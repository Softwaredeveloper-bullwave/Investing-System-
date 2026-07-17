"""F&O eligibility — document upload or ₹50k portfolio holding."""

from __future__ import annotations

from decimal import Decimal
from typing import Optional

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from accounts.models import User

from .models import FnoEligibilityRequest
from .notifications import (
    notify_admin_new_fno_request,
    notify_user_fno_approved,
    notify_user_fno_rejected,
)


class FnoError(Exception):
    pass


FNO_PROOF_TYPES = frozenset(
    {
        FnoEligibilityRequest.ProofType.BANK_STATEMENT,
        FnoEligibilityRequest.ProofType.FORM16,
        FnoEligibilityRequest.ProofType.ITR,
        FnoEligibilityRequest.ProofType.PORTFOLIO_HOLDING,
    }
)

DOCUMENT_PROOF_TYPES = frozenset(
    {
        FnoEligibilityRequest.ProofType.BANK_STATEMENT,
        FnoEligibilityRequest.ProofType.FORM16,
        FnoEligibilityRequest.ProofType.ITR,
    }
)


def _min_portfolio_value() -> Decimal:
    return Decimal(str(getattr(settings, 'FNO_MIN_PORTFOLIO_VALUE', 50000)))


def _portfolio_current_value(user: User) -> Decimal:
    """Fast total portfolio value — uses DB quotes only (no live market refresh)."""
    from django.db.models import Sum

    from finance.models import Transaction, UserInvestment
    from stocks.portfolio_service import get_stock_summary

    stock = get_stock_summary(user, refresh=False)
    stock_value = Decimal(str(stock.get('current_value') or 0))

    active = user.investments.filter(status=UserInvestment.Status.ACTIVE)
    plan_invested = active.aggregate(t=Sum('amount'))['t'] or Decimal('0')
    monthly_profit = active.aggregate(t=Sum('monthly_return'))['t'] or Decimal('0')
    plan_profit = (
        user.transactions.filter(type=Transaction.TxType.PROFIT).aggregate(t=Sum('amount'))['t']
        or monthly_profit
    )
    return stock_value + plan_invested + plan_profit


def user_fno_is_verified(user: User) -> bool:
    status = (user.fno_status or '').lower()
    if status == User.FnoStatus.VERIFIED:
        return True
    return user.fno_requests.filter(status=FnoEligibilityRequest.Status.APPROVED).exists()


def serialize_fno_request(req: FnoEligibilityRequest, request=None) -> dict:
    doc_url = ''
    if req.document:
        if request is not None:
            doc_url = request.build_absolute_uri(req.document.url)
        else:
            doc_url = req.document.url
    return {
        'id': str(req.id),
        'proof_type': req.proof_type,
        'proof_label': req.get_proof_type_display(),
        'status': req.status,
        'portfolio_value': float(req.portfolio_value or 0),
        'document_url': doc_url,
        'rejection_reason': req.rejection_reason,
        'reviewed_at': req.reviewed_at.isoformat() if req.reviewed_at else None,
        'created_at': req.created_at.isoformat(),
    }


def get_fno_me_payload(user: User, request=None) -> dict:
    latest = user.fno_requests.order_by('-created_at').first()
    portfolio_value = _portfolio_current_value(user)
    min_value = _min_portfolio_value()
    return {
        'fno_status': user.fno_status,
        'is_verified': user_fno_is_verified(user),
        'portfolio_value': float(portfolio_value),
        'min_portfolio_value': float(min_value),
        'latest_request': serialize_fno_request(latest, request) if latest else None,
        'proof_options': [
            {
                'type': FnoEligibilityRequest.ProofType.BANK_STATEMENT,
                'label': '6-Month Bank Statement',
                'requires_upload': True,
            },
            {
                'type': FnoEligibilityRequest.ProofType.FORM16,
                'label': 'FORM 16',
                'requires_upload': True,
            },
            {
                'type': FnoEligibilityRequest.ProofType.ITR,
                'label': 'ITR Form',
                'requires_upload': True,
            },
            {
                'type': FnoEligibilityRequest.ProofType.PORTFOLIO_HOLDING,
                'label': f'₹{int(min_value):,} Portfolio Holding',
                'requires_upload': False,
            },
        ],
    }


