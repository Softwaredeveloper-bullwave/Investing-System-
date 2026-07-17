from decimal import Decimal

from django.conf import settings
from django.db import transaction

from accounts.models import User
from finance.models import Wallet, WalletTransaction

from .models import Notification, ReferralReward


def referral_reward_amount() -> Decimal:
    return Decimal(str(getattr(settings, 'REFERRAL_REWARD_AMOUNT', 500)))


def apply_referral_code(user: User, code: str) -> tuple[bool, str]:
    normalized = (code or '').strip().upper()
    if not normalized:
        return False, 'Enter a referral code.'

    if user.referred_by_id:
        return False, 'Referral code already applied.'

    try:
        referrer = User.objects.get(referral_code__iexact=normalized)
    except User.DoesNotExist:
        return False, 'Invalid referral code.'

    if referrer.pk == user.pk:
        return False, 'You cannot use your own referral code.'

    user.referred_by = referrer
    user.save(update_fields=['referred_by'])
    return True, 'Referral code applied.'


@transaction.atomic
def credit_referral_reward(referred_user: User) -> bool:
    """Pay referrer when referred user completes onboarding (once)."""
    if not referred_user.referred_by_id:
        return False
    if not referred_user.has_completed_onboarding:
        return False
    if ReferralReward.objects.filter(referred_user=referred_user).exists():
        return False

    referrer = referred_user.referred_by
    reward_amount = referral_reward_amount()

    ReferralReward.objects.create(
        user=referrer,
        referred_user=referred_user,
        friend_name=referred_user.name or referred_user.phone,
        amount=reward_amount,
    )

    wallet, _ = Wallet.objects.get_or_create(user=referrer)
    wallet.balance += reward_amount
    wallet.save(update_fields=['balance'])

    WalletTransaction.objects.create(
        wallet=wallet,
        type=WalletTransaction.TxType.PROFIT_CREDIT,
        amount=reward_amount,
        status=WalletTransaction.Status.COMPLETED,
    )

    Notification.objects.create(
        user=referrer,
        title='Referral reward credited',
        message=f'You earned ₹{reward_amount:,.0f} because a friend joined with your code!',
        type='referral',
    )

    return True


def build_share_message(user: User) -> str:
    amount = int(referral_reward_amount())
    app_url = getattr(settings, 'APP_SHARE_URL', 'https://bullwave.in')
    return (
        f'Join me on BullWave Invest and explore live markets & stocks!\n\n'
        f'My referral code: {user.referral_code}\n'
        f'Download: {app_url}\n\n'
        f'Sign up, complete your profile, and we both win — earn up to ₹{amount:,} per referral!'
    )
