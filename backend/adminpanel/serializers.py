from __future__ import annotations

from decimal import Decimal

from rest_framework import serializers

from accounts.models import BankAccount, KycDocument, User


def _fmt_date(dt):
    if not dt:
        return None
    return dt.strftime('%d %b %Y')


def _fmt_datetime(dt):
    if not dt:
        return None
    return dt.strftime('%d %b %Y, %I:%M %p')


def _abs_url(request, file_field):
    if not file_field:
        return ''
    try:
        url = file_field.url
    except ValueError:
        return ''
    if request is not None:
        return request.build_absolute_uri(url)
    return url


_KYC_STATUS_MAP = {
    User.KycStatus.VERIFIED: 'approved',
    User.KycStatus.COMPLETED: 'approved',
    User.KycStatus.PENDING: 'pending',
    User.KycStatus.IN_PROGRESS: 'pending',
    User.KycStatus.REJECTED: 'rejected',
    User.KycStatus.NOT_SUBMITTED: 'not_submitted',
}


def _mapped_kyc_status(user: User) -> str:
    return _KYC_STATUS_MAP.get(user.kyc_status, user.kyc_status or 'not_submitted')


def serialize_user_list_item(user: User) -> dict:
    """Lightweight shape for the admin Users table — no extra queries per row
    beyond what a `select_related('bank_account')` prefetch already covers.
    """
    return {
        'id': str(user.id),
        'name': user.name or user.phone,
        'email': user.email or '',
        'phone': user.phone,
        'avatar': user.avatar_url or '',
        'status': 'active' if user.is_active else 'blocked',
        'kycStatus': _mapped_kyc_status(user),
        'joinedAt': _fmt_date(user.date_joined),
        'lastLogin': _fmt_datetime(user.last_login),
    }


def serialize_user_detail(user: User, request=None) -> dict:
    """Full shape for the admin User Details modal — one user at a time, so
    the extra related-model lookups here are cheap.
    """
    from finance.models import Wallet, WalletTransaction
    from stocks.trading_service import get_or_create_paper_wallet

    base = serialize_user_list_item(user)

    # --- Bank & PAN info: prefer the live KYC profile, fall back to the
    # legacy BankAccount row if that's all that exists for this user. ---
    pan_number = ''
    account_number = ''
    ifsc_code = ''
    bank_name = ''
    account_holder_name = ''

    kyc_profile = getattr(user, 'kyc_profile', None)
    if kyc_profile is not None:
        pan_number = kyc_profile.pan_number or ''
        account_number = kyc_profile.bank_account_number or ''
        ifsc_code = kyc_profile.bank_ifsc or ''
        bank_name = kyc_profile.bank_name or ''
        account_holder_name = kyc_profile.account_holder_name or ''

    if not (pan_number and account_number):
        bank_account = BankAccount.objects.filter(user=user).first()
        if bank_account:
            pan_number = pan_number or bank_account.pan_number
            account_number = account_number or bank_account.account_number
            ifsc_code = ifsc_code or bank_account.ifsc
            bank_name = bank_name or bank_account.bank_name
            account_holder_name = account_holder_name or bank_account.account_holder_name

    # --- Wallet / paper-trading balances ---
    from django.db.models import Sum

    wallet, _ = Wallet.objects.get_or_create(user=user)
    total_deposited = (
        WalletTransaction.objects.filter(
            wallet=wallet,
            type=WalletTransaction.TxType.DEPOSIT,
            status=WalletTransaction.Status.COMPLETED,
        ).aggregate(total=Sum('amount'))['total']
        or Decimal('0')
    )

    try:
        paper_balance = get_or_create_paper_wallet(user).balance
    except Exception:
        paper_balance = Decimal('0')

    # --- KYC documents: prefer a manual KYCRequest (has the review trail),
    # fall back to individually-uploaded KycDocument rows. ---
    document_type = ''
    document_number = pan_number
    submitted_at = None
    reviewed_at = None
    document_front = ''
    document_back = ''
    selfie = ''

    try:
        from kyc.models import KYCRequest

        kyc_request = KYCRequest.objects.filter(user=user).order_by('-created_at').first()
    except Exception:
        kyc_request = None

    if kyc_request is not None:
        document_type = 'PAN Card'
        document_number = kyc_request.pan_number or document_number
        submitted_at = kyc_request.created_at
        reviewed_at = kyc_request.reviewed_at
        document_front = _abs_url(request, kyc_request.pan_image)

    docs = {d.document_type: d for d in KycDocument.objects.filter(user=user)}
    if KycDocument.DocumentType.AADHAAR_FRONT in docs:
        document_front = document_front or _abs_url(request, docs[KycDocument.DocumentType.AADHAAR_FRONT].file)
        submitted_at = submitted_at or docs[KycDocument.DocumentType.AADHAAR_FRONT].uploaded_at
        document_type = document_type or 'Aadhaar Card'
    if KycDocument.DocumentType.AADHAAR_BACK in docs:
        document_back = _abs_url(request, docs[KycDocument.DocumentType.AADHAAR_BACK].file)
    if KycDocument.DocumentType.SELFIE in docs:
        selfie = _abs_url(request, docs[KycDocument.DocumentType.SELFIE].file)
    if KycDocument.DocumentType.PAN in docs and not document_front:
        document_front = _abs_url(request, docs[KycDocument.DocumentType.PAN].file)
        document_type = document_type or 'PAN Card'
        submitted_at = submitted_at or docs[KycDocument.DocumentType.PAN].uploaded_at

    base.update(
        {
            'panNumber': pan_number,
            'accountNumber': account_number,
            'ifscCode': ifsc_code,
            'bankName': bank_name,
            'accountHolderName': account_holder_name,
            'coinBalance': float(wallet.balance),
            'totalCoinsPurchased': float(total_deposited),
            'totalAmountSpent': float(total_deposited),
            'paperTradingBalance': float(paper_balance),
            'kyc': {
                'documentType': document_type,
                'documentNumber': document_number,
                'submittedAt': _fmt_date(submitted_at),
                'reviewedAt': _fmt_date(reviewed_at),
                'documentFront': document_front,
                'documentBack': document_back,
                'selfie': selfie,
            },
            'address': {
                'street': '',
                'city': user.city or '',
                'state': '',
                'postalCode': '',
                'country': 'India',
            },
        }
    )
    return base


