from datetime import timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.utils import timezone

from stocks.models import BlockDeal, DarkPoolPrint


BLOCK_SEED = [
    {
        'symbol': 'RELIANCE',
        'company_name': 'Reliance Industries',
        'exchange': 'NSE',
        'deal_type': 'block',
        'side': 'BUY',
        'price': Decimal('2895.00'),
        'quantity': 2500000,
        'value_cr': Decimal('723.75'),
        'ltp': Decimal('2888.50'),
        'premium_percent': Decimal('0.23'),
        'client_name': 'Fidelity Worldwide',
        'counterparty': 'Institutional',
        'hours_ago': 2,
    },
    {
        'symbol': 'HDFCBANK',
        'company_name': 'HDFC Bank',
        'exchange': 'NSE',
        'deal_type': 'block',
        'side': 'SELL',
        'price': Decimal('1672.00'),
        'quantity': 1800000,
        'value_cr': Decimal('300.96'),
        'ltp': Decimal('1680.25'),
        'premium_percent': Decimal('-0.49'),
        'client_name': 'GIC Private Ltd',
        'counterparty': 'Domestic MF',
        'hours_ago': 3,
    },
    {
        'symbol': 'TCS',
        'company_name': 'Tata Consultancy Services',
        'exchange': 'NSE',
        'deal_type': 'bulk',
        'side': 'BUY',
        'price': Decimal('4125.50'),
        'quantity': 450000,
        'value_cr': Decimal('185.65'),
        'ltp': Decimal('4110.00'),
        'premium_percent': Decimal('0.38'),
        'client_name': 'Norges Bank',
        'counterparty': 'Institutional',
        'hours_ago': 5,
    },
    {
        'symbol': 'INFY',
        'company_name': 'Infosys',
        'exchange': 'NSE',
        'deal_type': 'block',
        'side': 'BUY',
        'price': Decimal('1538.00'),
        'quantity': 1200000,
        'value_cr': Decimal('184.56'),
        'ltp': Decimal('1529.75'),
        'premium_percent': Decimal('0.54'),
        'client_name': 'Capital Group',
        'counterparty': 'Institutional',
        'hours_ago': 6,
    },
    {
        'symbol': 'ICICIBANK',
        'company_name': 'ICICI Bank',
        'exchange': 'NSE',
        'deal_type': 'bulk',
        'side': 'SELL',
        'price': Decimal('1248.00'),
        'quantity': 2100000,
        'value_cr': Decimal('262.08'),
        'ltp': Decimal('1255.40'),
        'premium_percent': Decimal('-0.59'),
        'client_name': 'Promoter Group',
        'counterparty': 'Market',
        'hours_ago': 8,
    },
    {
        'symbol': 'SBIN',
        'company_name': 'State Bank of India',
        'exchange': 'BSE',
        'deal_type': 'block',
        'side': 'BUY',
        'price': Decimal('812.50'),
        'quantity': 3500000,
        'value_cr': Decimal('284.38'),
        'ltp': Decimal('808.20'),
        'premium_percent': Decimal('0.53'),
        'client_name': 'LIC of India',
        'counterparty': 'Institutional',
        'hours_ago': 10,
    },
    {
        'symbol': 'BHARTIARTL',
        'company_name': 'Bharti Airtel',
        'exchange': 'NSE',
        'deal_type': 'block',
        'side': 'BUY',
        'price': Decimal('1645.00'),
        'quantity': 900000,
        'value_cr': Decimal('148.05'),
        'ltp': Decimal('1638.60'),
        'premium_percent': Decimal('0.39'),
        'client_name': 'BlackRock',
        'counterparty': 'Institutional',
        'hours_ago': 12,
    },
    {
        'symbol': 'LT',
        'company_name': 'Larsen & Toubro',
        'exchange': 'NSE',
        'deal_type': 'bulk',
        'side': 'SELL',
        'price': Decimal('3580.00'),
        'quantity': 320000,
        'value_cr': Decimal('114.56'),
        'ltp': Decimal('3595.00'),
        'premium_percent': Decimal('-0.42'),
        'client_name': 'Foreign Portfolio',
        'counterparty': 'Domestic MF',
        'hours_ago': 14,
    },
]

