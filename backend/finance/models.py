import uuid
from decimal import Decimal

from django.conf import settings
from django.db import models


class InvestmentPlan(models.Model):
    id = models.CharField(primary_key=True, max_length=20)
    name = models.CharField(max_length=120)
    minimum_investment = models.DecimalField(max_digits=14, decimal_places=2)
    monthly_return_rate = models.DecimalField(max_digits=5, decimal_places=2)
    monthly_return_min = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal('0.20'))
    monthly_return_max = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal('2.00'))
    annual_return_rate = models.DecimalField(max_digits=5, decimal_places=2)
    description = models.TextField()
    is_featured = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name


class UserInvestment(models.Model):
    class Status(models.TextChoices):
        ACTIVE = 'Active', 'Active'
        PENDING = 'Pending', 'Pending'
        CLOSED = 'Closed', 'Closed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='investments'
    )
    plan = models.ForeignKey(InvestmentPlan, on_delete=models.PROTECT, related_name='investments')
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    monthly_return = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0'))
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    reference_id = models.CharField(max_length=30, unique=True)
    invested_at = models.DateTimeField(auto_now_add=True)
    documents = models.JSONField(default=list, blank=True)

    class Meta:
        ordering = ['-invested_at']


class Wallet(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='wallet'
    )
    balance = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0'))
    updated_at = models.DateTimeField(auto_now=True)


class WalletTransaction(models.Model):
    class TxType(models.TextChoices):
        DEPOSIT = 'Deposit', 'Deposit'
        WITHDRAWAL = 'Withdrawal', 'Withdrawal'
        PROFIT_CREDIT = 'Profit Credit', 'Profit Credit'

    class Status(models.TextChoices):
        COMPLETED = 'Completed', 'Completed'
        PENDING = 'Pending', 'Pending'
        FAILED = 'Failed', 'Failed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    wallet = models.ForeignKey(Wallet, on_delete=models.CASCADE, related_name='transactions')
    type = models.CharField(max_length=20, choices=TxType.choices)
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class Transaction(models.Model):
    class TxType(models.TextChoices):
        INVESTMENT = 'investment', 'Investment'
        PROFIT = 'profit', 'Profit'
        WITHDRAWAL = 'withdrawal', 'Withdrawal'

    class Status(models.TextChoices):
        COMPLETED = 'completed', 'Completed'
        PENDING = 'pending', 'Pending'
        FAILED = 'failed', 'Failed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='transactions'
    )
    reference_id = models.CharField(max_length=30)
    type = models.CharField(max_length=20, choices=TxType.choices)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    description = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class InvestmentFaq(models.Model):
    question = models.CharField(max_length=500)
    answer = models.TextField()
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['order']


class PaymentOrder(models.Model):
    class Status(models.TextChoices):
        CREATED = 'created', 'Created'
        PAID = 'paid', 'Paid'
        FAILED = 'failed', 'Failed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='payment_orders'
    )
    gateway = models.CharField(max_length=20, default='razorpay')
    order_id = models.CharField(max_length=80, unique=True)
    payment_id = models.CharField(max_length=80, blank=True)
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    currency = models.CharField(max_length=3, default='INR')
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.CREATED)
    created_at = models.DateTimeField(auto_now_add=True)
    paid_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']


class GoalPlanTemplate(models.Model):
    """PhonePe-style savings goal categories."""

    class Category(models.TextChoices):
        HOUSE = 'house', 'Dream Home'
        RETIREMENT = 'retirement', 'Retirement'
        EDUCATION = 'education', 'Education'
        MARRIAGE = 'marriage', 'Marriage'
        VEHICLE = 'vehicle', 'Vehicle'

    id = models.CharField(primary_key=True, max_length=30)
    category = models.CharField(max_length=20, choices=Category.choices, unique=True)
    name = models.CharField(max_length=120)
    tagline = models.CharField(max_length=255)
    icon = models.CharField(max_length=40, default='savings')
    color = models.CharField(max_length=20, default='#9333EA')
    min_target = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('10000'))
    suggested_monthly = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('2000'))
    min_duration_months = models.PositiveIntegerField(default=3)
    max_duration_months = models.PositiveIntegerField(default=24)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return self.name


class UserGoalPlan(models.Model):
    class Status(models.TextChoices):
        ACTIVE = 'active', 'Active'
        COMPLETED = 'completed', 'Completed'
        PAUSED = 'paused', 'Paused'
        CLOSED = 'closed', 'Closed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='goal_plans'
    )
    template = models.ForeignKey(
        GoalPlanTemplate, on_delete=models.PROTECT, related_name='user_goals', null=True, blank=True
    )
    category = models.CharField(max_length=20)
    title = models.CharField(max_length=120)
    target_amount = models.DecimalField(max_digits=14, decimal_places=2)
    monthly_contribution = models.DecimalField(max_digits=14, decimal_places=2)
    duration_months = models.PositiveIntegerField()
    accumulated_amount = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0'))
    returns_earned = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0'))
    annual_return_rate = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal('8'))
    installments_done = models.PositiveIntegerField(default=0)
    next_contribution_date = models.DateField(null=True, blank=True)
    target_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.ACTIVE)
    reference_id = models.CharField(max_length=30, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    @property
    def progress_percent(self) -> float:
        if self.target_amount <= 0:
            return 0.0
        return min(100.0, float(self.accumulated_amount / self.target_amount * 100))


class GoalContribution(models.Model):
    class Kind(models.TextChoices):
        INITIAL = 'initial', 'Initial'
        MONTHLY = 'monthly', 'Monthly'
        TOP_UP = 'top_up', 'Top-up'
        RETURN = 'return', 'Return'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    goal = models.ForeignKey(UserGoalPlan, on_delete=models.CASCADE, related_name='contributions')
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    kind = models.CharField(max_length=20, choices=Kind.choices)
    created_at = models.DateTimeField(auto_now_add=True)
