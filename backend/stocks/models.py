import uuid
from decimal import Decimal

from django.conf import settings
from django.db import models


class Stock(models.Model):
    symbol = models.CharField(max_length=20, unique=True, db_index=True)
    name = models.CharField(max_length=120)
    exchange = models.CharField(max_length=10, default='NSE')
    sector = models.CharField(max_length=60)
    ltp = models.DecimalField(max_digits=12, decimal_places=2)
    change = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    change_percent = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    open_price = models.DecimalField(max_digits=12, decimal_places=2)
    high = models.DecimalField(max_digits=12, decimal_places=2)
    low = models.DecimalField(max_digits=12, decimal_places=2)
    previous_close = models.DecimalField(max_digits=12, decimal_places=2)
    volume = models.BigIntegerField(default=0)
    market_cap_cr = models.DecimalField(max_digits=16, decimal_places=2, default=0)
    pe = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    eps = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    week52_high = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    week52_low = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    roe = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    debt_to_equity = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    revenue_growth = models.DecimalField(max_digits=8, decimal_places=2, default=0)

    def __str__(self):
        return self.symbol


class StockCandle(models.Model):
    class Interval(models.TextChoices):
        M1 = '1m', '1 Minute'
        M5 = '5m', '5 Minutes'
        M30 = '30m', '30 Minutes'
        H1 = '1h', '1 Hour'
        D1 = '1d', '1 Day'
        D90 = '90d', '90 Days'

    stock = models.ForeignKey(Stock, on_delete=models.CASCADE, related_name='candles')
    time = models.DateTimeField()
    open_price = models.DecimalField(max_digits=12, decimal_places=2)
    high = models.DecimalField(max_digits=12, decimal_places=2)
    low = models.DecimalField(max_digits=12, decimal_places=2)
    close = models.DecimalField(max_digits=12, decimal_places=2)
    volume = models.BigIntegerField(default=0)
    interval = models.CharField(max_length=5, choices=Interval.choices, default=Interval.D1)

    class Meta:
        ordering = ['time']
        indexes = [models.Index(fields=['stock', 'interval', 'time'])]


class WatchlistItem(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='watchlist_items'
    )
    stock = models.ForeignKey(Stock, on_delete=models.CASCADE)
    added_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'stock')
        ordering = ['-added_at']


class StockHolding(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='stock_holdings'
    )
    stock = models.ForeignKey(Stock, on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField()
    avg_price = models.DecimalField(max_digits=12, decimal_places=2)

    class Meta:
        unique_together = ('user', 'stock')


class PaperWallet(models.Model):
    """Isolated virtual cash ledger for equity paper trading.

    Deliberately separate from finance.Wallet (real money — Cashfree deposits
    /payouts). Paper trading must never touch real funds; this gives each
    learner a fixed practice balance that's debited/credited exactly like a
    real order pad, so buying power constraints are actually taught.
    """

    DEFAULT_STARTING_BALANCE = Decimal('1000000.00')

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='paper_wallet'
    )
    balance = models.DecimalField(max_digits=14, decimal_places=2, default=DEFAULT_STARTING_BALANCE)
    starting_balance = models.DecimalField(max_digits=14, decimal_places=2, default=DEFAULT_STARTING_BALANCE)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @classmethod
    def get_or_create_for(cls, user):
        return cls.objects.get_or_create(
            user=user,
            defaults={
                'balance': cls.DEFAULT_STARTING_BALANCE,
                'starting_balance': cls.DEFAULT_STARTING_BALANCE,
            },
        )[0]


class PriceAlert(models.Model):
    class Condition(models.TextChoices):
        ABOVE = 'above', 'Above'
        BELOW = 'below', 'Below'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='price_alerts'
    )
    stock = models.ForeignKey(Stock, on_delete=models.CASCADE)
    target_price = models.DecimalField(max_digits=12, decimal_places=2)
    condition = models.CharField(max_length=10, choices=Condition.choices)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)


