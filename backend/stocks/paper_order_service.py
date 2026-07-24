"""Paper-trading order book: MARKET / LIMIT / SL-M / SL order placement,
opportunistic matching against live LTP, modify/cancel, and position exits.

MARKET orders execute immediately (same behaviour as the legacy
`trading_service.place_paper_order`). LIMIT/SL-M/SL orders sit `PENDING` in
`PaperOrder` until `process_pending_paper_orders()` matches them — called
opportunistically from the order-book GET endpoint and order-placement POST
endpoint (no Celery/cron worker in this project — see
`management/commands/run_finance_jobs.py` for the equivalent `--paper-orders`
flag for real cron setups).

Simplification, documented for honesty: SL / SL-M orders are evaluated as a
single trigger+fill condition per matching pass rather than persisting a
separate "triggered" sub-state — see `_match()`. Good enough for a learning
simulator; a real exchange's stop-order semantics are more nuanced.
"""

from __future__ import annotations

from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from .finnhub_client import FinnhubError
from .market_data_service import refresh_stock
from .models import PaperOrder, PaperWallet, Stock, StockHolding
from .paper_charges_service import total_charges
from .trading_service import TradingError, apply_fill

ORDER_TYPES_REQUIRING_LIMIT = {PaperOrder.OrderType.LIMIT, PaperOrder.OrderType.SL}
ORDER_TYPES_REQUIRING_TRIGGER = {PaperOrder.OrderType.SL_M, PaperOrder.OrderType.SL}


class OrderValidationError(TradingError):
    pass


def _round2(value) -> float:
    return round(float(value), 2)


def build_order_payload(order: PaperOrder) -> dict:
    stock = order.stock
    payload = {
        'id': str(order.id),
        'symbol': stock.symbol,
        'stockName': stock.name,
        'side': order.side,
        'orderType': order.order_type,
        'quantity': order.quantity,
        'limitPrice': _round2(order.limit_price) if order.limit_price is not None else None,
        'triggerPrice': _round2(order.trigger_price) if order.trigger_price is not None else None,
        'status': order.status,
        'executedPrice': _round2(order.executed_price) if order.executed_price is not None else None,
        'charges': _round2(order.charges),
        'rejectReason': order.reject_reason,
        'ltp': _round2(stock.ltp),
        'createdAt': order.created_at.isoformat(),
        'updatedAt': order.updated_at.isoformat(),
        'executedAt': order.executed_at.isoformat() if order.executed_at else None,
        'tradeId': str(order.trade_id) if order.trade_id else None,
    }
    return payload


def _resolve_stock(symbol: str) -> Stock:
    symbol = symbol.upper().strip()
    stock = Stock.objects.filter(symbol=symbol).first()
    if not stock:
        try:
            stock = refresh_stock(symbol)
        except FinnhubError as exc:
            raise OrderValidationError(str(exc)) from exc
    return stock


def _validate_order_type_fields(order_type: str, limit_price, trigger_price, side: str):
    if order_type in ORDER_TYPES_REQUIRING_LIMIT and limit_price is None:
        raise OrderValidationError(f'{order_type} orders require a limit price.')
    if order_type in ORDER_TYPES_REQUIRING_TRIGGER and trigger_price is None:
        raise OrderValidationError(f'{order_type} orders require a trigger (stop) price.')
    if order_type == PaperOrder.OrderType.SL:
        # BUY stop-limit: breakout entry, trigger <= limit (cap what you'll pay).
        # SELL stop-limit: protect a long, trigger >= limit (floor what you'll accept).
        if side == 'BUY' and trigger_price > limit_price:
            raise OrderValidationError('For a BUY stop-limit, trigger price must be ≤ limit price.')
        if side == 'SELL' and trigger_price < limit_price:
            raise OrderValidationError('For a SELL stop-limit, trigger price must be ≥ limit price.')


def _reserved_buy_value(user, exclude_order_id=None) -> Decimal:
    """Estimated ₹ already committed by this user's other pending BUY orders,
    so a new order can't be accepted against funds that are already spoken
    for by an earlier resting order."""
    qs = PaperOrder.objects.filter(
        user=user, status=PaperOrder.Status.PENDING, side='BUY'
    )
    if exclude_order_id:
        qs = qs.exclude(id=exclude_order_id)
    total = Decimal('0')
    for o in qs:
        est_price = o.limit_price or o.trigger_price or o.stock.ltp
        total += Decimal(o.quantity) * Decimal(est_price)
    return total


def _reserved_sell_qty(user, stock, exclude_order_id=None) -> int:
    qs = PaperOrder.objects.filter(
        user=user, status=PaperOrder.Status.PENDING, side='SELL', stock=stock
    )
    if exclude_order_id:
        qs = qs.exclude(id=exclude_order_id)
    return sum(o.quantity for o in qs)


