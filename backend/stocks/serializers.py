from decimal import Decimal

from rest_framework import serializers

from core.serializers import CamelCaseModelSerializer, CamelCaseSerializer
from .models import (
    DividendRecord,
    NewsAlert,
    OptionContract,
    PaperTrade,
    PriceAlert,
    SipPlan,
    Stock,
    StockCandle,
    StockHolding,
    StockNews,
    TraderNote,
)


class StockSerializer(CamelCaseModelSerializer):
    open = serializers.DecimalField(source='open_price', max_digits=12, decimal_places=2)

    class Meta:
        model = Stock
        fields = (
            'symbol', 'name', 'exchange', 'sector', 'ltp', 'change', 'change_percent',
            'open', 'high', 'low', 'previous_close', 'volume', 'market_cap_cr',
            'pe', 'eps', 'week52_high', 'week52_low',
        )


class StockCandleSerializer(CamelCaseModelSerializer):
    open = serializers.DecimalField(source='open_price', max_digits=12, decimal_places=2)
    time = serializers.DateTimeField()

    class Meta:
        model = StockCandle
        fields = ('time', 'open', 'high', 'low', 'close', 'volume')


class StockHoldingSerializer(CamelCaseModelSerializer):
    symbol = serializers.CharField(source='stock.symbol')
    name = serializers.CharField(source='stock.name')
    ltp = serializers.DecimalField(source='stock.ltp', max_digits=12, decimal_places=2)

    class Meta:
        model = StockHolding
        fields = ('symbol', 'name', 'quantity', 'avg_price', 'ltp')


class StockNewsSerializer(CamelCaseSerializer):
    id = serializers.CharField()
    title = serializers.CharField()
    summary = serializers.CharField()
    source = serializers.CharField()
    published_at = serializers.DateTimeField()
    related_symbols = serializers.ListField(child=serializers.CharField())
    category = serializers.CharField()
    url = serializers.URLField(required=False, allow_blank=True)
    image_url = serializers.URLField(required=False, allow_blank=True)

    def to_representation(self, instance):
        if isinstance(instance, dict):
            return super().to_representation(instance)
        return super().to_representation(
            {
                'id': str(instance.id),
                'title': instance.title,
                'summary': instance.summary,
                'source': instance.source,
                'published_at': instance.published_at,
                'related_symbols': instance.related_symbols,
                'category': instance.category,
                'url': '',
                'image_url': '',
            }
        )


class StockNewsModelSerializer(CamelCaseModelSerializer):
    published_at = serializers.DateTimeField()
    related_symbols = serializers.ListField(child=serializers.CharField())

    class Meta:
        model = StockNews
        fields = ('id', 'title', 'summary', 'source', 'published_at', 'related_symbols', 'category')


class PriceAlertSerializer(CamelCaseModelSerializer):
    symbol = serializers.CharField(source='stock.symbol')
    name = serializers.CharField(source='stock.name')

    class Meta:
        model = PriceAlert
        fields = ('id', 'symbol', 'name', 'target_price', 'condition', 'is_active')


class CreateAlertSerializer(CamelCaseSerializer):
    symbol = serializers.CharField()
    target_price = serializers.DecimalField(max_digits=12, decimal_places=2)
    condition = serializers.ChoiceField(choices=['above', 'below'])


class NewsAlertSerializer(CamelCaseModelSerializer):
    class Meta:
        model = NewsAlert
        fields = ('id', 'keyword', 'is_active', 'last_matched_at', 'last_matched_title', 'created_at')


class CreateNewsAlertSerializer(CamelCaseSerializer):
    keyword = serializers.CharField(max_length=80)


class SipPlanSerializer(CamelCaseModelSerializer):
    symbol = serializers.CharField(source='stock.symbol')
    name = serializers.CharField(source='stock.name')
    next_date = serializers.DateField()

    class Meta:
        model = SipPlan
        fields = (
            'id', 'symbol', 'name', 'monthly_amount', 'installments_done',
            'total_installments', 'total_invested', 'current_value', 'next_date',
        )


class CreateSipSerializer(CamelCaseSerializer):
    symbol = serializers.CharField()
    monthly_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    total_installments = serializers.IntegerField(default=12, min_value=1)


class OptionContractSerializer(CamelCaseSerializer):
    symbol = serializers.CharField()
    strike = serializers.DecimalField(max_digits=12, decimal_places=2)
    type = serializers.CharField()
    ltp = serializers.DecimalField(max_digits=12, decimal_places=2)
    change = serializers.DecimalField(max_digits=12, decimal_places=2)
    oi = serializers.IntegerField()
    volume = serializers.IntegerField()
    expiry = serializers.DateField()

    def to_representation(self, instance):
        if isinstance(instance, dict):
            data = {
                'symbol': instance.get('symbol', ''),
                'strike': instance['strike'],
                'type': instance.get('type') or instance.get('option_type', ''),
                'ltp': instance['ltp'],
                'change': instance['change'],
                'oi': instance['oi'],
                'volume': instance['volume'],
                'expiry': instance['expiry'],
            }
            return super().to_representation(data)
        return super().to_representation(
            {
                'symbol': instance.underlying,
                'strike': instance.strike,
                'type': instance.option_type,
                'ltp': instance.ltp,
                'change': instance.change,
                'oi': instance.oi,
                'volume': instance.volume,
                'expiry': instance.expiry,
            }
        )