class NewsAlert(models.Model):
    """Watch keywords / symbols and notify when matching market news appears."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='news_alerts'
    )
    keyword = models.CharField(max_length=80, help_text='Symbol or keyword, e.g. RELIANCE or RBI')
    is_active = models.BooleanField(default=True)
    last_matched_at = models.DateTimeField(null=True, blank=True)
    last_matched_title = models.CharField(max_length=300, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        unique_together = ('user', 'keyword')


class SipPlan(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='sip_plans'
    )
    stock = models.ForeignKey(Stock, on_delete=models.CASCADE)
    monthly_amount = models.DecimalField(max_digits=12, decimal_places=2)
    installments_done = models.PositiveIntegerField(default=0)
    total_installments = models.PositiveIntegerField(default=12)
    total_invested = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    current_value = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    next_date = models.DateField()
    is_active = models.BooleanField(default=True)


class PaperTrade(models.Model):
    class Side(models.TextChoices):
        BUY = 'BUY', 'Buy'
        SELL = 'SELL', 'Sell'

    class Status(models.TextChoices):
        EXECUTED = 'Executed', 'Executed'
        PENDING = 'Pending', 'Pending'
        CANCELLED = 'Cancelled', 'Cancelled'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='paper_trades'
    )
    stock = models.ForeignKey(Stock, on_delete=models.CASCADE)
    side = models.CharField(max_length=4, choices=Side.choices)
    quantity = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=12, decimal_places=2)
    avg_cost = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    realized_pnl = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.EXECUTED)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class StockNews(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=300)
    summary = models.TextField()
    source = models.CharField(max_length=80)
    published_at = models.DateTimeField()
    related_symbols = models.JSONField(default=list)
    category = models.CharField(max_length=40, default='market')
    stock = models.ForeignKey(
        Stock, null=True, blank=True, on_delete=models.SET_NULL, related_name='news'
    )

    class Meta:
        ordering = ['-published_at']


class OptionContract(models.Model):
    class OptionType(models.TextChoices):
        CE = 'CE', 'Call'
        PE = 'PE', 'Put'

    underlying = models.CharField(max_length=20, db_index=True)
    strike = models.DecimalField(max_digits=12, decimal_places=2)
    option_type = models.CharField(max_length=2, choices=OptionType.choices)
    ltp = models.DecimalField(max_digits=12, decimal_places=2)
    change = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    oi = models.BigIntegerField(default=0)
    volume = models.BigIntegerField(default=0)
    expiry = models.DateField()

    class Meta:
        indexes = [models.Index(fields=['underlying', 'expiry'])]


class DividendRecord(models.Model):
    class Status(models.TextChoices):
        UPCOMING = 'Upcoming', 'Upcoming'
        PAID = 'Paid', 'Paid'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='dividends'
    )
    stock = models.ForeignKey(Stock, on_delete=models.CASCADE)
    amount_per_share = models.DecimalField(max_digits=8, decimal_places=2)
    ex_date = models.DateField()
    payment_date = models.DateField()
    shares_held = models.PositiveIntegerField(default=0)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.UPCOMING)


class CommodityHolding(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='commodity_holdings'
    )
    commodity_id = models.CharField(max_length=20, db_index=True)
    quantity = models.PositiveIntegerField()
    avg_price_usd = models.DecimalField(max_digits=12, decimal_places=2)

    class Meta:
        unique_together = ('user', 'commodity_id')


class CommodityTrade(models.Model):
    class Side(models.TextChoices):
        BUY = 'BUY', 'Buy'
        SELL = 'SELL', 'Sell'

    class Status(models.TextChoices):
        EXECUTED = 'Executed', 'Executed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='commodity_trades'
    )
    commodity_id = models.CharField(max_length=20, db_index=True)
    side = models.CharField(max_length=4, choices=Side.choices)
    quantity = models.PositiveIntegerField()
    price_usd = models.DecimalField(max_digits=12, decimal_places=2)
    amount_inr = models.DecimalField(max_digits=14, decimal_places=2)
    usd_inr_rate = models.DecimalField(max_digits=8, decimal_places=2)
    avg_cost_usd = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class OptionHolding(models.Model):
    class AssetClass(models.TextChoices):
        EQUITY_FNO = 'equity_fno', 'Equity F&O'
        COMMODITY = 'commodity', 'Commodity'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='option_holdings'
    )
    underlying = models.CharField(max_length=20, db_index=True)
    asset_class = models.CharField(max_length=20, choices=AssetClass.choices, default=AssetClass.EQUITY_FNO)
    strike = models.DecimalField(max_digits=12, decimal_places=4)
    option_type = models.CharField(max_length=2)
    expiry = models.DateField()
    quantity = models.PositiveIntegerField()
    avg_premium = models.DecimalField(max_digits=12, decimal_places=4)
    lot_size = models.PositiveIntegerField(default=1)

    class Meta:
        unique_together = ('user', 'underlying', 'strike', 'option_type', 'expiry', 'asset_class')


class OptionTrade(models.Model):
    class Side(models.TextChoices):
        BUY = 'BUY', 'Buy'
        SELL = 'SELL', 'Sell'

    class Status(models.TextChoices):
        EXECUTED = 'Executed', 'Executed'

    class AssetClass(models.TextChoices):
        EQUITY_FNO = 'equity_fno', 'Equity F&O'
        COMMODITY = 'commodity', 'Commodity'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='option_trades'
    )
    underlying = models.CharField(max_length=20, db_index=True)
    asset_class = models.CharField(max_length=20, choices=AssetClass.choices, default=AssetClass.EQUITY_FNO)
    strike = models.DecimalField(max_digits=12, decimal_places=4)
    option_type = models.CharField(max_length=2)
    expiry = models.DateField()
    side = models.CharField(max_length=4, choices=Side.choices)
    quantity = models.PositiveIntegerField()
    premium = models.DecimalField(max_digits=12, decimal_places=4)
    lot_size = models.PositiveIntegerField(default=1)
    amount_inr = models.DecimalField(max_digits=14, decimal_places=2)
    avg_premium = models.DecimalField(max_digits=12, decimal_places=4, null=True, blank=True)
    realized_pnl_inr = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.EXECUTED)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class IpoEvent(models.Model):
    class Status(models.TextChoices):
        UPCOMING = 'upcoming', 'Upcoming'
        OPEN = 'open', 'Open Now'
        CLOSED = 'closed', 'Closed'
        LISTED = 'listed', 'Listed'

    id = models.CharField(primary_key=True, max_length=40)
    company_name = models.CharField(max_length=160)
    symbol = models.CharField(max_length=20, blank=True)
    sector = models.CharField(max_length=80)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.UPCOMING)
    open_date = models.DateField(null=True, blank=True)
    close_date = models.DateField(null=True, blank=True)
    listing_date = models.DateField(null=True, blank=True)
    price_band_min = models.DecimalField(max_digits=12, decimal_places=2)
    price_band_max = models.DecimalField(max_digits=12, decimal_places=2)
    issue_size_cr = models.DecimalField(max_digits=10, decimal_places=2)
    lot_size = models.PositiveIntegerField(default=1)
    min_investment = models.DecimalField(max_digits=12, decimal_places=2)
    gmp_percent = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    subscription_times = models.CharField(max_length=20, blank=True)
    exchange = models.CharField(max_length=10, default='NSE')
    is_featured = models.BooleanField(default=False)
    description = models.TextField(blank=True)

    class Meta:
        ordering = ['open_date', 'listing_date']
        verbose_name = 'IPO event'


class IpoHolding(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='ipo_holdings'
    )
    ipo = models.ForeignKey(IpoEvent, on_delete=models.CASCADE, related_name='holdings')
    lots = models.PositiveIntegerField()
    quantity = models.PositiveIntegerField()
    avg_price = models.DecimalField(max_digits=12, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'ipo')


class IpoTrade(models.Model):
    class Side(models.TextChoices):
        APPLY = 'APPLY', 'Apply'
        SELL = 'SELL', 'Sell'

    class Status(models.TextChoices):
        EXECUTED = 'Executed', 'Executed'
        CANCELLED = 'Cancelled', 'Cancelled'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='ipo_trades'
    )
    ipo = models.ForeignKey(IpoEvent, on_delete=models.CASCADE, related_name='trades')
    side = models.CharField(max_length=8, choices=Side.choices)
    lots = models.PositiveIntegerField(default=1)
    quantity = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=12, decimal_places=2)
    amount_inr = models.DecimalField(max_digits=14, decimal_places=2)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.EXECUTED)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class TraderNote(models.Model):
    class Category(models.TextChoices):
        GENERAL = 'general', 'General'
        STOCK = 'stock', 'Stock'
        TRADE_IDEA = 'trade_idea', 'Trade Idea'
        JOURNAL = 'journal', 'Journal'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='trader_notes'
    )
    title = models.CharField(max_length=200)
    body = models.TextField()
    symbol = models.CharField(max_length=20, blank=True, default='')
    category = models.CharField(
        max_length=20, choices=Category.choices, default=Category.GENERAL
    )
    is_pinned = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-is_pinned', '-updated_at']
        indexes = [
            models.Index(fields=['user', 'category', '-updated_at']),
            models.Index(fields=['user', '-updated_at']),
        ]


class CopyTraderProfile(models.Model):
    """Public verified trader whose method others can copy."""

    class RiskLevel(models.TextChoices):
        LOW = 'low', 'Low'
        MEDIUM = 'medium', 'Medium'
        HIGH = 'high', 'High'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='copy_trader_profile',
    )
    display_name = models.CharField(max_length=80)
    handle = models.SlugField(max_length=40, unique=True)
    avatar_color = models.CharField(max_length=7, default='#10B981')
    bio = models.TextField(blank=True, default='')
    strategy_title = models.CharField(max_length=120)
    strategy_summary = models.TextField()
    method_tags = models.JSONField(default=list)
    risk_level = models.CharField(
        max_length=10, choices=RiskLevel.choices, default=RiskLevel.MEDIUM
    )
    is_verified = models.BooleanField(default=True)
    is_active = models.BooleanField(default=True)
    return_1m = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    return_3m = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    return_1y = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    win_rate = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    max_drawdown = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    followers_count = models.PositiveIntegerField(default=0)
    aum_inr = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    min_copy_amount = models.DecimalField(max_digits=12, decimal_places=2, default=5000)
    experience_years = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-return_3m', '-followers_count']

    def __str__(self):
        return f'{self.display_name} (@{self.handle})'


class CopyTraderTrade(models.Model):
    """Published trade from a verified trader's method feed."""

    class Side(models.TextChoices):
        BUY = 'BUY', 'Buy'
        SELL = 'SELL', 'Sell'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    trader = models.ForeignKey(
        CopyTraderProfile, on_delete=models.CASCADE, related_name='trades'
    )
    symbol = models.CharField(max_length=20)
    side = models.CharField(max_length=4, choices=Side.choices)
    quantity = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=12, decimal_places=2)
    pnl_percent = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    note = models.CharField(max_length=200, blank=True, default='')
    executed_at = models.DateTimeField()

    class Meta:
        ordering = ['-executed_at']


