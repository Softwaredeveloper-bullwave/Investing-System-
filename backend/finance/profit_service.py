"""Monthly investment plan profit credits."""

import logging
from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from engagement.models import Notification

from .models import Transaction, UserInvestment, Wallet, WalletTransaction

logger = logging.getLogger('bullwave.finance')


@transaction.atomic
def credit_monthly_investment_returns() -> int:
    """Credit monthly returns for active investments. Returns count credited."""
    month_key = timezone.localdate().strftime('%Y-%m')
    investments = UserInvestment.objects.filter(status=UserInvestment.Status.ACTIVE).select_related(
        'user', 'plan'
    )
    credited = 0

    for inv in investments:
        ref = f'PROFIT-{month_key}-{inv.reference_id}'
        if Transaction.objects.filter(user=inv.user, reference_id=ref).exists():
            continue

        amount = inv.monthly_return
        if amount <= 0:
            continue

        wallet, _ = Wallet.objects.select_for_update().get_or_create(user=inv.user)
        wallet.balance += amount
        wallet.save(update_fields=['balance'])

        WalletTransaction.objects.create(
            wallet=wallet,
            type=WalletTransaction.TxType.PROFIT_CREDIT,
            amount=amount,
            status=WalletTransaction.Status.COMPLETED,
        )
        Transaction.objects.create(
            user=inv.user,
            reference_id=ref,
            type=Transaction.TxType.PROFIT,
            status=Transaction.Status.COMPLETED,
            amount=amount,
            description=f'{inv.plan.name} monthly return',
        )
        Notification.objects.create(
            user=inv.user,
            title='Monthly Return Credited',
            message=f'₹{amount:,.0f} credited to your wallet from {inv.plan.name}.',
            type='profit',
        )
        credited += 1

    return credited