class OptionContractModelSerializer(CamelCaseModelSerializer):
    symbol = serializers.CharField(source='underlying')
    type = serializers.CharField(source='option_type')

    class Meta:
        model = OptionContract
        fields = ('symbol', 'strike', 'type', 'ltp', 'change', 'oi', 'volume', 'expiry')


class PaperTradeSerializer(CamelCaseModelSerializer):
    symbol = serializers.CharField(source='stock.symbol')
    time = serializers.DateTimeField(source='created_at')

    class Meta:
        model = PaperTrade
        fields = ('id', 'symbol', 'side', 'quantity', 'price', 'time', 'status')


class PaperOrderSerializer(CamelCaseSerializer):
    symbol = serializers.CharField()
    side = serializers.ChoiceField(choices=['BUY', 'SELL'])
    quantity = serializers.IntegerField(min_value=1)


class CommodityOrderSerializer(CamelCaseSerializer):
    commodity_id = serializers.CharField()
    side = serializers.ChoiceField(choices=['BUY', 'SELL'])
    quantity = serializers.IntegerField(min_value=1)


class OptionOrderSerializer(CamelCaseSerializer):
    underlying = serializers.CharField()
    strike = serializers.DecimalField(max_digits=12, decimal_places=4)
    option_type = serializers.CharField()
    expiry = serializers.DateField()
    side = serializers.ChoiceField(choices=['BUY', 'SELL'])
    quantity = serializers.IntegerField(min_value=1)
    premium = serializers.DecimalField(max_digits=12, decimal_places=4)
    asset_class = serializers.ChoiceField(
        choices=['equity_fno', 'commodity'],
        default='equity_fno',
        required=False,
    )


class ScreenerStockSerializer(CamelCaseSerializer):
    stock = StockSerializer()
    roe = serializers.DecimalField(max_digits=8, decimal_places=2)
    debt_to_equity = serializers.DecimalField(max_digits=8, decimal_places=2)
    revenue_growth = serializers.DecimalField(max_digits=8, decimal_places=2)

    def to_representation(self, instance):
        return {
            'stock': StockSerializer(instance).data,
            'roe': float(instance.roe),
            'debtToEquity': float(instance.debt_to_equity),
            'revenueGrowth': float(instance.revenue_growth),
        }


class DividendSerializer(CamelCaseModelSerializer):
    symbol = serializers.CharField(source='stock.symbol')
    name = serializers.CharField(source='stock.name')

    class Meta:
        model = DividendRecord
        fields = (
            'symbol', 'name', 'amount_per_share', 'ex_date',
            'payment_date', 'shares_held', 'status',
        )


class TraderNoteSerializer(CamelCaseModelSerializer):
    created_at = serializers.DateTimeField()
    updated_at = serializers.DateTimeField()

    class Meta:
        model = TraderNote
        fields = (
            'id', 'title', 'body', 'symbol', 'category',
            'is_pinned', 'created_at', 'updated_at',
        )
        read_only_fields = ('id', 'created_at', 'updated_at')


class CreateTraderNoteSerializer(CamelCaseSerializer):
    title = serializers.CharField(max_length=200)
    body = serializers.CharField(allow_blank=True)
    symbol = serializers.CharField(max_length=20, required=False, allow_blank=True, default='')
    category = serializers.ChoiceField(
        choices=['general', 'stock', 'trade_idea', 'journal'],
        required=False,
        default='general',
    )
    is_pinned = serializers.BooleanField(required=False, default=False)


class UpdateTraderNoteSerializer(CamelCaseSerializer):
    title = serializers.CharField(max_length=200, required=False)
    body = serializers.CharField(required=False, allow_blank=True)
    symbol = serializers.CharField(max_length=20, required=False, allow_blank=True)
    category = serializers.ChoiceField(
        choices=['general', 'stock', 'trade_idea', 'journal'],
        required=False,
    )
    is_pinned = serializers.BooleanField(required=False)


class StartCopySerializer(CamelCaseSerializer):
    trader_id = serializers.UUIDField()
    allocation_inr = serializers.DecimalField(
        max_digits=12, decimal_places=2, min_value=Decimal('1')
    )
    copy_ratio = serializers.DecimalField(
        max_digits=5,
        decimal_places=2,
        required=False,
        default=Decimal('1'),
        min_value=Decimal('0.1'),
    )
    auto_copy = serializers.BooleanField(required=False, default=True)


class UpdateCopySubscriptionSerializer(CamelCaseSerializer):
    status = serializers.ChoiceField(
        choices=['active', 'paused', 'stopped'], required=False
    )
    allocation_inr = serializers.DecimalField(
        max_digits=12, decimal_places=2, required=False, min_value=Decimal('1')
    )
    auto_copy = serializers.BooleanField(required=False)


class CreatePaperCompetitionSerializer(CamelCaseSerializer):
    name = serializers.CharField(max_length=80, required=False, allow_blank=True, default='')
    starting_balance = serializers.DecimalField(
        max_digits=14, decimal_places=2, required=False, default=Decimal('100000'),
        min_value=Decimal('10000'),
    )
    duration_days = serializers.IntegerField(required=False, default=7, min_value=1, max_value=30)


class JoinPaperCompetitionSerializer(CamelCaseSerializer):
    invite_code = serializers.CharField(max_length=10)