class CopySubscription(models.Model):
    """Follower copying a verified trader's method with an allocation."""

    class Status(models.TextChoices):
        ACTIVE = 'active', 'Active'
        PAUSED = 'paused', 'Paused'
        STOPPED = 'stopped', 'Stopped'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    follower = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='copy_subscriptions'
    )
    trader = models.ForeignKey(
        CopyTraderProfile, on_delete=models.CASCADE, related_name='subscriptions'
    )
    allocation_inr = models.DecimalField(max_digits=12, decimal_places=2)
    copy_ratio = models.DecimalField(max_digits=5, decimal_places=2, default=1)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.ACTIVE)
    auto_copy = models.BooleanField(default=True)
    copied_pnl = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    started_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-started_at']
        constraints = [
            models.UniqueConstraint(
                fields=['follower', 'trader'],
                condition=models.Q(status__in=['active', 'paused']),
                name='uniq_active_copy_subscription',
            )
        ]


class PaperCompetition(models.Model):
    """Invite friends to a timed paper-trading competition."""

    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        ACTIVE = 'active', 'Active'
        ENDED = 'ended', 'Ended'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    host = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='hosted_paper_competitions',
    )
    name = models.CharField(max_length=80)
    invite_code = models.CharField(max_length=10, unique=True, db_index=True)
    starting_balance = models.DecimalField(max_digits=14, decimal_places=2, default=1000000)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.OPEN)
    duration_days = models.PositiveIntegerField(default=7)
    starts_at = models.DateTimeField(auto_now_add=True)
    ends_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.name} ({self.invite_code})'


