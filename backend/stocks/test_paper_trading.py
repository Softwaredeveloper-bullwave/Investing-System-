"""Tests for the Paper Trading module — order book (market/limit/SL-M/SL),
charges, journal, analytics, and risk limits.

Run with: python manage.py test stocks.test_paper_trading

These exercise the service layer directly (fast, no HTTP/permission
plumbing) plus one end-to-end APIClient test for the place-order endpoint to
confirm URL wiring + auth actually work. Not yet executed in this sandbox
(no Django install here) — please run the command above before relying on
these; report back if anything fails.
"""

from decimal import Decimal

from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from accounts.models import User
from . import paper_journal_service, paper_order_service, paper_risk_limit_service
from .models import (
    PaperCommodityHolding,
    PaperCommodityOrder,
    PaperOptionHolding,
    PaperOptionOrder,
    PaperOrder,
    PaperTrade,
    PaperWallet,
    Stock,
    StockHolding,
)
from .paper_analytics_service import compute_performance_analytics
from .paper_charges_service import estimate_charges
from .paper_commodity_service import (
    PaperCommodityTradingError,
    exit_paper_commodity_position,
    place_paper_commodity_order,
)
from .paper_option_service import (
    PaperOptionTradingError,
    exit_paper_option_position,
    place_paper_option_order,
)
from .trading_service import get_or_create_paper_wallet, reset_paper_portfolio


def _make_stock(symbol='TESTSTK', ltp='100.00'):
    return Stock.objects.create(
        symbol=symbol, name=f'{symbol} Ltd', sector='Testing',
        ltp=Decimal(ltp), open_price=Decimal(ltp), high=Decimal(ltp),
        low=Decimal(ltp), previous_close=Decimal(ltp),
    )


@override_settings(KYC_AUTO_APPROVE=True)
class PaperTradingTestBase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='9000000001')
        self.stock = _make_stock()


class MarketOrderTests(PaperTradingTestBase):
    def test_market_buy_fills_immediately_and_debits_wallet(self):
        wallet_before = get_or_create_paper_wallet(self.user).balance
        payload = paper_order_service.place_order(
            self.user, symbol='TESTSTK', side='BUY', quantity=10,
        )
        self.assertEqual(payload['status'], PaperOrder.Status.EXECUTED)
        self.assertEqual(payload['executedPrice'], 100.0)

        wallet_after = get_or_create_paper_wallet(self.user).balance
        holding = StockHolding.objects.get(user=self.user, stock=self.stock)
        self.assertEqual(holding.quantity, 10)
        expected_debit = Decimal('1000.00') + Decimal(str(payload['charges']))
        self.assertAlmostEqual(float(wallet_before - wallet_after), float(expected_debit), places=2)

    def test_market_sell_credits_wallet_and_computes_realized_pnl(self):
        paper_order_service.place_order(self.user, symbol='TESTSTK', side='BUY', quantity=10)
        self.stock.ltp = Decimal('120.00')
        self.stock.save(update_fields=['ltp'])

        payload = paper_order_service.place_order(
            self.user, symbol='TESTSTK', side='SELL', quantity=10,
        )
        self.assertEqual(payload['status'], PaperOrder.Status.EXECUTED)
        trade = PaperTrade.objects.get(id=payload['tradeId'])
        self.assertGreater(trade.realized_pnl, Decimal('190'))  # ~200 minus charges
        self.assertFalse(StockHolding.objects.filter(user=self.user, stock=self.stock).exists())

    def test_market_buy_insufficient_balance_is_rejected_but_order_persists(self):
        wallet = get_or_create_paper_wallet(self.user)
        wallet.balance = Decimal('50.00')
        wallet.save(update_fields=['balance'])

        with self.assertRaises(paper_order_service.OrderValidationError):
            paper_order_service.place_order(self.user, symbol='TESTSTK', side='BUY', quantity=10)

        order = PaperOrder.objects.filter(user=self.user, side='BUY').latest('created_at')
        self.assertEqual(order.status, PaperOrder.Status.REJECTED)
        self.assertTrue(order.reject_reason)

    def test_market_sell_without_holding_rejected(self):
        with self.assertRaises(paper_order_service.OrderValidationError):
            paper_order_service.place_order(self.user, symbol='TESTSTK', side='SELL', quantity=5)


