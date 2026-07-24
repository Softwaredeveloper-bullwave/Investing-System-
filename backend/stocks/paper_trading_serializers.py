"""Request serializers for the paper-trading order book, journal, and risk
limits. Response payloads are plain camelCase dicts built by the service
layer (`build_order_payload`, `build_journal_payload`, ...) — matching the
existing convention (`PaperOrderSerializer` in `serializers.py` is
request-only too, e.g. `PaperTradingOrdersView`).
"""

from rest_framework import serializers

from core.serializers import CamelCaseSerializer
from .models import PaperOrder


class PlaceOrderSerializer(CamelCaseSerializer):
    symbol = serializers.CharField()
    side = serializers.ChoiceField(choices=['BUY', 'SELL'])
    quantity = serializers.IntegerField(min_value=1)
    order_type = serializers.ChoiceField(
        choices=PaperOrder.OrderType.values, required=False, default=PaperOrder.OrderType.MARKET
    )
    limit_price = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, allow_null=True)
    trigger_price = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, allow_null=True)


class ModifyOrderSerializer(CamelCaseSerializer):
    quantity = serializers.IntegerField(min_value=1, required=False)
    limit_price = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, allow_null=True)
    trigger_price = serializers.DecimalField(max_digits=12, decimal_places=2, required=False, allow_null=True)


class ExitPositionSerializer(CamelCaseSerializer):
    symbol = serializers.CharField()


class CreateJournalEntrySerializer(CamelCaseSerializer):
    title = serializers.CharField(max_length=120)
    notes = serializers.CharField(required=False, allow_blank=True, default='')
    symbol = serializers.CharField(required=False, allow_blank=True, default='')
    trade_id = serializers.UUIDField(required=False, allow_null=True)
    lesson_learned = serializers.CharField(required=False, allow_blank=True, default='')
    mood = serializers.ChoiceField(
        choices=['confident', 'neutral', 'anxious', 'fomo', 'disciplined', ''],
        required=False, allow_blank=True, default='',
    )
    rating = serializers.IntegerField(required=False, allow_null=True, min_value=1, max_value=5)


class UpdateJournalEntrySerializer(CamelCaseSerializer):
    title = serializers.CharField(max_length=120, required=False)
    notes = serializers.CharField(required=False, allow_blank=True)
    lesson_learned = serializers.CharField(required=False, allow_blank=True)
    mood = serializers.ChoiceField(
        choices=['confident', 'neutral', 'anxious', 'fomo', 'disciplined', ''],
        required=False, allow_blank=True,
    )
    rating = serializers.IntegerField(required=False, allow_null=True, min_value=1, max_value=5)


class UpdateRiskLimitSerializer(CamelCaseSerializer):
    max_daily_loss = serializers.DecimalField(
        max_digits=14, decimal_places=2, required=False, allow_null=True
    )
    max_position_size_percent = serializers.DecimalField(
        max_digits=5, decimal_places=2, required=False
    )
    is_active = serializers.BooleanField(required=False)