class PaperCompetitionMember(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    competition = models.ForeignKey(
        PaperCompetition, on_delete=models.CASCADE, related_name='members'
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='paper_competition_memberships',
    )
    display_name = models.CharField(max_length=80)
    equity = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    pnl = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    pnl_percent = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    trades_count = models.PositiveIntegerField(default=0)
    joined_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-pnl_percent', '-equity']
        unique_together = ('competition', 'user')


class BlockDeal(models.Model):
    """NSE/BSE reported block / bulk deals."""

    class DealType(models.TextChoices):
        BLOCK = 'block', 'Block Deal'
        BULK = 'bulk', 'Bulk Deal'

    class Side(models.TextChoices):
        BUY = 'BUY', 'Buy'
        SELL = 'SELL', 'Sell'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    symbol = models.CharField(max_length=20, db_index=True)
    company_name = models.CharField(max_length=120)
    exchange = models.CharField(max_length=10, default='NSE')
    deal_type = models.CharField(max_length=10, choices=DealType.choices, default=DealType.BLOCK)
    side = models.CharField(max_length=4, choices=Side.choices, default=Side.BUY)
    price = models.DecimalField(max_digits=12, decimal_places=2)
    quantity = models.PositiveIntegerField()
    value_cr = models.DecimalField(max_digits=14, decimal_places=2)
    ltp = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    premium_percent = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    client_name = models.CharField(max_length=120, blank=True, default='')
    counterparty = models.CharField(max_length=120, blank=True, default='Institutional')
    traded_at = models.DateTimeField(db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-traded_at', '-value_cr']


class PaperOrder(models.Model):
    """Paper-trading order book — the resting/working order, distinct from
    `PaperTrade` (the executed fill). MARKET orders execute immediately and
    go straight to EXECUTED; LIMIT/SL-M/SL orders sit PENDING until
    `paper_order_service.process_pending_paper_orders()` matches them against
    live LTP (called opportunistically on every order-book read/place, and
    by the `--paper-orders` management-command flag for real cron setups).

    Never touches the real broker or `finance.Wallet` — see `PaperWallet`.
    """

    class Side(models.TextChoices):
        BUY = 'BUY', 'Buy'
        SELL = 'SELL', 'Sell'

    class OrderType(models.TextChoices):
        MARKET = 'MARKET', 'Market'
        LIMIT = 'LIMIT', 'Limit'
        SL_M = 'SL-M', 'Stop-Loss Market'
        SL = 'SL', 'Stop-Loss Limit'

    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        EXECUTED = 'EXECUTED', 'Executed'
        CANCELLED = 'CANCELLED', 'Cancelled'
        REJECTED = 'REJECTED', 'Rejected'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='paper_orders'
    )
    stock = models.ForeignKey(Stock, on_delete=models.CASCADE, related_name='paper_orders')
    side = models.CharField(max_length=4, choices=Side.choices)
    order_type = models.CharField(max_length=10, choices=OrderType.choices, default=OrderType.MARKET)
    quantity = models.PositiveIntegerField()
    limit_price = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    trigger_price = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    executed_price = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    charges = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0'))
    reject_reason = models.CharField(max_length=200, blank=True, default='')
    trade = models.ForeignKey(
        'PaperTrade', on_delete=models.SET_NULL, null=True, blank=True, related_name='order'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    executed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['status', 'order_type']),
            models.Index(fields=['user', 'created_at']),
        ]

    @property
    def is_pending(self) -> bool:
        return self.status == self.Status.PENDING


