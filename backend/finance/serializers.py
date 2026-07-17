from rest_framework import serializers

from core.serializers import CamelCaseModelSerializer, CamelCaseSerializer
from .models import (
    InvestmentFaq,
    InvestmentPlan,
    Transaction,
    UserInvestment,
    Wallet,
    WalletTransaction,
)


class InvestmentPlanSerializer(CamelCaseModelSerializer):
    class Meta:
        model = InvestmentPlan
        fields = (
            'id', 'name', 'minimum_investment', 'monthly_return_rate',
            'monthly_return_min', 'monthly_return_max',
            'annual_return_rate', 'description', 'is_featured',
        )


class UserInvestmentSerializer(CamelCaseModelSerializer):
    plan_name = serializers.CharField(source='plan.name', read_only=True)
    date = serializers.DateTimeField(source='invested_at')

    class Meta:
        model = UserInvestment
        fields = (
            'id', 'plan_name', 'amount', 'date', 'monthly_return',
            'status', 'reference_id', 'documents',
        )


class PortfolioSerializer(CamelCaseSerializer):
    total_investment = serializers.DecimalField(max_digits=14, decimal_places=2)
    current_value = serializers.DecimalField(max_digits=14, decimal_places=2)
    monthly_profit = serializers.DecimalField(max_digits=14, decimal_places=2)
    total_profit = serializers.DecimalField(max_digits=14, decimal_places=2)
    growth_percent = serializers.FloatField()
    day_pnl = serializers.DecimalField(max_digits=14, decimal_places=2, required=False)
    day_pnl_percent = serializers.FloatField(required=False)
    holdings_count = serializers.IntegerField(required=False)
    stocks_invested = serializers.DecimalField(max_digits=14, decimal_places=2, required=False)
    stocks_value = serializers.DecimalField(max_digits=14, decimal_places=2, required=False)
    wallet_balance = serializers.DecimalField(max_digits=14, decimal_places=2, required=False)


class WalletSerializer(CamelCaseModelSerializer):
    class Meta:
        model = Wallet
        fields = ('balance',)


class WalletTransactionSerializer(CamelCaseModelSerializer):
    date = serializers.DateTimeField(source='created_at')

    class Meta:
        model = WalletTransaction
        fields = ('id', 'type', 'amount', 'date', 'status')


class TransactionSerializer(CamelCaseModelSerializer):
    date = serializers.DateTimeField(source='created_at')

    class Meta:
        model = Transaction
        fields = ('id', 'reference_id', 'type', 'status', 'amount', 'date', 'description')


class InvestmentFaqSerializer(CamelCaseModelSerializer):
    class Meta:
        model = InvestmentFaq
        fields = ('question', 'answer')


class SubscribeSerializer(CamelCaseSerializer):
    plan_id = serializers.CharField()
    amount = serializers.DecimalField(max_digits=14, decimal_places=2)


class DepositWithdrawSerializer(CamelCaseSerializer):
    amount = serializers.DecimalField(max_digits=14, decimal_places=2, min_value=1)