class LimitOrderTests(PaperTradingTestBase):
    def test_limit_buy_below_market_stays_pending(self):
        payload = paper_order_service.place_order(
            self.user, symbol='TESTSTK', side='BUY', quantity=5,
            order_type='LIMIT', limit_price='90.00',
        )
        self.assertEqual(payload['status'], PaperOrder.Status.PENDING)
        self.assertEqual(StockHolding.objects.filter(user=self.user).count(), 0)

    def test_marketable_limit_buy_fills_immediately(self):
        payload = paper_order_service.place_order(
            self.user, symbol='TESTSTK', side='BUY', quantity=5,
            order_type='LIMIT', limit_price='110.00',  # ltp=100 already satisfies this
        )
        self.assertEqual(payload['status'], PaperOrder.Status.EXECUTED)

    def test_pending_limit_buy_fills_once_price_drops(self):
        paper_order_service.place_order(
            self.user, symbol='TESTSTK', side='BUY', quantity=5,
            order_type='LIMIT', limit_price='90.00',
        )
        self.stock.ltp = Decimal('88.00')
        self.stock.save(update_fields=['ltp'])

        filled = paper_order_service.process_pending_paper_orders(user=self.user)
        self.assertEqual(len(filled), 1)
        order = PaperOrder.objects.get(id=filled[0].id)
        self.assertEqual(order.status, PaperOrder.Status.EXECUTED)
        self.assertEqual(order.executed_price, Decimal('88.00'))

    def test_reservation_blocks_second_pending_buy_over_budget(self):
        wallet = get_or_create_paper_wallet(self.user)
        wallet.balance = Decimal('1000.00')
        wallet.save(update_fields=['balance'])

        paper_order_service.place_order(
            self.user, symbol='TESTSTK', side='BUY', quantity=9,
            order_type='LIMIT', limit_price='95.00',  # resting, ~855 reserved
        )
        with self.assertRaises(paper_order_service.OrderValidationError):
            paper_order_service.place_order(
                self.user, symbol='TESTSTK', side='BUY', quantity=5,
                order_type='LIMIT', limit_price='95.00',  # would need ~475 more, only ~145 left
            )


class StopOrderTests(PaperTradingTestBase):
    def test_sl_m_sell_triggers_on_price_drop(self):
        paper_order_service.place_order(self.user, symbol='TESTSTK', side='BUY', quantity=10)
        paper_order_service.place_order(
            self.user, symbol='TESTSTK', side='SELL', quantity=10,
            order_type='SL-M', trigger_price='90.00',
        )
        self.stock.ltp = Decimal('85.00')
        self.stock.save(update_fields=['ltp'])

        filled = paper_order_service.process_pending_paper_orders(user=self.user)
        self.assertEqual(len(filled), 1)
        self.assertEqual(filled[0].status, PaperOrder.Status.EXECUTED)

    def test_sl_stop_limit_rejects_invalid_price_ordering(self):
        with self.assertRaises(paper_order_service.OrderValidationError):
            paper_order_service.place_order(
                self.user, symbol='TESTSTK', side='SELL', quantity=1,
                order_type='SL', trigger_price='90.00', limit_price='95.00',
            )  # SELL SL requires trigger >= limit


class ModifyCancelTests(PaperTradingTestBase):
    def test_modify_pending_order_quantity(self):
        payload = paper_order_service.place_order(
            self.user, symbol='TESTSTK', side='BUY', quantity=5,
            order_type='LIMIT', limit_price='90.00',
        )
        updated = paper_order_service.modify_order(self.user, payload['id'], quantity=8)
        self.assertEqual(updated['quantity'], 8)

    def test_cannot_modify_executed_order(self):
        payload = paper_order_service.place_order(self.user, symbol='TESTSTK', side='BUY', quantity=5)
        with self.assertRaises(paper_order_service.OrderValidationError):
            paper_order_service.modify_order(self.user, payload['id'], quantity=8)

    def test_cancel_pending_order(self):
        payload = paper_order_service.place_order(
            self.user, symbol='TESTSTK', side='BUY', quantity=5,
            order_type='LIMIT', limit_price='90.00',
        )
        cancelled = paper_order_service.cancel_order(self.user, payload['id'])
        self.assertEqual(cancelled['status'], PaperOrder.Status.CANCELLED)


