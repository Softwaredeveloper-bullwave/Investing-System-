from django.conf import settings
from decimal import Decimal
import uuid

from django.db import transaction
from django.db.models import Sum
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from engagement.models import MarketIndex, Notification
from engagement.serializers import MarketIndexSerializer
from stocks.news_service import fetch_news_headlines
from .goal_service import get_user_goals
from .models import (
    InvestmentFaq,
    InvestmentPlan,
    Transaction,
    UserInvestment,
    Wallet,
    WalletTransaction,
)
from .serializers import (
    DepositWithdrawSerializer,
    InvestmentFaqSerializer,
    InvestmentPlanSerializer,
    PortfolioSerializer,
    SubscribeSerializer,
    TransactionSerializer,
    UserInvestmentSerializer,
    WalletSerializer,
    WalletTransactionSerializer,
)


class HomeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        portfolio = _build_portfolio(user, refresh_stocks=False)
        wallet, _ = Wallet.objects.get_or_create(user=user)
        portfolio['wallet_balance'] = wallet.balance

        indices = list(MarketIndex.objects.all().order_by('id')[:6])
        recent = user.transactions.all()[:5]

        try:
            news = fetch_news_headlines(limit=8)
        except Exception:
            news = []

        return Response(
            {
                'portfolio': PortfolioSerializer(portfolio).data,
                'featuredPlans': InvestmentPlanSerializer(
                    InvestmentPlan.objects.filter(is_featured=True, is_active=True),
                    many=True,
                ).data,
                'goalPlans': get_user_goals(user)[:5],
                'marketIndices': MarketIndexSerializer(indices, many=True).data,
                'marketNews': news,
                'recentActivity': TransactionSerializer(recent, many=True).data,
            }
        )


class InvestmentPlanListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        plans = InvestmentPlan.objects.filter(is_active=True)
        return Response(InvestmentPlanSerializer(plans, many=True).data)


class InvestmentPlanDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, plan_id):
        try:
            plan = InvestmentPlan.objects.get(pk=plan_id, is_active=True)
        except InvestmentPlan.DoesNotExist:
            return Response({'detail': 'Plan not found.'}, status=404)
        return Response(InvestmentPlanSerializer(plan).data)


class InvestmentFaqListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        return Response(InvestmentFaqSerializer(InvestmentFaq.objects.all(), many=True).data)


class SubscribeInvestmentView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        serializer = SubscribeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        plan = InvestmentPlan.objects.get(pk=serializer.validated_data['plan_id'], is_active=True)
        amount = serializer.validated_data['amount']

        if amount < plan.minimum_investment:
            return Response(
                {'detail': f'Minimum investment is ₹{plan.minimum_investment}.'},
                status=400,
            )

        wallet = Wallet.objects.select_for_update().get(user=request.user)
        if wallet.balance < amount:
            return Response({'detail': 'Insufficient wallet balance.'}, status=400)

        monthly_return = amount * (plan.monthly_return_rate / Decimal('100'))
        ref_id = f'BW-{timezone.now().strftime("%Y")}-{uuid.uuid4().hex[:6].upper()}'

        investment = UserInvestment.objects.create(
            user=request.user,
            plan=plan,
            amount=amount,
            monthly_return=monthly_return,
            status=UserInvestment.Status.ACTIVE,
            reference_id=ref_id,
            documents=['Investment Agreement', 'Receipt', 'Terms & Conditions'],
        )

        wallet.balance -= amount
        wallet.save(update_fields=['balance'])

        Transaction.objects.create(
            user=request.user,
            reference_id=ref_id,
            type=Transaction.TxType.INVESTMENT,
            status=Transaction.Status.COMPLETED,
            amount=amount,
            description=f'{plan.name} Investment',
        )

        Notification.objects.create(
            user=request.user,
            title='Investment Successful',
            message=f'Your investment of ₹{amount:,.0f} in {plan.name} is confirmed.',
            type='investment',
        )

        return Response(UserInvestmentSerializer(investment).data, status=201)


class MyInvestmentsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        investments = request.user.investments.select_related('plan')
        return Response(UserInvestmentSerializer(investments, many=True).data)


class MyInvestmentDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, investment_id):
        try:
            investment = request.user.investments.select_related('plan').get(pk=investment_id)
        except UserInvestment.DoesNotExist:
            return Response({'detail': 'Investment not found.'}, status=404)
        return Response(UserInvestmentSerializer(investment).data)


class PortfolioView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(PortfolioSerializer(_build_portfolio(request.user)).data)


class PortfolioAllocationsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        investments = (
            request.user.investments.filter(status=UserInvestment.Status.ACTIVE)
            .values('plan__name')
            .annotate(total=Sum('amount'))
        )
        grand_total = sum(i['total'] for i in investments) or Decimal('1')
        colors = [0xFF1B3A6B, 0xFF10B981, 0xFF2E5090, 0xFFF59E0B, 0xFF6366F1]
        allocations = []
        for idx, item in enumerate(investments):
            allocations.append(
                {
                    'label': item['plan__name'],
                    'percentage': round(float(item['total'] / grand_total * 100), 1),
                    'colorValue': colors[idx % len(colors)],
                }
            )
        return Response(allocations)


class PortfolioEarningsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from django.db.models.functions import TruncMonth

        profits = list(
            Transaction.objects.filter(user=request.user, type=Transaction.TxType.PROFIT)
            .annotate(month=TruncMonth('created_at'))
            .values('month')
            .annotate(total=Sum('amount'))
            .order_by('month')
        )[-6:]
        months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
        return Response(
            [
                {'month': months[p['month'].month - 1], 'amount': float(p['total'])}
                for p in profits
            ]
        )


class WalletView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        wallet, _ = Wallet.objects.get_or_create(user=request.user)
        bank = getattr(request.user, 'bank_account', None)
        data = WalletSerializer(wallet).data
        if bank:
            masked = f'****{bank.account_number[-4:]}' if len(bank.account_number) >= 4 else bank.account_number
            data['bankName'] = bank.bank_name
            data['accountNumber'] = masked
            data['ifsc'] = bank.ifsc
        else:
            data['bankName'] = ''
            data['accountNumber'] = ''
            data['ifsc'] = ''
        return Response(data)


class WalletTransactionsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        wallet, _ = Wallet.objects.get_or_create(user=request.user)
        txs = wallet.transactions.all()
        return Response(WalletTransactionSerializer(txs, many=True).data)


class DepositView(APIView):
    """Instant deposit — dev only when Razorpay is not configured."""

    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        from core.integrations.razorpay_service import is_configured

        if is_configured():
            return Response(
                {
                    'detail': 'Use POST /wallet/deposit/create-order/ and /wallet/deposit/verify/ for Razorpay payments.',
                },
                status=400,
            )
        if not settings.DEBUG:
            return Response(
                {'detail': 'Configure RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET for deposits.'},
                status=503,
            )

        serializer = DepositWithdrawSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        amount = serializer.validated_data['amount']
        wallet = Wallet.objects.select_for_update().get(user=request.user)

        WalletTransaction.objects.create(
            wallet=wallet,
            type=WalletTransaction.TxType.DEPOSIT,
            amount=amount,
            status=WalletTransaction.Status.COMPLETED,
        )
        wallet.balance += amount
        wallet.save(update_fields=['balance'])
        return Response({'success': True, 'balance': float(wallet.balance)})


class WithdrawView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        serializer = DepositWithdrawSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        amount = serializer.validated_data['amount']
        wallet = Wallet.objects.select_for_update().get(user=request.user)

        if wallet.balance < amount:
            return Response({'detail': 'Insufficient balance.'}, status=400)

        bank = getattr(request.user, 'bank_account', None)
        if not bank or not bank.is_verified:
            return Response({'detail': 'Verified bank account required.'}, status=400)

        ref_id = f'BW-WD-{uuid.uuid4().hex[:6].upper()}'
        WalletTransaction.objects.create(
            wallet=wallet,
            type=WalletTransaction.TxType.WITHDRAWAL,
            amount=amount,
            status=WalletTransaction.Status.PENDING,
        )
        wallet.balance -= amount
        wallet.save(update_fields=['balance'])

        Transaction.objects.create(
            user=request.user,
            reference_id=ref_id,
            type=Transaction.TxType.WITHDRAWAL,
            status=Transaction.Status.PENDING,
            amount=amount,
            description='Wallet Withdrawal',
        )
        return Response({'success': True, 'balance': float(wallet.balance)})


class TransactionListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        tx_type = request.query_params.get('type')
        qs = request.user.transactions.all()
        if tx_type and tx_type != 'all':
            qs = qs.filter(type=tx_type)
        return Response(TransactionSerializer(qs, many=True).data)


def _build_portfolio(user, *, refresh_stocks=False):
    from stocks.portfolio_service import get_stock_summary

    stock = get_stock_summary(user, refresh=refresh_stocks)
    stock_invested = Decimal(str(stock['total_invested']))
    stock_value = Decimal(str(stock['current_value']))
    stock_pnl = Decimal(str(stock['total_pnl']))
    day_pnl = Decimal(str(stock['day_pnl']))

    active = user.investments.filter(status=UserInvestment.Status.ACTIVE)
    plan_invested = active.aggregate(t=Sum('amount'))['t'] or Decimal('0')
    monthly_profit = active.aggregate(t=Sum('monthly_return'))['t'] or Decimal('0')
    plan_profit = (
        user.transactions.filter(type=Transaction.TxType.PROFIT).aggregate(t=Sum('amount'))['t']
        or monthly_profit
    )
    plan_current = plan_invested + plan_profit

    total_investment = stock_invested + plan_invested
    current_value = stock_value + plan_current
    total_profit = stock_pnl + plan_profit
    growth = (
        float((current_value - total_investment) / total_investment * 100)
        if total_investment
        else 0.0
    )
    return {
        'total_investment': total_investment,
        'current_value': current_value,
        'monthly_profit': monthly_profit,
        'total_profit': total_profit,
        'growth_percent': round(growth, 2),
        'day_pnl': day_pnl,
        'day_pnl_percent': stock['day_pnl_percent'],
        'holdings_count': stock['holdings_count'],
        'stocks_invested': stock_invested,
        'stocks_value': stock_value,
    }