DARK_SEED = [
    {
        'symbol': 'RELIANCE',
        'company_name': 'Reliance Industries',
        'venue': 'NSE Dark / Negotiated',
        'price': Decimal('2890.25'),
        'quantity': 1850000,
        'value_cr': Decimal('534.70'),
        'vwap': Decimal('2886.10'),
        'vs_vwap_percent': Decimal('0.14'),
        'bias': 'buy',
        'note': 'Large negotiated print above session VWAP',
        'hours_ago': 1,
    },
    {
        'symbol': 'HDFCBANK',
        'company_name': 'HDFC Bank',
        'venue': 'BSE Dark / Negotiated',
        'price': Decimal('1675.80'),
        'quantity': 1420000,
        'value_cr': Decimal('237.96'),
        'vwap': Decimal('1681.20'),
        'vs_vwap_percent': Decimal('-0.32'),
        'bias': 'sell',
        'note': 'Institutional distribution under VWAP',
        'hours_ago': 2,
    },
    {
        'symbol': 'TCS',
        'company_name': 'Tata Consultancy Services',
        'venue': 'NSE Dark / Negotiated',
        'price': Decimal('4118.00'),
        'quantity': 610000,
        'value_cr': Decimal('251.20'),
        'vwap': Decimal('4115.40'),
        'vs_vwap_percent': Decimal('0.06'),
        'bias': 'buy',
        'note': 'Quiet accumulation print',
        'hours_ago': 4,
    },
    {
        'symbol': 'INFY',
        'company_name': 'Infosys',
        'venue': 'NSE Dark / Negotiated',
        'price': Decimal('1532.40'),
        'quantity': 980000,
        'value_cr': Decimal('150.18'),
        'vwap': Decimal('1530.00'),
        'vs_vwap_percent': Decimal('0.16'),
        'bias': 'buy',
        'note': 'IT basket dark print',
        'hours_ago': 5,
    },
    {
        'symbol': 'BAJFINANCE',
        'company_name': 'Bajaj Finance',
        'venue': 'NSE Dark / Negotiated',
        'price': Decimal('7125.00'),
        'quantity': 210000,
        'value_cr': Decimal('149.63'),
        'vwap': Decimal('7150.20'),
        'vs_vwap_percent': Decimal('-0.35'),
        'bias': 'sell',
        'note': 'NBFC supply in dark venue',
        'hours_ago': 7,
    },
    {
        'symbol': 'AXISBANK',
        'company_name': 'Axis Bank',
        'venue': 'BSE Dark / Negotiated',
        'price': Decimal('1188.50'),
        'quantity': 1250000,
        'value_cr': Decimal('148.56'),
        'vwap': Decimal('1186.00'),
        'vs_vwap_percent': Decimal('0.21'),
        'bias': 'buy',
        'note': 'Banking sector dark accumulation',
        'hours_ago': 9,
    },
    {
        'symbol': 'ITC',
        'company_name': 'ITC Limited',
        'venue': 'NSE Dark / Negotiated',
        'price': Decimal('448.20'),
        'quantity': 4200000,
        'value_cr': Decimal('188.24'),
        'vwap': Decimal('447.60'),
        'vs_vwap_percent': Decimal('0.13'),
        'bias': 'mixed',
        'note': 'Two-way institutional flow',
        'hours_ago': 11,
    },
]


class Command(BaseCommand):
    help = 'Seed block deals and dark pool prints for trackers'

    def handle(self, *args, **options):
        now = timezone.now()
        BlockDeal.objects.all().delete()
        DarkPoolPrint.objects.all().delete()

        for raw in BLOCK_SEED:
            item = dict(raw)
            hours = item.pop('hours_ago')
            BlockDeal.objects.create(**item, traded_at=now - timedelta(hours=hours))

        for raw in DARK_SEED:
            item = dict(raw)
            hours = item.pop('hours_ago')
            DarkPoolPrint.objects.create(**item, print_time=now - timedelta(hours=hours))

        self.stdout.write(
            self.style.SUCCESS(
                f'Seeded {len(BLOCK_SEED)} block deals and {len(DARK_SEED)} dark pool prints.'
            )
        )