class ExitPositionTests(PaperTradingTestBase):
    def test_exit_position_sells_full_holding(self):
        paper_order_service.place_order(self.user, symbol='TESTSTK', side='BUY', quantity=7)
        result = paper_order_service.exit_position(self.user, 'TESTSTK')
        self.assertEqual(result['status'], PaperOrder.Status.EXECUTED)
        self.assertEqual(result['quantity'], 7)
        self.assertFalse(StockHolding.objects.filter(user=self.user, stock=self.stock).exists())

    def test_exit_all_positions_closes_every_holding(self):
        stock2 = _make_stock(symbol='TESTSTK2', ltp='50.00')
        paper_order_service.place_order(self.user, symbol='TESTSTK', side='BUY', quantity=3)
        paper_order_service.place_order(self.user, symbol='TESTSTK2', side='BUY', quantity=4)

        results = paper_order_service.exit_all_positions(self.user)
        self.assertEqual(len(results), 2)
        self.assertEqual(StockHolding.objects.filter(user=self.user).count(), 0)


class ChargesTests(TestCase):
    def test_stamp_duty_only_on_buy_side(self):
        buy = estimate_charges(side='BUY', order_value=Decimal('100000'))
        sell = estimate_charges(side='SELL', order_value=Decimal('100000'))
        self.assertGreater(buy['stamp_duty'], Decimal('0'))
        self.assertEqual(sell['stamp_duty'], Decimal('0'))
        self.assertGreater(buy['total_charges'], sell['total_charges'])


class AnalyticsTests(PaperTradingTestBase):
    def test_win_rate_and_profit_factor_after_mixed_trades(self):
        # Winning round-trip.
        paper_order_service.place_order(self.user, symbol='TESTSTK', side='BUY', quantity=10)
        self.stock.ltp = Decimal('120.00')
        self.stock.save(update_fields=['ltp'])
        paper_order_service.place_order(self.user, symbol='TESTSTK', side='SELL', quantity=10)

        # Losing round-trip.
        self.stock.ltp = Decimal('100.00')
        self.stock.save(update_fields=['ltp'])
        paper_order_service.place_order(self.user, symbol='TESTSTK', side='BUY', quantity=10)
        self.stock.ltp = Decimal('90.00')
        self.stock.save(update_fields=['ltp'])
        paper_order_service.place_order(self.user, symbol='TESTSTK', side='SELL', quantity=10)

        analytics = compute_performance_analytics(self.user)
        self.assertEqual(analytics['closedTrades'], 2)
        self.assertEqual(analytics['winCount'], 1)
        self.assertEqual(analytics['lossCount'], 1)
        self.assertEqual(analytics['winRatePercent'], 50.0)
        self.assertGreater(analytics['profitFactor'], 0)
        self.assertTrue(len(analytics['equityCurve']) >= 1)


class JournalTests(PaperTradingTestBase):
    def test_create_update_delete_journal_entry(self):
        entry = paper_journal_service.create_journal_entry(
            self.user, title='First trade', notes='Bought the dip', symbol='TESTSTK', rating=4,
        )
        self.assertEqual(entry['title'], 'First trade')

        updated = paper_journal_service.update_journal_entry(
            self.user, entry['id'], notes='Updated notes', rating=5,
        )
        self.assertEqual(updated['notes'], 'Updated notes')
        self.assertEqual(updated['rating'], 5)

        paper_journal_service.delete_journal_entry(self.user, entry['id'])
        self.assertEqual(len(paper_journal_service.list_journal(self.user)), 0)

    def test_rating_out_of_range_rejected(self):
        with self.assertRaises(paper_journal_service.JournalError):
            paper_journal_service.create_journal_entry(self.user, title='Bad rating', rating=9)


