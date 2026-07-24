"""Views for the paper-trading module: order book (market/limit/SL-M/SL),
position exits, funds ledger, journal, analytics, and risk limits.

Additive only — the legacy `PaperTradingOrdersView`/`PaperWalletView` in
`views.py` (market-order-only) are untouched and keep working exactly as
before for the existing Flutter order pad.
"""

import logging

from rest_framework.response import Response
from rest_framework.views import APIView

from kyc.permissions import MARKET_TRADE_PERMISSIONS

from .paper_analytics_service import compute_performance_analytics
from .paper_journal_service import (
    JournalError,
    create_journal_entry,
    delete_journal_entry,
    list_journal,
    update_journal_entry,
)
from .paper_ledger_service import list_ledger
from .paper_order_service import (
    OrderValidationError,
    cancel_order,
    exit_all_positions,
    exit_position,
    list_order_book,
    modify_order,
    place_order,
)
from .paper_risk_limit_service import check_risk_warnings, update_risk_limit
from .paper_trading_serializers import (
    CreateJournalEntrySerializer,
    ExitPositionSerializer,
    ModifyOrderSerializer,
    PlaceOrderSerializer,
    UpdateJournalEntrySerializer,
    UpdateRiskLimitSerializer,
)
from .trading_service import TradingError

logger = logging.getLogger('bullwave.paper_trading')


class PlaceOrderView(APIView):
    """POST /paper-trading/place-order/ — market/limit/SL-M/SL, unlike the
    legacy market-only /paper-trading/orders/ endpoint."""

    permission_classes = MARKET_TRADE_PERMISSIONS

    def post(self, request):
        serializer = PlaceOrderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            payload = place_order(
                request.user,
                symbol=data['symbol'],
                side=data['side'],
                quantity=data['quantity'],
                order_type=data.get('order_type', 'MARKET'),
                limit_price=data.get('limit_price'),
                trigger_price=data.get('trigger_price'),
            )
        except (OrderValidationError, TradingError) as exc:
            return Response({'detail': str(exc)}, status=400)
        payload['success'] = True
        return Response(payload, status=201)


class OrderBookView(APIView):
    """GET /paper-trading/order-book/ — full order book (pending + recent
    executed/cancelled/rejected). Runs the matching pass first so pending
    limit/stop orders that should have filled show up filled."""

    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request):
        status_filter = request.query_params.get('status')
        orders = list_order_book(request.user, status=status_filter)
        return Response(orders)


class OrderDetailView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def patch(self, request, order_id):
        serializer = ModifyOrderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            payload = modify_order(
                request.user, order_id,
                quantity=data.get('quantity'),
                limit_price=data.get('limit_price'),
                trigger_price=data.get('trigger_price'),
            )
        except OrderValidationError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(payload)

    def delete(self, request, order_id):
        try:
            payload = cancel_order(request.user, order_id)
        except OrderValidationError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(payload)


class ExitPositionView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def post(self, request):
        serializer = ExitPositionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            payload = exit_position(request.user, serializer.validated_data['symbol'])
        except (OrderValidationError, TradingError) as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(payload)


class ExitAllPositionsView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def post(self, request):
        results = exit_all_positions(request.user)
        return Response({'results': results})


class PaperLedgerView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request):
        return Response(list_ledger(request.user))


class PaperJournalView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request):
        return Response(list_journal(request.user))

    def post(self, request):
        serializer = CreateJournalEntrySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            payload = create_journal_entry(
                request.user,
                title=data['title'],
                notes=data.get('notes', ''),
                symbol=data.get('symbol', ''),
                trade_id=data.get('trade_id'),
                lesson_learned=data.get('lesson_learned', ''),
                mood=data.get('mood', ''),
                rating=data.get('rating'),
            )
        except JournalError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(payload, status=201)


class PaperJournalDetailView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def patch(self, request, entry_id):
        serializer = UpdateJournalEntrySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            payload = update_journal_entry(request.user, entry_id, **serializer.validated_data)
        except JournalError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(payload)

    def delete(self, request, entry_id):
        try:
            delete_journal_entry(request.user, entry_id)
        except JournalError as exc:
            return Response({'detail': str(exc)}, status=404)
        return Response(status=204)


class PaperAnalyticsView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request):
        return Response(compute_performance_analytics(request.user))


class PaperRiskLimitView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request):
        return Response(check_risk_warnings(request.user))

    def patch(self, request):
        serializer = UpdateRiskLimitSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        payload = update_risk_limit(request.user, **serializer.validated_data)
        return Response(payload)