class PaperLedgerEntry(models.Model):
    """Immutable virtual funds transaction ledger — every credit/debit to a
    user's `PaperWallet` gets a row here (reset, buy, sell, charges), so the
    running balance is always auditable independent of `PaperWallet.balance`.
    """

    class EntryType(models.TextChoices):
        RESET = 'RESET', 'Account Reset'
        BUY = 'BUY', 'Buy Debit'
        SELL = 'SELL', 'Sell Credit'
        CHARGE = 'CHARGE', 'Trading Charges'
        ADJUSTMENT = 'ADJUSTMENT', 'Adjustment'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='paper_ledger_entries'
    )
    entry_type = models.CharField(max_length=12, choices=EntryType.choices)
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    balance_after = models.DecimalField(max_digits=14, decimal_places=2)
    description = models.CharField(max_length=200, blank=True, default='')
    order = models.ForeignKey(
        PaperOrder, on_delete=models.SET_NULL, null=True, blank=True, related_name='ledger_entries'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['user', 'created_at'])]


class PaperJournalEntry(models.Model):
    """Trading journal — structured reflection notes a learner attaches to a
    paper trade (or a free-standing idea), separate from the generic
    `TraderNote` model which isn't paper-trading specific.
    """

    class Mood(models.TextChoices):
        CONFIDENT = 'confident', 'Confident'
        NEUTRAL = 'neutral', 'Neutral'
        ANXIOUS = 'anxious', 'Anxious'
        FOMO = 'fomo', 'FOMO'
        DISCIPLINED = 'disciplined', 'Disciplined'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='paper_journal_entries'
    )
    trade = models.ForeignKey(
        PaperTrade, on_delete=models.SET_NULL, null=True, blank=True, related_name='journal_entries'
    )
    symbol = models.CharField(max_length=20, blank=True, default='')
    title = models.CharField(max_length=120)
    notes = models.TextField(blank=True, default='')
    lesson_learned = models.TextField(blank=True, default='')
    mood = models.CharField(max_length=12, choices=Mood.choices, blank=True, default='')
    rating = models.PositiveSmallIntegerField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['user', 'created_at'])]