class RiskLimitTests(PaperTradingTestBase):
    def test_update_and_fetch_risk_limit(self):
        payload = paper_risk_limit_service.update_risk_limit(
            self.user, max_daily_loss='5000', max_position_size_percent='15',
        )
        self.assertEqual(payload['maxDailyLoss'], 5000.0)
        self.assertEqual(payload['maxPositionSizePercent'], 15.0)

    def test_daily_loss_warning_triggers_after_big_drop(self):
        paper_risk_limit_service.update_risk_limit(self.user, max_daily_loss='100')
        paper_order_service.place_order(self.user, symbol='TESTSTK', side='BUY', quantity=50)
        self.stock.ltp = Decimal('50.00')  # big paper loss on unrealized position
        self.stock.save(update_fields=['ltp'])

        status = paper_risk_limit_service.check_risk_warnings(self.user)
        self.assertTrue(status['dailyLossBreached'])


class ResetTests(PaperTradingTestBase):
    def test_reset_clears_orders_and_restores_balance(self):
        paper_order_service.place_order(self.user, symbol='TESTSTK', side='BUY', quantity=5)
        reset_paper_portfolio(self.user)
        self.assertEqual(PaperOrder.objects.filter(user=self.user).count(), 0)
        self.assertEqual(StockHolding.objects.filter(user=self.user).count(), 0)
        wallet = get_or_create_paper_wallet(self.user)
        self.assertEqual(wallet.balance, wallet.starting_balance)


@override_settings(KYC_AUTO_APPROVE=True)
class PlaceOrderEndpointTests(TestCase):
    """One end-to-end check that URL wiring + auth + serializer validation
    actually connect the view to the service layer correctly."""

    def setUp(self):
        self.user = User.objects.create_user(phone='9000000002')
        _make_stock(symbol='ENDPTEST', ltp='200.00')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_place_market_order_via_api(self):
        # NOTE: request bodies use snake_case (matching every other existing
        # endpoint, e.g. CreateAlertSerializer's `target_price`) — CamelCase-
        # Serializer only camelCases *responses*, not incoming field names.
        response = self.client.post('/api/v1/paper-trading/place-order/', {
            'symbol': 'ENDPTEST', 'side': 'BUY', 'quantity': 3, 'order_type': 'MARKET',
        }, format='json')
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['status'], 'EXECUTED')

    def test_place_limit_order_missing_price_returns_400(self):
        response = self.client.post('/api/v1/paper-trading/place-order/', {
            'symbol': 'ENDPTEST', 'side': 'BUY', 'quantity': 3, 'order_type': 'LIMIT',
        }, format='json')
        self.assertEqual(response.status_code, 400)


@override_settings(KYC_AUTO_APPROVE=True)
class PaperOptionTradingTests(TestCase):
    """Options settle against PaperWallet only — never finance.Wallet."""

    def setUp(self):
        self.user = User.objects.create_user(phone='9000000003')
        self.wallet = get_or_create_paper_wallet(self.user)

    def test_buy_option_debits_paper_wallet_and_opens_holding(self):
        balance_before = self.wallet.balance
        payload = place_paper_option_order(
            self.user, underlying='NIFTY', strike='24000', option_type='CE',
            expiry='2026-08-27', side='BUY', quantity=2, premium='150.00',
        )
        self.assertEqual(payload['status'], PaperOptionOrder.Status.EXECUTED)
        holding = PaperOptionHolding.objects.get(user=self.user, underlying='NIFTY', strike=Decimal('24000'))
        self.assertEqual(holding.quantity, 2)
        # 2 lots * 25 lot size * 150 premium = 7500, plus charges
        self.wallet.refresh_from_db()
        self.assertLess(self.wallet.balance, balance_before - Decimal('7500'))

    def test_sell_more_than_held_is_rejected_but_persisted(self):
        with self.assertRaises(PaperOptionTradingError):
            place_paper_option_order(
                self.user, underlying='NIFTY', strike='24000', option_type='CE',
                expiry='2026-08-27', side='SELL', quantity=1, premium='150.00',
            )
        rejected = PaperOptionOrder.objects.filter(user=self.user, status=PaperOptionOrder.Status.REJECTED)
        self.assertEqual(rejected.count(), 1)

    def test_exit_position_realizes_pnl(self):
        place_paper_option_order(
            self.user, underlying='NIFTY', strike='24000', option_type='CE',
            expiry='2026-08-27', side='BUY', quantity=1, premium='100.00',
        )
        payload = exit_paper_option_position(
            self.user, underlying='NIFTY', strike='24000', option_type='CE',
            expiry='2026-08-27', premium='150.00',
        )
        self.assertGreater(payload['realizedPnlInr'], 0)
        self.assertFalse(PaperOptionHolding.objects.filter(user=self.user).exists())

    def test_reset_wipes_option_holdings(self):
        place_paper_option_order(
            self.user, underlying='NIFTY', strike='24000', option_type='CE',
            expiry='2026-08-27', side='BUY', quantity=1, premium='100.00',
        )
        reset_paper_portfolio(self.user)
        self.assertFalse(PaperOptionHolding.objects.filter(user=self.user).exists())
        self.assertFalse(PaperOptionOrder.objects.filter(user=self.user).exists())


