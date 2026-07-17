from datetime import date, timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.utils import timezone

from accounts.models import User
from engagement.models import MarketIndex, MarketNews, SupportFaq
from finance.models import InvestmentFaq, InvestmentPlan
from stocks.models import OptionContract, Stock, StockCandle, StockHolding, StockNews


STOCKS = [
    ('RELIANCE', 'Reliance Industries', 'Energy', 2948.50, 32.40, 1.11, 2920, 2955, 2910.25, 2916.10, 8420000, 1995000, 28.4, 103.8, 3210, 2220, 12.5, 0.45, 8.2),
    ('TCS', 'Tata Consultancy Services', 'IT', 4125.30, -18.70, -0.45, 4148, 4155, 4110, 4144, 2150000, 1502000, 32.1, 128.5, 4592, 3311, 38.2, 0.05, 10.5),
    ('INFY', 'Infosys Ltd', 'IT', 1882.15, 12.85, 0.69, 1870, 1890.5, 1865, 1869.30, 4680000, 782000, 27.8, 67.7, 2006, 1350, 29.1, 0.08, 9.8),
    ('HDFCBANK', 'HDFC Bank', 'Banking', 1724.80, 8.20, 0.48, 1718, 1730, 1712.5, 1716.60, 6120000, 1310000, 19.2, 89.8, 1880, 1363, 16.8, 1.2, 12.1),
    ('ICICIBANK', 'ICICI Bank', 'Banking', 1248.60, -5.40, -0.43, 1256, 1258, 1242, 1254, 8940000, 875000, 18.5, 67.4, 1312, 912, 15.2, 1.1, 11.4),
    ('SBIN', 'State Bank of India', 'Banking', 812.45, 4.15, 0.51, 808, 815, 805, 808.30, 12500000, 724000, 10.2, 79.6, 912, 543, 14.5, 1.8, 8.9),
    ('BHARTIARTL', 'Bharti Airtel', 'Telecom', 1588.20, 22.10, 1.41, 1568, 1592, 1560, 1566.10, 5200000, 898000, 42.5, 37.4, 1779, 1186, 18.9, 1.5, 15.2),
    ('ITC', 'ITC Ltd', 'FMCG', 465.30, -2.10, -0.45, 468, 470, 463, 467.40, 9800000, 582000, 28.9, 16.1, 528, 392, 22.4, 0.02, 6.5),
]

DEMO_HOLDINGS = [
    ('RELIANCE', 10),
    ('TCS', 5),
    ('HDFCBANK', 15),
    ('INFY', 20),
]

PLANS = [
    (
        'PLAN001',
        'BullWave Alpha Premier',
        1000000,
        0.25,
        0.25,
        0.25,
        3.0,
        'Entry-tier premium plan — ₹10 lakh minimum with 0.25% monthly returns.',
        True,
    ),
    (
        'PLAN002',
        'BullWave Platinum Reserve',
        5000000,
        3.0,
        3.0,
        3.0,
        36.0,
        'Mid-tier wealth plan — ₹50 lakh minimum with 3% monthly returns.',
        True,
    ),
    (
        'PLAN003',
        'BullWave Sovereign Crown',
        10000000,
        4.0,
        4.0,
        4.0,
        48.0,
        'Flagship HNI plan — ₹1 crore minimum with 4% monthly returns.',
        True,
    ),
]


