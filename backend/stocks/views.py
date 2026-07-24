from datetime import date, timedelta
from decimal import Decimal
import logging

from django.db.models import Q
from django.utils import timezone
from django.http import HttpResponse
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.utils import camelize
from engagement.serializers import MarketIndexSerializer

from .quote_provider import FinnhubError, INDEX_SYMBOLS, provider_label
from .kotak_neo_client import KotakNeoError
from .market_data_service import (
    get_live_candles,
    get_market_snapshot,
    refresh_all_indices,
    refresh_nifty50,
    refresh_stock,
    refresh_stocks,
)
from .models import (
    DividendRecord,
    NewsAlert,
    PaperTrade,
    PriceAlert,
    SipPlan,
    Stock,
    StockHolding,
    TraderNote,
    WatchlistItem,
)
from kyc.permissions import IsFnoVerified, IsKycVerified, MARKET_BROWSE_PERMISSIONS, MARKET_TRADE_PERMISSIONS

from .commodity_trading_service import (
    CommodityTradingError,
    list_commodity_holdings,
    list_recent_commodity_trades,
    place_commodity_order,
)
from .option_trading_service import (
    OptionTradingError,
    list_option_holdings,
    list_recent_option_trades,
    place_option_order,
)
from .trading_service import (
    TradingError,
    get_or_create_paper_wallet,
    list_recent_trades,
    place_paper_order,
    reset_paper_portfolio,
)
from .portfolio_service import get_stock_portfolio
from .portfolio_health_service import get_portfolio_health
from .rebalance_service import analyze_portfolio_rebalance
from .screener_service import get_screener_results, get_screener_sectors
from .dividend_service import sync_user_dividends
from .news_service import fetch_market_news
from .news_image_service import fetch_news_image
from .tradingview_service import (
    resolve_commodity_symbol,
    resolve_interval,
    resolve_stock_symbol,
    tradingview_config,
)
from .options_service import get_commodity_option_chain, get_option_chain
from .serializers import (
    CreateAlertSerializer,
    CreateNewsAlertSerializer,
    CreateSipSerializer,
    CommodityOrderSerializer,
    NewsAlertSerializer,
    OptionOrderSerializer,
    PaperOrderSerializer,
    PriceAlertSerializer,
    SipPlanSerializer,
    StockCandleSerializer,
    StockHoldingSerializer,
    StockNewsSerializer,
    StockSerializer,
    ScreenerStockSerializer,
    OptionContractSerializer,
    CreateTraderNoteSerializer,
    TraderNoteSerializer,
    UpdateTraderNoteSerializer,
    DividendSerializer,
    PaperTradeSerializer,
)

logger = logging.getLogger('bullwave.market')


class MarketLiveView(APIView):
    """Live Nifty 50 + indices (Kotak Neo / Finnhub / Yahoo)."""
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        fast = request.query_params.get('fast', '1') != '0'
        force = request.query_params.get('refresh', '0') == '1'
        try:
            snapshot = get_market_snapshot(fast=fast, force_refresh=force)
        except (FinnhubError, KotakNeoError) as exc:
            from .market_symbols import NIFTY_50

            db_stocks = list(Stock.objects.filter(symbol__in=NIFTY_50).order_by('-market_cap_cr'))
            if db_stocks:
                from engagement.models import MarketIndex
                from .quote_provider import INDEX_SYMBOLS

                snapshot = {
                    'stocks': db_stocks,
                    'indices': list(MarketIndex.objects.filter(id__in=INDEX_SYMBOLS.keys())),
                    'updated_at': timezone.now().isoformat(),
                    'provider': f'{provider_label()} (cached)',
                }
            else:
                return Response({'detail': str(exc)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        return Response(
            {
                'stocks': StockSerializer(snapshot['stocks'], many=True).data,
                'indices': MarketIndexSerializer(snapshot['indices'], many=True).data,
                'updatedAt': snapshot['updated_at'],
                'provider': snapshot['provider'],
            }
        )


class StockSearchView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        query = request.query_params.get('q', '').strip()
        live = request.query_params.get('live', '1') != '0'

        try:
            if not query:
                qs = refresh_nifty50() if live else Stock.objects.filter(exchange='NSE').order_by('-market_cap_cr')[:50]
            else:
                qs = Stock.objects.filter(
                    Q(symbol__icontains=query) | Q(name__icontains=query),
                    exchange='NSE',
                )[:30]
                if live and qs.exists():
                    refresh_stocks([s.symbol for s in qs])
                    qs = Stock.objects.filter(pk__in=[s.pk for s in qs])
        except FinnhubError as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        if query:
            return Response(StockSerializer(qs, many=True).data)
        return Response(StockSerializer(list(qs[:50]), many=True).data)


class StockQuoteView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request, symbol):
        try:
            stock = refresh_stock(symbol.upper(), include_fundamentals=True)
        except FinnhubError as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        except Stock.DoesNotExist:
            return Response({'detail': 'Stock not found.'}, status=404)

        return Response(
            {
                **StockSerializer(stock).data,
                'updatedAt': timezone.now().isoformat(),
            }
        )


class StockCandlesView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request, symbol):
        interval = request.query_params.get('interval', '1d')
        fast = request.query_params.get('fast', '').lower() in ('1', 'true', 'yes')
        try:
            candles = get_live_candles(symbol.upper(), interval=interval, fast=fast)
        except FinnhubError as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        except Stock.DoesNotExist:
            return Response({'detail': 'Stock not found.'}, status=404)

        return Response(StockCandleSerializer(candles, many=True).data)


