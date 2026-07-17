"""SIP installment execution using live prices."""

import logging
from datetime import timedelta
from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from engagement.models import Notification

from .market_data_service import refresh_stock
from .finnhub_client import FinnhubError
from .models import SipPlan, StockHolding

logger = logging.getLogger('bullwave.finance')


@transaction.atomic
def process_due_sip_installments() -> int:
    """Run SIP installments due today or earlier. Returns count processed."""
    today = timezone.localdate()
    plans = SipPlan.objects.filter(is_active=True, next_date__lte=today).select_related(
        'stock', 'user'
    )
    processed = 0

    for plan in plans:
        if plan.installments_done >= plan.total_installments:
            plan.is_active = False
            plan.save(update_fields=['is_active'])
            continue

        try:
            stock = refresh_stock(plan.stock.symbol)
        except FinnhubError as exc:
            logger.warning('SIP skip %s: %s', plan.stock.symbol, exc)
            continue

        amount = plan.monthly_amount
        ltp = stock.ltp
        if ltp <= 0:
            continue

        qty = int(amount / ltp)
        if qty < 1:
            continue

        actual_invested = Decimal(str(qty)) * ltp
        holding, _ = StockHolding.objects.get_or_create(
            user=plan.user,
            stock=stock,
            defaults={'quantity': 0, 'avg_price': Decimal('0')},
        )
        total_cost = holding.quantity * holding.avg_price + actual_invested
        holding.quantity += qty
        holding.avg_price = total_cost / holding.quantity
        holding.save()

        plan.installments_done += 1
        plan.total_invested += actual_invested
        plan.current_value = Decimal(str(holding.quantity)) * ltp
        plan.next_date = today + timedelta(days=30)

        if plan.installments_done >= plan.total_installments:
            plan.is_active = False

        plan.save()

        Notification.objects.create(
            user=plan.user,
            title=f'SIP Executed: {stock.symbol}',
            message=f'₹{actual_invested:,.0f} invested — bought {qty} shares at ₹{ltp}.',
            type='investment',
        )
        processed += 1

    return processed