def place_order(
    user,
    *,
    symbol: str,
    side: str,
    quantity: int,
    order_type: str = PaperOrder.OrderType.MARKET,
    limit_price=None,
    trigger_price=None,
) -> dict:
    side = (side or '').upper().strip()
    order_type = (order_type or PaperOrder.OrderType.MARKET).upper().strip()

    if side not in ('BUY', 'SELL'):
        raise OrderValidationError('Invalid order side.')
    if quantity < 1:
        raise OrderValidationError('Quantity must be at least 1.')
    if order_type not in PaperOrder.OrderType.values:
        raise OrderValidationError('Invalid order type.')

    limit_price = Decimal(str(limit_price)) if limit_price not in (None, '') else None
    trigger_price = Decimal(str(trigger_price)) if trigger_price not in (None, '') else None
    _validate_order_type_fields(order_type, limit_price, trigger_price, side)

    stock = _resolve_stock(symbol)
    if stock.ltp <= 0:
        raise OrderValidationError('Live price unavailable for this stock. Try again shortly.')

    if order_type == PaperOrder.OrderType.MARKET:
        price = stock.ltp
        charges = total_charges(side=side, order_value=Decimal(quantity) * price)
        order = PaperOrder.objects.create(
            user=user, stock=stock, side=side, order_type=order_type,
            quantity=quantity, status=PaperOrder.Status.PENDING, charges=charges,
        )
        _fill_order(order, stock, price)
        if order.status == PaperOrder.Status.REJECTED:
            # The order row persists (audit trail) but the caller still gets
            # a clear error — matches the legacy place_paper_order contract.
            raise OrderValidationError(order.reject_reason)
        return build_order_payload(order)

    # Resting (LIMIT / SL-M / SL) order — fund/share reservation guard.
    if side == 'BUY':
        est_price = limit_price or trigger_price
        estimate = Decimal(quantity) * est_price
        wallet = PaperWallet.get_or_create_for(user)
        already_reserved = _reserved_buy_value(user)
        if estimate + already_reserved > wallet.balance:
            raise OrderValidationError(
                f'Insufficient virtual balance. This order needs ~₹{estimate:,.2f}, and '
                f'₹{already_reserved:,.2f} is already committed to other pending orders — '
                f'you only have ₹{wallet.balance:,.2f} available.'
            )
    else:
        holding = StockHolding.objects.filter(user=user, stock=stock).first()
        held = holding.quantity if holding else 0
        reserved = _reserved_sell_qty(user, stock)
        if held - reserved < quantity:
            raise OrderValidationError(
                f'Insufficient uncommitted shares. You hold {held} {stock.symbol}, '
                f'{reserved} already reserved by other pending sell orders.'
            )

    order = PaperOrder.objects.create(
        user=user, stock=stock, side=side, order_type=order_type,
        quantity=quantity, limit_price=limit_price, trigger_price=trigger_price,
        status=PaperOrder.Status.PENDING,
    )
    # Marketable-limit behaviour: if the condition is already met right now,
    # fill immediately instead of making the learner wait for the next poll.
    should_fill, fill_price = _match(order, stock.ltp)
    if should_fill:
        _fill_order(order, stock, fill_price)
    return build_order_payload(order)


def _match(order: PaperOrder, ltp) -> tuple[bool, Decimal | None]:
    ltp = Decimal(ltp)
    ot, side = order.order_type, order.side

    if ot == PaperOrder.OrderType.LIMIT:
        if side == 'BUY' and ltp <= order.limit_price:
            return True, ltp
        if side == 'SELL' and ltp >= order.limit_price:
            return True, ltp
        return False, None

    if ot == PaperOrder.OrderType.SL_M:
        if side == 'BUY' and ltp >= order.trigger_price:
            return True, ltp
        if side == 'SELL' and ltp <= order.trigger_price:
            return True, ltp
        return False, None

    if ot == PaperOrder.OrderType.SL:
        if side == 'BUY' and order.trigger_price <= ltp <= order.limit_price:
            return True, ltp
        if side == 'SELL' and order.limit_price <= ltp <= order.trigger_price:
            return True, ltp
        return False, None

    return False, None


def _fill_order(order: PaperOrder, stock: Stock, price: Decimal):
    """Attempts the fill and always leaves `order` in a terminal, *persisted*
    state (EXECUTED or REJECTED) — never raises, so a rejection during
    opportunistic matching can't unwind an unrelated caller's transaction and
    silently erase the rejected order's audit trail. Callers check
    `order.status` afterwards."""
    charges = order.charges if order.charges and order.charges > 0 else total_charges(
        side=order.side, order_value=Decimal(order.quantity) * Decimal(price)
    )
    try:
        trade, _holding, _wallet = apply_fill(
            order.user, stock, order.side, order.quantity, price,
            charges=charges, order=order,
        )
    except TradingError as exc:
        order.status = PaperOrder.Status.REJECTED
        order.reject_reason = str(exc)
        order.save(update_fields=['status', 'reject_reason', 'updated_at'])
        return
    order.status = PaperOrder.Status.EXECUTED
    order.executed_price = price
    order.charges = charges
    order.trade = trade
    order.executed_at = timezone.now()
    order.save(update_fields=['status', 'executed_price', 'charges', 'trade', 'executed_at', 'updated_at'])


