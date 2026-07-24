"""Views for paper F&O/commodity-option trading and paper commodity trading
— the options/commodities counterpart to `paper_trading_views.py`. Fully
separate from `option_trading_service.py`/`commodity_trading_service.py`
(real wallet) — these only ever touch `PaperWallet`.
"""

from rest_framework.response import Response
from rest_framework.views import APIView

from core.utils import camelize
from kyc.permissions import MARKET_TRADE_PERMISSIONS

from .paper_commodity_service import (
    PaperCommodityTradingError,
    exit_paper_commodity_position,
    list_paper_commodity_holdings,
    list_paper_commodity_orders,
    place_paper_commodity_order,
)
from .paper_option_commodity_serializers import (
    ExitCommodityPositionSerializer,
    ExitOptionPositionSerializer,
    PlaceCommodityOrderSerializer,
    PlaceOptionOrderSerializer,
)
from .paper_option_service import (
    PaperOptionTradingError,
    exit_paper_option_position,
    list_paper_option_holdings,
    list_paper_option_orders,
    place_paper_option_order,
)
from .paper_portfolio_service import get_unified_paper_portfolio


class PaperPortfolioView(APIView):
    """GET /paper-trading/portfolio/ — unified live view across equity,
    option, and commodity paper positions, sharing one PaperWallet."""

    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request):
        return Response(camelize(get_unified_paper_portfolio(request.user)))


class PaperOptionOrderView(APIView):
    """POST place a paper option order, GET the recent order book."""

    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request):
        return Response(list_paper_option_orders(request.user))

    def post(self, request):
        serializer = PlaceOptionOrderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            payload = place_paper_option_order(
                request.user,
                underlying=data['underlying'],
                strike=data['strike'],
                option_type=data['option_type'],
                expiry=data['expiry'],
                side=data['side'],
                quantity=data['quantity'],
                premium=data['premium'],
                asset_class=data.get('asset_class', 'equity_fno'),
            )
        except PaperOptionTradingError as exc:
            return Response({'detail': str(exc)}, status=400)
        payload['success'] = True
        return Response(payload, status=201)


class PaperOptionHoldingsView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request):
        asset_class = request.query_params.get('asset_class')
        return Response(list_paper_option_holdings(request.user, asset_class=asset_class))


class PaperOptionExitView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def post(self, request):
        serializer = ExitOptionPositionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            payload = exit_paper_option_position(
                request.user,
                underlying=data['underlying'],
                strike=data['strike'],
                option_type=data['option_type'],
                expiry=data['expiry'],
                premium=data['premium'],
                asset_class=data.get('asset_class', 'equity_fno'),
            )
        except PaperOptionTradingError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(payload)


class PaperCommodityOrderView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request):
        return Response(list_paper_commodity_orders(request.user))

    def post(self, request):
        serializer = PlaceCommodityOrderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            payload = place_paper_commodity_order(
                request.user,
                commodity_id=data['commodity_id'],
                side=data['side'],
                quantity=data['quantity'],
            )
        except PaperCommodityTradingError as exc:
            return Response({'detail': str(exc)}, status=400)
        payload['success'] = True
        return Response(payload, status=201)


class PaperCommodityHoldingsView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request):
        return Response(list_paper_commodity_holdings(request.user))


class PaperCommodityExitView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def post(self, request):
        serializer = ExitCommodityPositionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            payload = exit_paper_commodity_position(
                request.user, commodity_id=serializer.validated_data['commodity_id'],
            )
        except PaperCommodityTradingError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(payload)