class Command(BaseCommand):
    help = 'Seed BullWave database with investment plans, stocks, and market data'

    def handle(self, *args, **options):
        self._seed_plans()
        self._seed_faqs()
        self._seed_stocks()
        self._seed_market()
        self._seed_news()
        self._seed_options()
        self._seed_demo_holdings()
        self.stdout.write(self.style.SUCCESS('Seed data loaded successfully.'))

    def _seed_plans(self):
        for row in PLANS:
            InvestmentPlan.objects.update_or_create(
                id=row[0],
                defaults={
                    'name': row[1],
                    'minimum_investment': Decimal(str(row[2])),
                    'monthly_return_rate': Decimal(str(row[3])),
                    'monthly_return_min': Decimal(str(row[4])),
                    'monthly_return_max': Decimal(str(row[5])),
                    'annual_return_rate': Decimal(str(row[6])),
                    'description': row[7],
                    'is_featured': row[8],
                },
            )

    def _seed_faqs(self):
        investment_faqs = [
            (
                'What returns can I expect?',
                'Alpha Premier offers 0.25% monthly, Platinum Reserve offers 3% monthly, '
                'and Sovereign Crown offers 4% monthly — all credited to your wallet.',
            ),
            ('Can I withdraw anytime?', 'Yes, you can withdraw your profits anytime. Principal withdrawal is subject to plan terms.'),
            ('What documents are required?', 'PAN, Aadhaar, bank details, and a selfie for KYC verification are required.'),
        ]
        for i, (q, a) in enumerate(investment_faqs):
            InvestmentFaq.objects.update_or_create(question=q, defaults={'answer': a, 'order': i})

        support_faqs = [
            ('What is the minimum investment amount?', 'Plans start at ₹10 lakh (Alpha Premier), ₹50 lakh (Platinum Reserve), and ₹1 crore (Sovereign Crown).'),
            ('How are returns calculated?', 'Returns are fixed monthly percentages based on your chosen plan and invested amount.'),
            ('How long does withdrawal take?', 'Withdrawals are processed within 2-3 business days.'),
            ('Is my investment secure?', 'All investments follow strict compliance guidelines and regulated instruments.'),
        ]
        for i, (q, a) in enumerate(support_faqs):
            SupportFaq.objects.update_or_create(question=q, defaults={'answer': a, 'order': i})

    def _seed_stocks(self):
        for row in STOCKS:
            stock, created = Stock.objects.update_or_create(
                symbol=row[0],
                defaults={
                    'name': row[1],
                    'sector': row[2],
                    'ltp': Decimal(str(row[3])),
                    'change': Decimal(str(row[4])),
                    'change_percent': Decimal(str(row[5])),
                    'open_price': Decimal(str(row[6])),
                    'high': Decimal(str(row[7])),
                    'low': Decimal(str(row[8])),
                    'previous_close': Decimal(str(row[9])),
                    'volume': row[10],
                    'market_cap_cr': Decimal(str(row[11])),
                    'pe': Decimal(str(row[12])),
                    'eps': Decimal(str(row[13])),
                    'week52_high': Decimal(str(row[14])),
                    'week52_low': Decimal(str(row[15])),
                    'roe': Decimal(str(row[16])),
                    'debt_to_equity': Decimal(str(row[17])),
                    'revenue_growth': Decimal(str(row[18])),
                },
            )
            if created or not stock.candles.exists():
                self._seed_candles(stock)

    def _seed_candles(self, stock):
        base = float(stock.ltp)
        now = timezone.now()
        for i in range(30):
            t = now - timedelta(days=30 - i)
            o = base + (i % 5 - 2) * 10
            c = o + (i % 3 - 1) * 8
            StockCandle.objects.get_or_create(
                stock=stock,
                time=t.replace(hour=15, minute=30, second=0, microsecond=0),
                interval=StockCandle.Interval.D1,
                defaults={
                    'open_price': Decimal(str(round(o, 2))),
                    'high': Decimal(str(round(max(o, c) + 5, 2))),
                    'low': Decimal(str(round(min(o, c) - 5, 2))),
                    'close': Decimal(str(round(c, 2))),
                    'volume': 1000000 + i * 50000,
                },
            )

    def _seed_market(self):
        indices = [
            ('NIFTY50', 'Nifty 50', 'NIFTY', 24832.45, 156.30, 0.63),
            ('SENSEX', 'Sensex', 'SENSEX', 81524.78, 582.15, 0.72),
            ('BANKNIFTY', 'Bank Nifty', 'BANK NIFTY', 52318.60, -124.40, -0.24),
        ]
        for row in indices:
            MarketIndex.objects.update_or_create(
                id=row[0],
                defaults={
                    'name': row[1],
                    'short_name': row[2],
                    'value': Decimal(str(row[3])),
                    'change': Decimal(str(row[4])),
                    'change_percent': Decimal(str(row[5])),
                },
            )

        news_items = [
            ('Nifty 50 hits new all-time high', 'Markets rally on strong FII inflows'),
            ('RBI keeps repo rate unchanged', 'Policy stance remains accommodative'),
            ('Gold prices surge 2%', 'Safe haven demand rises globally'),
        ]
        for title, subtitle in news_items:
            MarketNews.objects.get_or_create(title=title, defaults={'subtitle': subtitle})

    def _seed_news(self):
        if StockNews.objects.exists():
            return
        StockNews.objects.create(
            title='Reliance announces Q3 results beat estimates',
            summary='Reliance Industries reported strong quarterly earnings driven by retail and Jio segments.',
            source='Economic Times',
            published_at=timezone.now() - timedelta(hours=2),
            related_symbols=['RELIANCE'],
            category='earnings',
        )
        StockNews.objects.create(
            title='IT sector outlook remains positive',
            summary='Analysts maintain bullish view on TCS and Infosys amid global deal wins.',
            source='Moneycontrol',
            published_at=timezone.now() - timedelta(hours=5),
            related_symbols=['TCS', 'INFY'],
            category='sector',
        )

    def _seed_options(self):
        if OptionContract.objects.exists():
            return
        expiry = date.today() + timedelta(days=30 - date.today().day % 7)
        for strike in [24000, 24500, 25000, 25500, 26000]:
            for opt_type in ['CE', 'PE']:
                OptionContract.objects.create(
                    underlying='NIFTY',
                    strike=Decimal(str(strike)),
                    option_type=opt_type,
                    ltp=Decimal(str(120 + strike % 500)),
                    change=Decimal(str(5.2)),
                    oi=450000,
                    volume=82000,
                    expiry=expiry,
                )

    def _seed_demo_holdings(self):
        for user in User.objects.all():
            if StockHolding.objects.filter(user=user, quantity__gt=0).exists():
                continue
            for symbol, qty in DEMO_HOLDINGS:
                stock = Stock.objects.filter(symbol=symbol).first()
                if not stock:
                    continue
                avg = (stock.ltp * Decimal('0.92')).quantize(Decimal('0.01'))
                StockHolding.objects.update_or_create(
                    user=user,
                    stock=stock,
                    defaults={'quantity': qty, 'avg_price': avg},
                )