def process_pending_paper_orders(user=None, symbols=None) -> list[PaperOrder]:
    """Matching pass — called opportunistically from the order-book/dashboard
    endpoints, and available as a management-command flag for real cron."""
    qs = PaperOrder.objects.filter(status=PaperOrder.Status.PENDING).select_related('stock', 'user')
    if user is not None:
        qs = qs.filter(user=user)
    if symbols:
        qs = qs.filter(stock__symbol__in=[s.upper() for s in symbols])

    filled = []
    for order in qs.order_by('created_at'):
        stock = order.stock
        if stock.ltp <= 0:
            continue
        should_fill, fill_price = _match(order, stock.ltp)
        if not should_fill:
            continue
        _fill_order(order, stock, fill_price)
        if order.status == PaperOrder.Status.EXECUTED:
            filled.append(order)
        # else: REJECTED — status/reason already persisted inside _fill_order.
    return filled


@transaction.atomic
def modify_order(user, order_id, *, quantity=None, limit_price=None, trigger_price=None) -> dict:
    try:
        order = PaperOrder.objects.select_for_update().get(id=order_id, user=user)
    except PaperOrder.DoesNotExist:
        raise OrderValidationError('Order not found.')
    if order.status != PaperOrder.Status.PENDING:
        raise OrderValidationError('Only pending orders can be modified.')

    if quantity is not None:
        if quantity < 1:
            raise OrderValidationError('Quantity must be at least 1.')
        order.quantity = quantity
    if limit_price is not None:
        order.limit_price = Decimal(str(limit_price))
    if trigger_price is not None:
        order.trigger_price = Decimal(str(trigger_price))

    _validate_order_type_fields(order.order_type, order.limit_price, order.trigger_price, order.side)

    # Re-check reservation with the new numbers, excluding this order itself.
    if order.side == 'BUY':
        est_price = order.limit_price or order.trigger_price or order.stock.ltp
        estimate = Decimal(order.quantity) * Decimal(est_price)
        wallet = PaperWallet.get_or_create_for(user)
        already_reserved = _reserved_buy_value(user, exclude_order_id=order.id)
        if estimate + already_reserved > wallet.balance:
            raise OrderValidationError('Modified order exceeds available virtual balance.')
    else:
        holding = StockHolding.objects.filter(user=user, stock=order.stock).first()
        held = holding.quantity if holding else 0
        reserved = _reserved_sell_qty(user, order.stock, exclude_order_id=order.id)
        if held - reserved < order.quantity:
            raise OrderValidationError('Modified order exceeds uncommitted shares held.')

    order.save(update_fields=['quantity', 'limit_price', 'trigger_price', 'updated_at'])
    return build_order_payload(order)


@transaction.atomic
def cancel_order(user, order_id) -> dict:
    try:
        order = PaperOrder.objects.select_for_update().get(id=order_id, user=user)
    except PaperOrder.DoesNotExist:
        raise OrderValidationError('Order not found.')
    if order.status != PaperOrder.Status.PENDING:
        raise OrderValidationError('Only pending orders can be cancelled.')
    order.status = PaperOrder.Status.CANCELLED
    order.save(update_fields=['status', 'updated_at'])
    return build_order_payload(order)


def list_order_book(user, *, status=None, limit: int = 100) -> list[dict]:
    process_pending_paper_orders(user=user)  # opportunistic matching before listing
    qs = PaperOrder.objects.filter(user=user).select_related('stock')
    if status:
        qs = qs.filter(status=status.upper())
    return [build_order_payload(o) for o in qs[:limit]]


def exit_position(user, symbol: str) -> dict:
    stock = _resolve_stock(symbol)
    holding = StockHolding.objects.filter(user=user, stock=stock).first()
    if not holding or holding.quantity < 1:
        raise OrderValidationError(f'No open position in {stock.symbol}.')
    return place_order(user, symbol=stock.symbol, side='SELL', quantity=holding.quantity)


def exit_all_positions(user) -> list[dict]:
    holdings = list(StockHolding.objects.filter(user=user, quantity__gt=0).select_related('stock'))
    results = []
    for holding in holdings:
        try:
            results.append(place_order(user, symbol=holding.stock.symbol, side='SELL', quantity=holding.quantity))
        except (TradingError, OrderValidationError) as exc:
            results.append({'symbol': holding.stock.symbol, 'error': str(exc)})
    return results