def _stock_or_fallback(symbol: str) -> Stock:
    """Resolve stock for watchlist — live quote preferred, DB fallback if APIs are down."""
    symbol = symbol.upper().strip()
    existing = Stock.objects.filter(symbol=symbol).first()
    try:
        return refresh_stock(symbol)
    except Exception as exc:
        logger.warning('Watchlist stock refresh failed for %s: %s', symbol, exc)
        if existing:
            return existing
        return Stock.objects.create(
            symbol=symbol,
            name=symbol,
            exchange='NSE',
            sector='General',
            ltp=Decimal('100'),
            change=Decimal('0'),
            change_percent=Decimal('0'),
            open_price=Decimal('100'),
            high=Decimal('100'),
            low=Decimal('100'),
            previous_close=Decimal('100'),
            volume=0,
        )


class WatchlistView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        items = list(
            WatchlistItem.objects.filter(user=request.user).select_related('stock')
        )
        symbols = [i.stock.symbol for i in items]
        if symbols:
            try:
                refresh_stocks(symbols)
                items = list(
                    WatchlistItem.objects.filter(user=request.user).select_related('stock')
                )
            except Exception as exc:
                logger.warning('Watchlist batch refresh failed: %s', exc)
        return Response(StockSerializer([i.stock for i in items], many=True).data)


class WatchlistSymbolView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def post(self, request, symbol):
        stock = _stock_or_fallback(symbol)
        WatchlistItem.objects.get_or_create(user=request.user, stock=stock)
        return Response(StockSerializer(stock).data, status=201)

    def delete(self, request, symbol):
        deleted, _ = WatchlistItem.objects.filter(
            user=request.user, stock__symbol__iexact=symbol
        ).delete()
        if not deleted:
            return Response({'detail': 'Symbol not in watchlist.'}, status=404)
        return Response(status=204)


class PortfolioOverviewView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        refresh = request.query_params.get('refresh', '0').strip() in ('1', 'true', 'yes')
        return Response(camelize(get_stock_portfolio(request.user, refresh=refresh)))


class PortfolioHoldingsView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        data = get_stock_portfolio(request.user)
        return Response(camelize(data['holdings']))


class PortfolioAnalyticsView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        data = get_stock_portfolio(request.user)
        summary = data['summary']
        return Response(
            camelize(
                {
                    'total_invested': summary['total_invested'],
                    'current_value': summary['current_value'],
                    'pnl': summary['total_pnl'],
                    'pnl_percent': summary['total_pnl_percent'],
                    'day_pnl': summary['day_pnl'],
                    'day_pnl_percent': summary['day_pnl_percent'],
                    'sector_breakdown': {
                        item['label']: item['value'] for item in data['sector_allocation']
                    },
                    'sector_allocation': data['sector_allocation'],
                    'holdings_count': summary['holdings_count'],
                    'holdings': data['holdings'],
                }
            )
        )