class AdminLoginSerializer(serializers.Serializer):
    phone = serializers.CharField()
    password = serializers.CharField(write_only=True)


_KYC_REQUEST_STATUS_MAP = {
    'PENDING': 'pending',
    'APPROVED': 'approved',
    'REJECTED': 'rejected',
}


def serialize_kyc_request(req, request=None) -> dict:
    """Shape for the admin KYC Requests table/modal — from a manual
    `kyc.KYCRequest` (PAN photo submission), the actual review workflow this
    app uses.
    """
    user = req.user
    return {
        'id': str(req.id),
        'userId': str(user.id),
        'userName': user.name or user.phone,
        'email': user.email or '',
        'phone': user.phone,
        'documentType': 'PAN Card',
        'documentNumber': req.pan_number,
        'status': _KYC_REQUEST_STATUS_MAP.get(req.status, req.status.lower()),
        'submittedAt': _fmt_date(req.created_at),
        'reviewedAt': _fmt_date(req.reviewed_at),
        'reviewedBy': (req.reviewed_by.name or req.reviewed_by.phone) if req.reviewed_by else None,
        'rejectionReason': req.rejection_reason,
        'documents': {
            'front': _abs_url(request, req.pan_image),
            'back': '',
            'selfie': '',
        },
    }


def serialize_admin_notification(notif) -> dict:
    """A message the admin panel sent to a user via the shared Notification
    model (same one the Flutter app already polls for its notification
    bell), so this is real, not a separate admin-only inbox.
    """
    return {
        'id': str(notif.id),
        'title': notif.title,
        'message': notif.message,
        'type': notif.type,
        'isRead': notif.is_read,
        'createdAt': _fmt_datetime(notif.created_at),
    }


def serialize_paper_trade(trade) -> dict:
    """A single executed paper-trading fill — real trading activity from a
    real user, shown as-is (no synthetic OPEN/CLOSED position pairing).
    """
    user = trade.user
    return {
        'id': str(trade.id),
        'user': {
            'name': user.name or user.phone,
            'email': user.email or '',
            'phone': user.phone,
        },
        'symbol': trade.stock.symbol,
        'company': trade.stock.name,
        'exchange': trade.stock.exchange,
        'side': trade.side,
        'quantity': trade.quantity,
        'price': float(trade.price),
        'avgCost': float(trade.avg_cost) if trade.avg_cost is not None else None,
        'pnl': float(trade.realized_pnl) if trade.realized_pnl is not None else None,
        'status': trade.status,
        'time': _fmt_datetime(trade.created_at),
    }