class PaperEquitySnapshot(models.Model):
    """One equity data point per user per day (balance + mark-to-market
    holdings value) — the raw series behind the equity curve, drawdown, and
    other performance analytics. Populated by
    `paper_analytics_service.record_daily_snapshot()`, called opportunistically
    from the analytics/dashboard endpoints and by the `--paper-orders` cron.
    """

    id = models.BigAutoField(primary_key=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='paper_equity_snapshots'
    )
    date = models.DateField()
    balance = models.DecimalField(max_digits=14, decimal_places=2)
    holdings_value = models.DecimalField(max_digits=14, decimal_places=2)
    equity = models.DecimalField(max_digits=14, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['date']
        unique_together = ('user', 'date')
        indexes = [models.Index(fields=['user', 'date'])]


class PaperRiskLimit(models.Model):
    """Per-user configurable practice risk limits — daily loss cap and
    max single-position sizing, purely advisory (never blocks an order),
    surfaced as warnings on the dashboard so learners build risk discipline.
    """

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='paper_risk_limit'
    )
    max_daily_loss = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True)
    max_position_size_percent = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal('20.00'))
    is_active = models.BooleanField(default=True)
    last_daily_warning_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @classmethod
    def get_or_create_for(cls, user):
        return cls.objects.get_or_create(
            user=user,
            defaults={'max_daily_loss': PaperWallet.DEFAULT_STARTING_BALANCE * Decimal('0.05')},
        )[0]


class PaperOptionHolding(models.Model):
    """Paper F&O / commodity-option position — mirrors `OptionHolding` but is
    settled entirely against `PaperWallet`. Kept as a distinct model (rather
    than reusing `OptionHolding`) so paper and real option books can never
    cross-contaminate, matching the same isolation `PaperWallet` gives
    equities."""

    class AssetClass(models.TextChoices):
        EQUITY_FNO = 'equity_fno', 'Equity F&O'
        COMMODITY = 'commodity', 'Commodity'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='paper_option_holdings'
    )
    underlying = models.CharField(max_length=20, db_index=True)
    asset_class = models.CharField(max_length=20, choices=AssetClass.choices, default=AssetClass.EQUITY_FNO)
    strike = models.DecimalField(max_digits=12, decimal_places=4)
    option_type = models.CharField(max_length=2)
    expiry = models.DateField()
    quantity = models.PositiveIntegerField()
    avg_premium = models.DecimalField(max_digits=12, decimal_places=4)
    lot_size = models.PositiveIntegerField(default=1)

    class Meta:
        unique_together = ('user', 'underlying', 'strike', 'option_type', 'expiry', 'asset_class')
        indexes = [models.Index(fields=['user', 'underlying'])]