class PortfolioRebalanceView(APIView):
    """AI portfolio rebalancing — drift analysis and automation status."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        result = analyze_portfolio_rebalance(request.user, create_notification=False)
        return Response(camelize(result))


class PortfolioRebalanceCheckView(APIView):
    """Run AI rebalance scan and create notification when drift exceeds threshold."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        result = analyze_portfolio_rebalance(request.user, create_notification=True)
        return Response(camelize(result))


class PortfolioHealthView(APIView):
    """Portfolio health score — diversification, concentration, performance."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(camelize(get_portfolio_health(request.user)))


class StockNewsView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        symbol = request.query_params.get('symbol')
        limit = min(int(request.query_params.get('limit', 20)), 50)
        news = fetch_market_news(limit=limit, symbol=symbol)
        return Response(StockNewsSerializer(news, many=True).data)


class NewsImageProxyView(APIView):
    """Serve remote news thumbnails through Django (fixes Flutter web CORS/hotlink)."""
    permission_classes = [AllowAny]

    def get(self, request):
        url = (request.query_params.get('url') or '').strip()
        if not url:
            return HttpResponse(status=400)

        payload = fetch_news_image(url)
        if not payload:
            return HttpResponse(status=404)

        data, content_type = payload
        response = HttpResponse(data, content_type=content_type)
        response['Cache-Control'] = 'public, max-age=3600'
        return response


class PriceAlertsView(APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [permission() for permission in MARKET_TRADE_PERMISSIONS]

    def get(self, request):
        alerts = PriceAlert.objects.filter(user=request.user).select_related('stock')
        return Response(PriceAlertSerializer(alerts, many=True).data)

    def post(self, request):
        serializer = CreateAlertSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        symbol = serializer.validated_data['symbol'].upper()
        stock = Stock.objects.filter(symbol=symbol).first()
        if not stock:
            try:
                stock = refresh_stock(symbol)
            except FinnhubError as exc:
                return Response({'detail': str(exc)}, status=503)
        alert = PriceAlert.objects.create(
            user=request.user,
            stock=stock,
            target_price=serializer.validated_data['target_price'],
            condition=serializer.validated_data['condition'],
        )
        return Response(PriceAlertSerializer(alert).data, status=201)


class PriceAlertDetailView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def patch(self, request, alert_id):
        try:
            alert = PriceAlert.objects.get(user=request.user, pk=alert_id)
        except PriceAlert.DoesNotExist:
            return Response({'detail': 'Alert not found.'}, status=404)
        if 'is_active' in request.data:
            alert.is_active = bool(request.data['is_active'])
            alert.save(update_fields=['is_active'])
        elif 'isActive' in request.data:
            alert.is_active = bool(request.data['isActive'])
            alert.save(update_fields=['is_active'])
        return Response(PriceAlertSerializer(alert).data)

    def delete(self, request, alert_id):
        deleted, _ = PriceAlert.objects.filter(user=request.user, pk=alert_id).delete()
        if not deleted:
            return Response({'detail': 'Alert not found.'}, status=404)
        return Response(status=204)


class NewsAlertsView(APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [permission() for permission in MARKET_TRADE_PERMISSIONS]

    def get(self, request):
        alerts = NewsAlert.objects.filter(user=request.user)
        return Response(NewsAlertSerializer(alerts, many=True).data)

    def post(self, request):
        serializer = CreateNewsAlertSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        keyword = serializer.validated_data['keyword'].strip().upper()
        if not keyword:
            return Response({'detail': 'Keyword required.'}, status=400)
        alert, created = NewsAlert.objects.get_or_create(
            user=request.user,
            keyword=keyword,
            defaults={'is_active': True},
        )
        if not created:
            alert.is_active = True
            alert.save(update_fields=['is_active'])
        return Response(NewsAlertSerializer(alert).data, status=201 if created else 200)


class NewsAlertDetailView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def patch(self, request, alert_id):
        try:
            alert = NewsAlert.objects.get(user=request.user, pk=alert_id)
        except NewsAlert.DoesNotExist:
            return Response({'detail': 'Not found.'}, status=404)
        if 'is_active' in request.data:
            alert.is_active = bool(request.data['is_active'])
            alert.save(update_fields=['is_active'])
        elif 'isActive' in request.data:
            alert.is_active = bool(request.data['isActive'])
            alert.save(update_fields=['is_active'])
        return Response(NewsAlertSerializer(alert).data)

    def delete(self, request, alert_id):
        deleted, _ = NewsAlert.objects.filter(user=request.user, pk=alert_id).delete()
        if not deleted:
            return Response({'detail': 'Not found.'}, status=404)
        return Response(status=204)


class SipPlansView(APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [permission() for permission in MARKET_TRADE_PERMISSIONS]

    def get(self, request):
        plans = SipPlan.objects.filter(user=request.user, is_active=True).select_related('stock')
        return Response(SipPlanSerializer(plans, many=True).data)

    def post(self, request):
        serializer = CreateSipSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        symbol = serializer.validated_data['symbol'].upper()
        stock = Stock.objects.filter(symbol=symbol).first()
        if not stock:
            try:
                stock = refresh_stock(symbol)
            except FinnhubError as exc:
                return Response({'detail': str(exc)}, status=503)
        plan = SipPlan.objects.create(
            user=request.user,
            stock=stock,
            monthly_amount=serializer.validated_data['monthly_amount'],
            total_installments=serializer.validated_data.get('total_installments', 12),
            next_date=date.today() + timedelta(days=30),
        )
        return Response(SipPlanSerializer(plan).data, status=201)


class SipPlanDetailView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def delete(self, request, plan_id):
        updated = SipPlan.objects.filter(user=request.user, pk=plan_id, is_active=True).update(
            is_active=False
        )
        if not updated:
            return Response({'detail': 'SIP plan not found.'}, status=404)
        return Response(status=204)


class OptionChainView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request, symbol):
        expiry = request.query_params.get('expiry')
        fast = request.query_params.get('fast', '').lower() in ('1', 'true', 'yes')
        try:
            chain = get_option_chain(symbol, expiry=expiry, fast=fast)
        except Exception as exc:
            logger.exception('Option chain failed for %s: %s', symbol, exc)
            return Response(
                {'detail': 'Unable to build option chain. Please try again.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        if not chain:
            return Response({'detail': 'Unable to load option chain for this symbol.'}, status=404)
        if not fast and not chain.get('contracts'):
            return Response({'detail': 'No F&O contracts available for this symbol.'}, status=404)

        contracts = OptionContractSerializer(chain['contracts'], many=True).data
        return Response(
            {
                'symbol': chain['symbol'],
                'underlyingValue': chain['underlying_value'],
                'expiryDates': chain['expiry_dates'],
                'selectedExpiry': chain['selected_expiry'],
                'updatedAt': chain['updated_at'],
                'provider': chain['source'],
                'contracts': contracts,
            }
        )


class PaperTradingOrdersView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request):
        return Response(list_recent_trades(request.user, limit=50))

    def post(self, request):
        serializer = PaperOrderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            payload = place_paper_order(
                request.user,
                symbol=data['symbol'],
                side=data['side'],
                quantity=data['quantity'],
            )
        except TradingError as exc:
            return Response({'detail': str(exc)}, status=400)
        payload['success'] = True
        payload['message'] = (
            'Sell order executed successfully.'
            if data['side'].upper() == 'SELL'
            else 'Buy order executed successfully.'
        )
        return Response(payload, status=201)


class PaperWalletView(APIView):
    """Virtual practice-capital balance for equity paper trading.

    Fully isolated from the real money `finance.Wallet` — resetting or
    trading here never touches funds the user actually deposited.
    """

    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request):
        wallet = get_or_create_paper_wallet(request.user)
        return Response(camelize({
            'virtualBalance': float(wallet.balance),
            'virtualStartingBalance': float(wallet.starting_balance),
        }))

    def post(self, request):
        """Reset the learner's paper portfolio: clears positions/orders and
        restores starting virtual capital so they can start a fresh run."""
        result = reset_paper_portfolio(request.user)
        return Response(camelize({**result, 'message': 'Paper portfolio reset.'}))


class ScreenerView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        sector = request.query_params.get('sector')
        min_pe = request.query_params.get('min_pe')
        max_pe = request.query_params.get('max_pe')
        min_roe = request.query_params.get('min_roe')
        max_de = request.query_params.get('max_de')
        sort = request.query_params.get('sort', 'market_cap')
        limit = min(int(request.query_params.get('limit', 50)), 100)

        def _float(val):
            if val in (None, ''):
                return None
            return float(val)

        try:
            stocks = get_screener_results(
                sector=sector,
                min_pe=_float(min_pe),
                max_pe=_float(max_pe),
                min_roe=_float(min_roe),
                max_de=_float(max_de),
                sort=sort,
                limit=limit,
            )
        except FinnhubError as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        return Response(
            {
                'sectors': get_screener_sectors(),
                'sort': sort,
                'updatedAt': timezone.now().isoformat(),
                'provider': provider_label(),
                'results': ScreenerStockSerializer(stocks, many=True).data,
            }
        )


class DividendsView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        sync = request.query_params.get('sync', 'true').lower() != 'false'
        if sync:
            try:
                sync_user_dividends(request.user)
            except Exception:
                pass
        records = DividendRecord.objects.filter(user=request.user).select_related('stock')
        return Response(DividendSerializer(records, many=True).data)


class CommodityListView(APIView):
    """Live global commodity prices — gold, silver, crude oil, etc."""

    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        from .commodity_service import get_commodity_snapshot

        return Response(camelize(get_commodity_snapshot()))


class CommodityDetailView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request, commodity_id):
        from .commodity_service import get_commodity_detail

        row = get_commodity_detail(commodity_id)
        if not row:
            return Response({'detail': 'Commodity not found.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(camelize(row))


class CommodityHoldingsView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        return Response(camelize({'holdings': list_commodity_holdings(request.user)}))


class CommodityOrdersView(APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [permission() for permission in MARKET_TRADE_PERMISSIONS]

    def get(self, request):
        return Response(camelize({'trades': list_recent_commodity_trades(request.user)}))

    def post(self, request):
        serializer = CommodityOrderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            payload = place_commodity_order(
                request.user,
                commodity_id=data['commodity_id'],
                side=data['side'],
                quantity=data['quantity'],
            )
        except CommodityTradingError as exc:
            return Response({'detail': str(exc)}, status=400)
        payload['success'] = True
        payload['message'] = (
            'Sell order executed successfully.'
            if data['side'].upper() == 'SELL'
            else 'Buy order executed successfully.'
        )
        return Response(camelize(payload), status=201)


class CommodityOptionChainView(APIView):
    """Commodity F&O chain — gold, silver, crude oil, etc."""

    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request, commodity_id):
        expiry = request.query_params.get('expiry')
        fast = request.query_params.get('fast', '').lower() in ('1', 'true', 'yes')
        try:
            chain = get_commodity_option_chain(commodity_id, expiry=expiry, fast=fast)
        except Exception as exc:
            logger.exception('Commodity option chain failed for %s: %s', commodity_id, exc)
            return Response(
                {'detail': 'Unable to build commodity option chain.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
        if not chain or not chain.get('contracts'):
            return Response({'detail': 'No option contracts for this commodity.'}, status=404)

        contracts = OptionContractSerializer(chain['contracts'], many=True).data
        return Response(
            camelize(
                {
                    'symbol': chain['symbol'],
                    'name': chain.get('name', ''),
                    'unit': chain.get('unit', ''),
                    'currency': chain.get('currency', 'USD'),
                    'underlying_value': chain['underlying_value'],
                    'expiry_dates': chain['expiry_dates'],
                    'selected_expiry': chain['selected_expiry'],
                    'contracts': contracts,
                    'updated_at': chain.get('updated_at', ''),
                    'source': chain.get('source', ''),
                    'asset_class': 'commodity',
                }
            )
        )


class OptionHoldingsView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        asset_class = request.query_params.get('asset_class')
        return Response(
            camelize({'holdings': list_option_holdings(request.user, asset_class=asset_class)})
        )


class OptionOrdersView(APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [permission() for permission in MARKET_TRADE_PERMISSIONS]

    def get(self, request):
        return Response(camelize({'trades': list_recent_option_trades(request.user)}))

    def post(self, request):
        serializer = OptionOrderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        asset_class = (data.get('asset_class') or 'equity_fno').lower()
        if asset_class == 'equity_fno' and not IsFnoVerified().has_permission(request, self):
            return Response(
                {'detail': 'F&O verification required to trade stock/index options.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        try:
            payload = place_option_order(
                request.user,
                underlying=data['underlying'],
                strike=data['strike'],
                option_type=data['option_type'],
                expiry=data['expiry'],
                side=data['side'],
                quantity=data['quantity'],
                premium=data['premium'],
                asset_class=asset_class,
            )
        except OptionTradingError as exc:
            return Response({'detail': str(exc)}, status=400)
        payload['success'] = True
        payload['message'] = (
            'Sell order executed successfully.'
            if data['side'].upper() == 'SELL'
            else 'Buy order executed successfully.'
        )
        return Response(camelize(payload), status=201)


class IpoCalendarView(APIView):
    """Upcoming, open, and recently listed IPOs."""
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        from .ipo_service import list_ipo_calendar

        status_filter = request.query_params.get('status')
        limit_raw = request.query_params.get('limit')
        limit = int(limit_raw) if limit_raw and limit_raw.isdigit() else None
        rows = list_ipo_calendar(status=status_filter, limit=limit)
        return Response(camelize({'events': rows, 'count': len(rows)}))


class IpoHoldingsView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        from .ipo_trading_service import list_ipo_holdings

        return Response(camelize({'holdings': list_ipo_holdings(request.user)}))


class IpoOrdersView(APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [permission() for permission in MARKET_TRADE_PERMISSIONS]

    def get(self, request):
        from .ipo_trading_service import list_ipo_trades

        return Response(camelize({'trades': list_ipo_trades(request.user)}))

    def post(self, request):
        from .ipo_trading_service import IpoTradingError, place_ipo_order

        ipo_id = request.data.get('ipo_id') or request.data.get('ipoId')
        raw_side = request.data.get('side', 'APPLY')
        lots = int(request.data.get('lots', 1))
        try:
            payload = place_ipo_order(request.user, ipo_id=ipo_id, side=raw_side, lots=lots)
        except IpoTradingError as exc:
            return Response({'detail': str(exc)}, status=400)
        payload['success'] = True
        payload['message'] = (
            'IPO sold successfully.'
            if str(raw_side).upper() == 'SELL'
            else 'IPO application submitted successfully.'
        )
        return Response(camelize(payload), status=201)


class TradingViewConfigView(APIView):
    """Client config for TradingView widget / charting library integration."""
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        return Response(camelize(tradingview_config()))


class TradingViewSymbolView(APIView):
    """Resolve app symbol → TradingView EXCHANGE:SYMBOL."""
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request, symbol):
        exchange = request.query_params.get('exchange', 'NSE')
        commodity = request.query_params.get('commodity', '0') == '1'
        interval = request.query_params.get('interval', '1d')
        tv_symbol = (
            resolve_commodity_symbol(symbol)
            if commodity
            else resolve_stock_symbol(symbol, exchange=exchange)
        )
        return Response(
            camelize(
                {
                    'symbol': symbol,
                    'tradingViewSymbol': tv_symbol,
                    'interval': resolve_interval(interval),
                }
            )
        )


class TradingViewUdfConfigView(APIView):
    """UDF /datafeed config — wire to your TradingView datafeed when licensed."""

    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        return Response(
            {
                'supported_resolutions': ['1', '5', '15', '30', '60', 'D', 'W', 'M'],
                'supports_group_request': False,
                'supports_marks': False,
                'supports_search': True,
                'supports_timescale_marks': False,
                'supports_time': True,
            }
        )


class TradingViewUdfTimeView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        return Response(int(timezone.now().timestamp()))


class TradingViewUdfSymbolsView(APIView):
    """Stub — implement symbol metadata for Charting Library UDF."""

    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        symbol = request.query_params.get('symbol', '')
        if not symbol:
            return Response({'s': 'error', 'errmsg': 'symbol required'}, status=400)
        return Response(
            {
                'name': symbol,
                'ticker': symbol,
                'description': symbol,
                'type': 'stock',
                'session': '0915-1530',
                'timezone': 'Asia/Kolkata',
                'exchange': symbol.split(':')[0] if ':' in symbol else 'NSE',
                'minmov': 1,
                'pricescale': 100,
                'has_intraday': True,
                'supported_resolutions': ['1', '5', '15', '30', '60', 'D', 'W', 'M'],
                'volume_precision': 0,
                'data_status': 'streaming',
            }
        )


class TradingViewUdfHistoryView(APIView):
    """Stub — implement OHLC history for Charting Library UDF."""

    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        return Response(
            {
                's': 'no_data',
                'nextTime': None,
                'detail': 'Wire TradingView UDF history to your market data provider.',
            }
        )


class TraderNotesView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = TraderNote.objects.filter(user=request.user)
        category = (request.query_params.get('category') or '').strip().lower()
        if category:
            qs = qs.filter(category=category)
        if request.query_params.get('pinned', '').lower() in ('1', 'true', 'yes'):
            qs = qs.filter(is_pinned=True)
        search = (request.query_params.get('search') or '').strip()
        if search:
            qs = qs.filter(
                Q(title__icontains=search)
                | Q(body__icontains=search)
                | Q(symbol__icontains=search)
            )
        return Response(TraderNoteSerializer(qs, many=True).data)

    def post(self, request):
        serializer = CreateTraderNoteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        symbol = (data.get('symbol') or '').strip().upper()
        note = TraderNote.objects.create(
            user=request.user,
            title=data['title'].strip(),
            body=(data.get('body') or '').strip(),
            symbol=symbol,
            category=data.get('category') or TraderNote.Category.GENERAL,
            is_pinned=bool(data.get('is_pinned', False)),
        )
        return Response(TraderNoteSerializer(note).data, status=status.HTTP_201_CREATED)


class TraderNoteDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def _get_note(self, request, note_id):
        try:
            return TraderNote.objects.get(user=request.user, pk=note_id)
        except TraderNote.DoesNotExist:
            return None

    def get(self, request, note_id):
        note = self._get_note(request, note_id)
        if not note:
            return Response({'detail': 'Note not found.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(TraderNoteSerializer(note).data)

    def patch(self, request, note_id):
        note = self._get_note(request, note_id)
        if not note:
            return Response({'detail': 'Note not found.'}, status=status.HTTP_404_NOT_FOUND)
        serializer = UpdateTraderNoteSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        if 'title' in data:
            note.title = data['title'].strip()
        if 'body' in data:
            note.body = data['body'].strip()
        if 'symbol' in data:
            note.symbol = (data['symbol'] or '').strip().upper()
        if 'category' in data:
            note.category = data['category']
        if 'is_pinned' in data:
            note.is_pinned = bool(data['is_pinned'])
        note.save()
        return Response(TraderNoteSerializer(note).data)

    def delete(self, request, note_id):
        deleted, _ = TraderNote.objects.filter(user=request.user, pk=note_id).delete()
        if not deleted:
            return Response({'detail': 'Note not found.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(status=status.HTTP_204_NO_CONTENT)


class CopyTradersView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        from .copy_trading_service import list_traders

        traders = list_traders(
            request.user,
            risk=request.query_params.get('risk'),
            q=request.query_params.get('q'),
        )
        return Response(camelize({'traders': traders, 'count': len(traders)}))


class CopyTraderDetailView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request, trader_id):
        from .copy_trading_service import CopyTradingError, get_trader

        try:
            payload = get_trader(trader_id, request.user)
        except CopyTradingError as exc:
            return Response({'detail': str(exc)}, status=404)
        return Response(camelize(payload))


class CopyTraderTradesView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request, trader_id):
        from .copy_trading_service import CopyTradingError, list_trader_trades

        try:
            trades = list_trader_trades(trader_id)
        except CopyTradingError as exc:
            return Response({'detail': str(exc)}, status=404)
        return Response(camelize({'trades': trades, 'count': len(trades)}))


class CopySubscriptionsView(APIView):
    def get_permissions(self):
        if self.request.method == 'GET':
            return [IsAuthenticated()]
        return [permission() for permission in MARKET_TRADE_PERMISSIONS]

    def get(self, request):
        from .copy_trading_service import list_subscriptions

        subs = list_subscriptions(request.user)
        return Response(camelize({'subscriptions': subs, 'count': len(subs)}))

    def post(self, request):
        from .copy_trading_service import CopyTradingError, start_copy
        from .serializers import StartCopySerializer

        serializer = StartCopySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            payload = start_copy(
                request.user,
                trader_id=data['trader_id'],
                allocation_inr=data['allocation_inr'],
                copy_ratio=data.get('copy_ratio', 1),
                auto_copy=data.get('auto_copy', True),
            )
        except CopyTradingError as exc:
            return Response({'detail': str(exc)}, status=400)
        payload['success'] = True
        payload['message'] = 'Now copying this trader’s method.'
        return Response(camelize(payload), status=201)


class CopySubscriptionDetailView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def patch(self, request, subscription_id):
        from .copy_trading_service import CopyTradingError, update_subscription
        from .serializers import UpdateCopySubscriptionSerializer

        serializer = UpdateCopySubscriptionSerializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            payload = update_subscription(
                request.user,
                subscription_id,
                status=data.get('status'),
                allocation_inr=data.get('allocation_inr'),
                auto_copy=data.get('auto_copy'),
            )
        except CopyTradingError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(camelize(payload))

    def delete(self, request, subscription_id):
        from .copy_trading_service import CopyTradingError, update_subscription

        try:
            update_subscription(request.user, subscription_id, status='stopped')
        except CopyTradingError as exc:
            return Response({'detail': str(exc)}, status=404)
        return Response(status=204)


class PaperRiskMeterView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request):
        from .paper_risk_service import get_paper_risk_meter

        return Response(camelize(get_paper_risk_meter(request.user)))


class MarketRiskMeterView(APIView):
    """Live portfolio risk meter for real Markets trading."""

    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        from .paper_risk_service import get_market_risk_meter

        return Response(camelize(get_market_risk_meter(request.user)))


class PaperCompetitionsView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request):
        from .paper_competition_service import list_competitions

        comps = list_competitions(request.user)
        return Response(camelize({'competitions': comps, 'count': len(comps)}))

    def post(self, request):
        from .paper_competition_service import CompetitionError, create_competition, join_competition
        from .serializers import CreatePaperCompetitionSerializer, JoinPaperCompetitionSerializer

        action = (request.data.get('action') or 'create').lower()
        if action == 'join':
            serializer = JoinPaperCompetitionSerializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            try:
                payload = join_competition(
                    request.user, invite_code=serializer.validated_data['invite_code']
                )
            except CompetitionError as exc:
                return Response({'detail': str(exc)}, status=400)
            payload['success'] = True
            payload['message'] = 'Joined competition.'
            return Response(camelize(payload), status=200)

        serializer = CreatePaperCompetitionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            payload = create_competition(
                request.user,
                name=data.get('name') or '',
                starting_balance=data.get('starting_balance', 100000),
                duration_days=data.get('duration_days', 7),
            )
        except CompetitionError as exc:
            return Response({'detail': str(exc)}, status=400)
        payload['success'] = True
        payload['message'] = 'Competition created. Share the invite code with friends.'
        return Response(camelize(payload), status=201)


class PaperCompetitionDetailView(APIView):
    permission_classes = MARKET_TRADE_PERMISSIONS

    def get(self, request, competition_id):
        from .paper_competition_service import CompetitionError, get_competition

        try:
            payload = get_competition(competition_id, request.user)
        except CompetitionError as exc:
            return Response({'detail': str(exc)}, status=404)
        return Response(camelize(payload))


class BlockDealsView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        from .institutional_flow_service import list_block_deals

        limit_raw = request.query_params.get('limit', '50')
        try:
            limit = min(max(int(limit_raw), 1), 100)
        except (TypeError, ValueError):
            limit = 50
        payload = list_block_deals(
            deal_type=request.query_params.get('deal_type') or request.query_params.get('dealType'),
            side=request.query_params.get('side'),
            q=request.query_params.get('q'),
            limit=limit,
        )
        return Response(camelize(payload))


class DarkPoolPrintsView(APIView):
    permission_classes = MARKET_BROWSE_PERMISSIONS

    def get(self, request):
        from .institutional_flow_service import list_dark_pool_prints

        limit_raw = request.query_params.get('limit', '50')
        try:
            limit = min(max(int(limit_raw), 1), 100)
        except (TypeError, ValueError):
            limit = 50
        payload = list_dark_pool_prints(
            bias=request.query_params.get('bias'),
            q=request.query_params.get('q'),
            limit=limit,
        )
        return Response(camelize(payload))
