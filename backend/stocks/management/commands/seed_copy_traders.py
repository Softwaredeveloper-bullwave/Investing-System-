from datetime import timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.utils import timezone

from stocks.models import CopyTraderProfile, CopyTraderTrade


SEED = [
    {
        'handle': 'nimbus_swing',
        'display_name': 'Aarav Mehta',
        'avatar_color': '#10B981',
        'bio': 'Swing trader focused on NSE large-caps with strict risk caps.',
        'strategy_title': 'Nifty Swing Momentum',
        'strategy_summary': (
            'Buys relative-strength leaders after pullbacks into 20-DMA support. '
            'Risks 1% per trade, scales out at 1.5R / 3R, and sits in cash when '
            'Bank Nifty breadth turns negative.'
        ),
        'method_tags': ['Swing', 'Large-cap', 'Risk 1%'],
        'risk_level': 'medium',
        'return_1m': Decimal('4.8'),
        'return_3m': Decimal('14.2'),
        'return_1y': Decimal('38.5'),
        'win_rate': Decimal('61.0'),
        'max_drawdown': Decimal('-8.4'),
        'followers_count': 1284,
        'aum_inr': Decimal('18500000'),
        'min_copy_amount': Decimal('5000'),
        'experience_years': 7,
        'trades': [
            ('RELIANCE', 'BUY', 40, 2890, 2.1, 'Breakout hold above 20DMA'),
            ('TCS', 'SELL', 25, 4120, 3.4, 'Booked partial at 3R'),
            ('HDFCBANK', 'BUY', 60, 1680, None, 'Pullback into support'),
            ('INFY', 'BUY', 50, 1525, 1.2, 'IT relative strength'),
        ],
    },
    {
        'handle': 'pulse_options',
        'display_name': 'Priya Shah',
        'avatar_color': '#3B82F6',
        'bio': 'Defined-risk options spreads around high-impact macro events.',
        'strategy_title': 'Event-Driven Spreads',
        'strategy_summary': (
            'Trades weekly / monthly option spreads around RBI, CPI, and earnings. '
            'Prefers debit spreads with capped loss and never holds naked short gamma '
            'into binary events.'
        ),
        'method_tags': ['Options', 'Defined risk', 'Events'],
        'risk_level': 'high',
        'return_1m': Decimal('6.1'),
        'return_3m': Decimal('18.9'),
        'return_1y': Decimal('52.0'),
        'win_rate': Decimal('57.5'),
        'max_drawdown': Decimal('-14.2'),
        'followers_count': 892,
        'aum_inr': Decimal('9200000'),
        'min_copy_amount': Decimal('10000'),
        'experience_years': 5,
        'trades': [
            ('NIFTY', 'BUY', 50, 245.5, 8.2, 'Bull call into CPI'),
            ('BANKNIFTY', 'SELL', 30, 180.0, 4.1, 'Credit put closed early'),
            ('RELIANCE', 'BUY', 100, 42.0, -1.5, 'Earnings straddle hedge'),
        ],
    },
    {
        'handle': 'steady_compound',
        'display_name': 'Rohan Iyer',
        'avatar_color': '#F59E0B',
        'bio': 'Long-only quality compounders with quarterly rebalancing.',
        'strategy_title': 'Quality Compounder Core',
        'strategy_summary': (
            'Builds a concentrated book of 8–12 quality businesses with rising ROE '
            'and clean balance sheets. Rebalances quarterly; uses dips to add, not chase.'
        ),
        'method_tags': ['Positional', 'Quality', 'Low turnover'],
        'risk_level': 'low',
        'return_1m': Decimal('2.4'),
        'return_3m': Decimal('7.8'),
        'return_1y': Decimal('24.6'),
        'win_rate': Decimal('68.0'),
        'max_drawdown': Decimal('-5.1'),
        'followers_count': 2105,
        'aum_inr': Decimal('31200000'),
        'min_copy_amount': Decimal('5000'),
        'experience_years': 9,
        'trades': [
            ('ASIANPAINT', 'BUY', 20, 2890, 1.1, 'Added on weakness'),
            ('NESTLEIND', 'BUY', 10, 2450, None, 'Core holding top-up'),
            ('BAJAJFINSV', 'SELL', 15, 1780, 5.6, 'Trimmed after run-up'),
            ('WIPRO', 'BUY', 80, 485, 0.8, 'Value add in IT'),
        ],
    },
    {
        'handle': 'midcap_radar',
        'display_name': 'Neha Kapoor',
        'avatar_color': '#A855F7',
        'bio': 'Mid-cap breakouts with volume confirmation and trailing stops.',
        'strategy_title': 'Midcap Breakout Radar',
        'strategy_summary': (
            'Scans for mid-caps breaking multi-week bases on rising delivery volume. '
            'Uses ATR trailing stops and cuts losers the same day if thesis breaks.'
        ),
        'method_tags': ['Mid-cap', 'Breakout', 'ATR stops'],
        'risk_level': 'high',
        'return_1m': Decimal('5.5'),
        'return_3m': Decimal('21.3'),
        'return_1y': Decimal('61.4'),
        'win_rate': Decimal('54.0'),
        'max_drawdown': Decimal('-16.8'),
        'followers_count': 674,
        'aum_inr': Decimal('6400000'),
        'min_copy_amount': Decimal('7500'),
        'experience_years': 4,
        'trades': [
            ('PERSISTENT', 'BUY', 15, 5420, 4.8, 'Base breakout'),
            ('DIXON', 'BUY', 10, 12450, 2.2, 'Volume surge'),
            ('POLYCAB', 'SELL', 12, 6850, 6.0, 'Trail hit'),
        ],
    },
]


class Command(BaseCommand):
    help = 'Seed verified copy-trading leaders and sample trade feeds'

    def handle(self, *args, **options):
        now = timezone.now()
        created = 0
        for raw in SEED:
            item = dict(raw)
            trades = item.pop('trades')
            trader, was_created = CopyTraderProfile.objects.update_or_create(
                handle=item['handle'],
                defaults={**item, 'is_verified': True, 'is_active': True},
            )
            if was_created:
                created += 1
            trader.trades.all().delete()
            for i, (symbol, side, qty, price, pnl, note) in enumerate(trades):
                CopyTraderTrade.objects.create(
                    trader=trader,
                    symbol=symbol,
                    side=side,
                    quantity=qty,
                    price=Decimal(str(price)),
                    pnl_percent=Decimal(str(pnl)) if pnl is not None else None,
                    note=note,
                    executed_at=now - timedelta(hours=6 * (i + 1), days=i),
                )
        self.stdout.write(
            self.style.SUCCESS(
                f'Seeded {len(SEED)} copy traders ({created} new).'
            )
        )
