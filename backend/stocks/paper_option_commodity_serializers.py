"""Request serializers for paper options and paper commodities — same
request-only, snake_case-input convention as `paper_trading_serializers.py`.
"""

from rest_framework import serializers

from core.serializers import CamelCaseSerializer
from .models import PaperOptionHolding


class PlaceOptionOrderSerializer(CamelCaseSerializer):
    underlying = serializers.CharField()
    strike = serializers.DecimalField(max_digits=12, decimal_places=4)
    option_type = serializers.ChoiceField(choices=['CE', 'PE'])
    expiry = serializers.DateField()
    side = serializers.ChoiceField(choices=['BUY', 'SELL'])
    quantity = serializers.IntegerField(min_value=1)
    premium = serializers.DecimalField(max_digits=12, decimal_places=4)
    asset_class = serializers.ChoiceField(
        choices=PaperOptionHolding.AssetClass.values, required=False,
        default=PaperOptionHolding.AssetClass.EQUITY_FNO,
    )


class ExitOptionPositionSerializer(CamelCaseSerializer):
    underlying = serializers.CharField()
    strike = serializers.DecimalField(max_digits=12, decimal_places=4)
    option_type = serializers.ChoiceField(choices=['CE', 'PE'])
    expiry = serializers.DateField()
    premium = serializers.DecimalField(max_digits=12, decimal_places=4)
    asset_class = serializers.ChoiceField(
        choices=PaperOptionHolding.AssetClass.values, required=False,
        default=PaperOptionHolding.AssetClass.EQUITY_FNO,
    )


class PlaceCommodityOrderSerializer(CamelCaseSerializer):
    commodity_id = serializers.CharField()
    side = serializers.ChoiceField(choices=['BUY', 'SELL'])
    quantity = serializers.IntegerField(min_value=1)


class ExitCommodityPositionSerializer(CamelCaseSerializer):
    commodity_id = serializers.CharField()