class PaperOptionOrder(models.Model):
    """Executed paper option fill — options are immediate-execution in this
    app (real `OptionTrade` has no resting order book either), so this
    doubles as both the order and the trade record."""

    class Side(models.TextChoices):
        BUY = 'BUY', 'Buy'
        SELL = 'SELL', 'Sell'

    class AssetClass(models.TextChoices):
        EQUITY_FNO = 'equity_fno', 'Equity F&O'
        COMMODITY = 'commodity', 'Commodity'

    class Status(models.TextChoices):
        EXECUTED = 'EXECUTED', 'Executed'
        REJECTED = 'REJECTED', 'Rejected'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='paper_option_orders'
    )
    underlying = models.CharField(max_length=20, db_index=True)
    asset_class = models.CharField(max_length=20, choices=AssetClass.choices, default=AssetClass.EQUITY_FNO)
    strike = models.DecimalField(max_digits=12, decimal_places=4)
    option_type = models.CharField(max_length=2)
    expiry = models.DateField()
    side = models.CharField(max_length=4, choices=Side.choices)
    quantity = models.PositiveIntegerField()
    premium = models.DecimalField(max_digits=12, decimal_places=4)
    lot_size = models.PositiveIntegerField(default=1)
    amount_inr = models.DecimalField(max_digits=14, decimal_places=2)
    avg_premium = models.DecimalField(max_digits=12, decimal_places=4, null=True, blank=True)
    realized_pnl_inr = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True)
    charges = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0'))
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.EXECUTED)
    reject_reason = models.CharField(max_length=200, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'created_at']),
            models.Index(fields=['user', 'underlying']),
        ]


class PaperCommodityHolding(models.Model):
    """Paper commodity position — mirrors `CommodityHolding`, settled
    against `PaperWallet`."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='paper_commodity_holdings'
    )
    commodity_id = models.CharField(max_length=20, db_index=True)
    quantity = models.PositiveIntegerField()
    avg_price_usd = models.DecimalField(max_digits=14, decimal_places=4)

    class Meta:
        unique_together = ('user', 'commodity_id')


class PaperCommodityOrder(models.Model):
    """Executed paper commodity fill — immediate-execution, mirrors
    `CommodityTrade`."""

    class Side(models.TextChoices):
        BUY = 'BUY', 'Buy'
        SELL = 'SELL', 'Sell'

    class Status(models.TextChoices):
        EXECUTED = 'EXECUTED', 'Executed'
        REJECTED = 'REJECTED', 'Rejected'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='paper_commodity_orders'
    )
    commodity_id = models.CharField(max_length=20, db_index=True)
    side = models.CharField(max_length=4, choices=Side.choices)
    quantity = models.PositiveIntegerField()
    price_usd = models.DecimalField(max_digits=14, decimal_places=4)
    amount_inr = models.DecimalField(max_digits=14, decimal_places=2)
    usd_inr_rate = models.DecimalField(max_digits=10, decimal_places=4)
    avg_cost_usd = models.DecimalField(max_digits=14, decimal_places=4, null=True, blank=True)
    realized_pnl_inr = models.DecimalField(max_digits=14, decimal_places=2, null=True, blank=True)
    charges = models.DecimalField(max_digits=12, decimal_places=2, default=Decimal('0'))
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.EXECUTED)
    reject_reason = models.CharField(max_length=200, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['user', 'created_at'])]


class DarkPoolPrint(models.Model):
    """Large off-exchange / dark-pool style institutional prints."""

    class Bias(models.TextChoices):
        BUY = 'buy', 'Buy-biased'
        SELL = 'sell', 'Sell-biased'
        MIXED = 'mixed', 'Mixed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    symbol = models.CharField(max_length=20, db_index=True)
    company_name = models.CharField(max_length=120)
    venue = models.CharField(max_length=40, default='Dark Pool')
    price = models.DecimalField(max_digits=12, decimal_places=2)
    quantity = models.PositiveIntegerField()
    value_cr = models.DecimalField(max_digits=14, decimal_places=2)
    vwap = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    vs_vwap_percent = models.DecimalField(max_digits=8, decimal_places=2, default=0)
    bias = models.CharField(max_length=10, choices=Bias.choices, default=Bias.MIXED)
    print_time = models.DateTimeField(db_index=True)
    note = models.CharField(max_length=200, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-print_time', '-value_cr']