@override_settings(KYC_AUTO_APPROVE=True)
class PaperCommodityTradingTests(TestCase):
    """Commodities settle against PaperWallet only, live-priced off the same
    static COMMODITY_CATALOG/quote source as real commodity trading."""

    def setUp(self):
        self.user = User.objects.create_user(phone='9000000004')
        self.wallet = get_or_create_paper_wallet(self.user)

    def test_buy_gold_debits_paper_wallet_and_opens_holding(self):
        balance_before = self.wallet.balance
        payload = place_paper_commodity_order(self.user, commodity_id='GOLD', side='BUY', quantity=1)
        self.assertEqual(payload['status'], PaperCommodityOrder.Status.EXECUTED)
        holding = PaperCommodityHolding.objects.get(user=self.user, commodity_id='GOLD')
        self.assertEqual(holding.quantity, 1)
        self.wallet.refresh_from_db()
        self.assertLess(self.wallet.balance, balance_before)

    def test_sell_more_than_held_is_rejected_but_persisted(self):
        with self.assertRaises(PaperCommodityTradingError):
            place_paper_commodity_order(self.user, commodity_id='GOLD', side='SELL', quantity=1)
        rejected = PaperCommodityOrder.objects.filter(user=self.user, status=PaperCommodityOrder.Status.REJECTED)
        self.assertEqual(rejected.count(), 1)

    def test_exit_position_closes_holding(self):
        place_paper_commodity_order(self.user, commodity_id='GOLD', side='BUY', quantity=2)
        exit_paper_commodity_position(self.user, commodity_id='GOLD')
        self.assertFalse(PaperCommodityHolding.objects.filter(user=self.user).exists())

    def test_reset_wipes_commodity_holdings(self):
        place_paper_commodity_order(self.user, commodity_id='GOLD', side='BUY', quantity=1)
        reset_paper_portfolio(self.user)
        self.assertFalse(PaperCommodityHolding.objects.filter(user=self.user).exists())
        self.assertFalse(PaperCommodityOrder.objects.filter(user=self.user).exists())


@override_settings(KYC_AUTO_APPROVE=True)
class UnifiedAnalyticsTests(TestCase):
    """Analytics/risk should aggregate realized P&L across equities,
    options, and commodities into one account-level picture."""

    def setUp(self):
        self.user = User.objects.create_user(phone='9000000005')
        get_or_create_paper_wallet(self.user)

    def test_analytics_include_option_and_commodity_realized_pnl(self):
        place_paper_option_order(
            self.user, underlying='NIFTY', strike='24000', option_type='CE',
            expiry='2026-08-27', side='BUY', quantity=1, premium='100.00',
        )
        exit_paper_option_position(
            self.user, underlying='NIFTY', strike='24000', option_type='CE',
            expiry='2026-08-27', premium='150.00',
        )
        place_paper_commodity_order(self.user, commodity_id='GOLD', side='BUY', quantity=1)
        exit_paper_commodity_position(self.user, commodity_id='GOLD')

        analytics = compute_performance_analytics(self.user)
        self.assertGreaterEqual(analytics['closedTrades'], 2)
        self.assertGreaterEqual(analytics['totalTrades'], 2)