@transaction.atomic
def submit_fno_eligibility(
    user: User,
    *,
    proof_type: str,
    document=None,
    reviewer: Optional[User] = None,
) -> FnoEligibilityRequest:
    proof_type = (proof_type or '').strip().lower()
    if proof_type not in FNO_PROOF_TYPES:
        raise FnoError('Invalid F&O proof type.')

    if user_fno_is_verified(user):
        raise FnoError('F&O access is already enabled for your account.')

    pending = user.fno_requests.filter(status=FnoEligibilityRequest.Status.PENDING).exists()
    if pending:
        raise FnoError('You already have an F&O verification request under review.')

    portfolio_value = _portfolio_current_value(user)
    min_value = _min_portfolio_value()
    now = timezone.now()

    if proof_type == FnoEligibilityRequest.ProofType.PORTFOLIO_HOLDING:
        if portfolio_value < min_value:
            raise FnoError(
                f'Your portfolio value is ₹{portfolio_value:,.0f}. '
                f'At least ₹{min_value:,.0f} is required for F&O access.'
            )
        req = FnoEligibilityRequest.objects.create(
            user=user,
            proof_type=proof_type,
            portfolio_value=portfolio_value,
            status=FnoEligibilityRequest.Status.APPROVED,
            reviewed_at=now,
        )
        user.fno_status = User.FnoStatus.VERIFIED
        user.save(update_fields=['fno_status'])
        return req

    if proof_type in DOCUMENT_PROOF_TYPES and document is None:
        raise FnoError('Please upload your document to continue.')

    req = FnoEligibilityRequest.objects.create(
        user=user,
        proof_type=proof_type,
        document=document,
        portfolio_value=portfolio_value,
        status=FnoEligibilityRequest.Status.PENDING,
    )
    user.fno_status = User.FnoStatus.PENDING
    user.save(update_fields=['fno_status'])

    req_id = str(req.id)
    doc_path = getattr(req.document, 'path', '') or ''
    doc_url = req.document.url if req.document else ''
    user_phone = user.phone
    user_email = user.email or ''
    user_name = user.name or ''
    proof_label = req.get_proof_type_display()
    submitted_at = req.created_at.isoformat()
    portfolio_float = float(portfolio_value)

    transaction.on_commit(
        lambda: notify_admin_new_fno_request(
            user_phone=user_phone,
            user_email=user_email,
            user_name=user_name,
            proof_label=proof_label,
            portfolio_value=portfolio_float,
            request_id=req_id,
            document_path=doc_path,
            document_url=doc_url,
            submitted_at=submitted_at,
        )
    )
    return req


@transaction.atomic
def approve_fno_request(req: FnoEligibilityRequest, admin_user: User) -> FnoEligibilityRequest:
    if req.status != FnoEligibilityRequest.Status.PENDING:
        raise FnoError('Only pending F&O requests can be approved.')

    now = timezone.now()
    req.status = FnoEligibilityRequest.Status.APPROVED
    req.reviewed_by = admin_user
    req.reviewed_at = now
    req.rejection_reason = ''
    req.save(update_fields=['status', 'reviewed_by', 'reviewed_at', 'rejection_reason', 'updated_at'])

    user = req.user
    user.fno_status = User.FnoStatus.VERIFIED
    user.save(update_fields=['fno_status'])

    user_phone = user.phone
    user_email = user.email or ''
    user_name = user.name or ''
    transaction.on_commit(
        lambda: notify_user_fno_approved(
            user_phone=user_phone,
            user_name=user_name,
            user_email=user_email,
        )
    )
    return req


@transaction.atomic
def reject_fno_request(req: FnoEligibilityRequest, admin_user: User, reason: str) -> FnoEligibilityRequest:
    if req.status != FnoEligibilityRequest.Status.PENDING:
        raise FnoError('Only pending F&O requests can be rejected.')

    reason = (reason or 'Document could not be verified. Please resubmit.').strip()[:500]
    now = timezone.now()
    req.status = FnoEligibilityRequest.Status.REJECTED
    req.reviewed_by = admin_user
    req.reviewed_at = now
    req.rejection_reason = reason
    req.save(update_fields=['status', 'reviewed_by', 'reviewed_at', 'rejection_reason', 'updated_at'])

    user = req.user
    user.fno_status = User.FnoStatus.REJECTED
    user.save(update_fields=['fno_status'])

    user_phone = user.phone
    user_email = user.email or ''
    user_name = user.name or ''
    rejection = reason
    transaction.on_commit(
        lambda: notify_user_fno_rejected(
            user_phone=user_phone,
            user_name=user_name,
            user_email=user_email,
            reason=rejection,
        )
    )
    return req
