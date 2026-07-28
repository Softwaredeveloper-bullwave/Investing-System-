from __future__ import annotations

import logging

from django.db.models import Q
from django.utils import timezone
from rest_framework import status
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import User

from .permissions import IsAdminStaff
from .serializers import (
    AdminLoginSerializer,
    serialize_admin_notification,
    serialize_kyc_request,
    serialize_paper_trade,
    serialize_user_detail,
    serialize_user_list_item,
)

logger = logging.getLogger('bullwave.adminpanel')


class AdminLoginView(APIView):
    """Staff-only login for the separate admin panel. Uses the same phone +
    password credentials as `manage.py createsuperuser` — this endpoint just
    additionally requires `is_staff`/`is_superuser` before issuing tokens, so
    a regular customer account (which has no usable password anyway) can
    never authenticate here even if they somehow guessed a password.
    """

    permission_classes = [AllowAny]

    def post(self, request):
        serializer = AdminLoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data['phone'].strip()
        password = serializer.validated_data['password']

        user = User.objects.filter(phone=phone).first()
        if user is None or not user.has_usable_password() or not user.check_password(password):
            return Response({'detail': 'Invalid phone number or password.'}, status=status.HTTP_401_UNAUTHORIZED)

        if not (user.is_staff or user.is_superuser):
            return Response(
                {'detail': 'This account does not have admin panel access.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        if not user.is_active:
            return Response({'detail': 'This admin account has been deactivated.'}, status=status.HTTP_403_FORBIDDEN)

        user.last_login = timezone.now()
        user.save(update_fields=['last_login'])

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                'access': str(refresh.access_token),
                'refresh': str(refresh),
                'admin': {
                    'id': str(user.id),
                    'name': user.name or user.phone,
                    'phone': user.phone,
                    'email': user.email,
                    'isSuperuser': user.is_superuser,
                },
            }
        )


class AdminUserPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'pageSize'
    max_page_size = 100

    def get_paginated_response(self, data):
        return Response(
            {
                'results': data,
                'count': self.page.paginator.count,
                'page': self.page.number,
                'totalPages': self.page.paginator.num_pages,
            }
        )


class AdminUserListView(APIView):
    """GET /api/v1/admin/users/?search=&status=&kyc=&page=

    `status` — active | blocked
    `kyc` — approved | pending | rejected | not_submitted
    """

    permission_classes = [IsAdminStaff]

    def get(self, request):
        qs = User.objects.all().order_by('-date_joined')

        search = request.query_params.get('search', '').strip()
        if search:
            qs = qs.filter(
                Q(name__icontains=search) | Q(phone__icontains=search) | Q(email__icontains=search)
            )

        status_filter = request.query_params.get('status', '').strip().lower()
        if status_filter == 'active':
            qs = qs.filter(is_active=True)
        elif status_filter == 'blocked':
            qs = qs.filter(is_active=False)

        kyc_filter = request.query_params.get('kyc', '').strip().lower()
        if kyc_filter == 'approved':
            qs = qs.filter(kyc_status__in=[User.KycStatus.VERIFIED, User.KycStatus.COMPLETED])
        elif kyc_filter == 'pending':
            qs = qs.filter(kyc_status__in=[User.KycStatus.PENDING, User.KycStatus.IN_PROGRESS])
        elif kyc_filter == 'rejected':
            qs = qs.filter(kyc_status=User.KycStatus.REJECTED)
        elif kyc_filter == 'not_submitted':
            qs = qs.filter(kyc_status=User.KycStatus.NOT_SUBMITTED)

        paginator = AdminUserPagination()
        page = paginator.paginate_queryset(qs, request)
        data = [serialize_user_list_item(u) for u in page]
        return paginator.get_paginated_response(data)


class AdminUserStatsView(APIView):
    permission_classes = [IsAdminStaff]

    def get(self, request):
        total = User.objects.count()
        active = User.objects.filter(is_active=True).count()
        blocked = User.objects.filter(is_active=False).count()
        pending_kyc = User.objects.filter(
            kyc_status__in=[User.KycStatus.PENDING, User.KycStatus.IN_PROGRESS]
        ).count()
        return Response(
            {
                'totalUsers': total,
                'activeUsers': active,
                'blockedUsers': blocked,
                'pendingKyc': pending_kyc,
            }
        )


class AdminUserDetailView(APIView):
    permission_classes = [IsAdminStaff]

    def get(self, request, user_id):
        user = User.objects.filter(id=user_id).select_related('kyc_profile').first()
        if user is None:
            return Response({'detail': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)
        return Response(serialize_user_detail(user, request=request))


class AdminUserActionView(APIView):
    """POST /api/v1/admin/users/<id>/action/  { "action": "block"|"unblock"|"delete" }"""

    permission_classes = [IsAdminStaff]

    def post(self, request, user_id):
        user = User.objects.filter(id=user_id).first()
        if user is None:
            return Response({'detail': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

        action = (request.data.get('action') or '').strip().lower()

        if action == 'block':
            if user.is_staff or user.is_superuser:
                return Response({'detail': 'Cannot block an admin account.'}, status=status.HTTP_400_BAD_REQUEST)
            user.is_active = False
            user.save(update_fields=['is_active'])
            logger.info('Admin %s blocked user %s', request.user.phone, user.phone)
            return Response(serialize_user_list_item(user))

        if action == 'unblock':
            user.is_active = True
            user.save(update_fields=['is_active'])
            logger.info('Admin %s unblocked user %s', request.user.phone, user.phone)
            return Response(serialize_user_list_item(user))

        if action == 'delete':
            if user.is_staff or user.is_superuser:
                return Response({'detail': 'Cannot delete an admin account.'}, status=status.HTTP_400_BAD_REQUEST)
            phone = user.phone
            user.delete()
            logger.warning('Admin %s deleted user %s', request.user.phone, phone)
            return Response({'detail': 'User deleted.'}, status=status.HTTP_200_OK)

        return Response({'detail': 'Unknown action. Use block, unblock, or delete.'}, status=status.HTTP_400_BAD_REQUEST)


class AdminUserMessageView(APIView):
    """GET  /api/v1/admin/users/<id>/messages/         — messages admin has sent this user
    POST /api/v1/admin/users/<id>/messages/  { "title", "message", "type" }

    Sends through the same `engagement.Notification` model the app's own
    notification bell already reads (`NotificationListView` in
    `engagement/views.py`), so this is a real message the user will see in
    the app — not a separate admin-only log. `type` defaults to "kyc" since
    the main use case is following up on KYC/document issues, but any
    freeform admin note can be sent (`type` "admin" for anything general).
    """

    permission_classes = [IsAdminStaff]
    ALLOWED_TYPES = {'kyc', 'admin', 'general'}

    def get(self, request, user_id):
        from engagement.models import Notification

        user = User.objects.filter(id=user_id).first()
        if user is None:
            return Response({'detail': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

        notifs = Notification.objects.filter(user=user, type__in=self.ALLOWED_TYPES).order_by('-created_at')
        return Response([serialize_admin_notification(n) for n in notifs])

    def post(self, request, user_id):
        from engagement.models import Notification

        user = User.objects.filter(id=user_id).first()
        if user is None:
            return Response({'detail': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

        title = (request.data.get('title') or '').strip()
        message = (request.data.get('message') or '').strip()
        msg_type = (request.data.get('type') or 'kyc').strip().lower()

        if not message:
            return Response({'detail': 'Message text is required.'}, status=status.HTTP_400_BAD_REQUEST)
        if msg_type not in self.ALLOWED_TYPES:
            msg_type = 'admin'
        if not title:
            title = 'KYC Update' if msg_type == 'kyc' else 'Message from Support'

        notif = Notification.objects.create(user=user, title=title, message=message, type=msg_type)
        logger.info('Admin %s sent a %s message to user %s', request.user.phone, msg_type, user.phone)
        return Response(serialize_admin_notification(notif), status=status.HTTP_201_CREATED)


class AdminKycPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = 'pageSize'
    max_page_size = 100

    def get_paginated_response(self, data):
        return Response(
            {
                'results': data,
                'count': self.page.paginator.count,
                'page': self.page.number,
                'totalPages': self.page.paginator.num_pages,
            }
        )


class AdminKycListView(APIView):
    """GET /api/v1/admin/kyc/?search=&status=&page=

    Lists manual PAN KYC submissions (`kyc.KYCRequest`) — the actual
    admin-reviewed verification flow this app uses.
    """

    permission_classes = [IsAdminStaff]

    def get(self, request):
        from kyc.models import KYCRequest

        qs = KYCRequest.objects.select_related('user', 'reviewed_by').order_by('-created_at')

        search = request.query_params.get('search', '').strip()
        if search:
            qs = qs.filter(
                Q(user__name__icontains=search)
                | Q(user__phone__icontains=search)
                | Q(user__email__icontains=search)
                | Q(pan_number__icontains=search)
            )

        status_filter = request.query_params.get('status', '').strip().upper()
        if status_filter in ('PENDING', 'APPROVED', 'REJECTED'):
            qs = qs.filter(status=status_filter)

        paginator = AdminKycPagination()
        page = paginator.paginate_queryset(qs, request)
        data = [serialize_kyc_request(r, request=request) for r in page]
        return paginator.get_paginated_response(data)


class AdminKycStatsView(APIView):
    permission_classes = [IsAdminStaff]

    def get(self, request):
        from kyc.models import KYCRequest

        total = KYCRequest.objects.count()
        pending = KYCRequest.objects.filter(status=KYCRequest.Status.PENDING).count()
        approved = KYCRequest.objects.filter(status=KYCRequest.Status.APPROVED).count()
        rejected = KYCRequest.objects.filter(status=KYCRequest.Status.REJECTED).count()
        return Response(
            {
                'totalRequests': total,
                'pendingRequests': pending,
                'approvedRequests': approved,
                'rejectedRequests': rejected,
            }
        )


class AdminKycActionView(APIView):
    """POST /api/v1/admin/kyc/<id>/action/  { "action": "approve"|"reject", "reason": "..." }

    Reuses the same `kyc.manual_service` functions the rest of the app uses
    for admin review, so approving/rejecting here behaves identically
    (notifies the user, updates `User.kyc_status`/`KycProfile`, etc.) to
    however KYC gets reviewed elsewhere.
    """

    permission_classes = [IsAdminStaff]

    def post(self, request, kyc_id):
        from kyc.manual_service import ManualKycError, approve_kyc_request, reject_kyc_request
        from kyc.models import KYCRequest

        req = KYCRequest.objects.filter(id=kyc_id).first()
        if req is None:
            return Response({'detail': 'KYC request not found.'}, status=status.HTTP_404_NOT_FOUND)

        action = (request.data.get('action') or '').strip().lower()
        try:
            if action == 'approve':
                approve_kyc_request(req, request.user)
            elif action == 'reject':
                reason = request.data.get('reason', '')
                reject_kyc_request(req, request.user, reason)
            else:
                return Response(
                    {'detail': 'Unknown action. Use approve or reject.'}, status=status.HTTP_400_BAD_REQUEST
                )
        except ManualKycError as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        req.refresh_from_db()
        logger.info('Admin %s %sd KYC request %s', request.user.phone, action, req.id)
        return Response(serialize_kyc_request(req, request=request))


class AdminKycMessageView(APIView):
    """POST /api/v1/admin/kyc/<id>/message/  { "message" }

    Convenience wrapper around AdminUserMessageView for the KYC review
    screen — sends the message to the KYC request's user with type "kyc",
    so admins can follow up about a document issue without leaving the KYC
    modal.
    """

    permission_classes = [IsAdminStaff]

    def post(self, request, kyc_id):
        from engagement.models import Notification
        from kyc.models import KYCRequest

        req = KYCRequest.objects.select_related('user').filter(id=kyc_id).first()
        if req is None:
            return Response({'detail': 'KYC request not found.'}, status=status.HTTP_404_NOT_FOUND)

        message = (request.data.get('message') or '').strip()
        if not message:
            return Response({'detail': 'Message text is required.'}, status=status.HTTP_400_BAD_REQUEST)

        notif = Notification.objects.create(
            user=req.user,
            title=request.data.get('title') or 'KYC Update',
            message=message,
            type='kyc',
        )
        logger.info('Admin %s sent a KYC message to user %s (request %s)', request.user.phone, req.user.phone, req.id)
        return Response(serialize_admin_notification(notif), status=status.HTTP_201_CREATED)


class AdminStockTradesView(APIView):
    """GET /api/v1/admin/trades/stocks/?page= — recent paper-trading equity
    fills across all users. Real trading activity, shown as individual
    executions (not synthetic OPEN/CLOSED positions).
    """

    permission_classes = [IsAdminStaff]

    def get(self, request):
        from stocks.models import PaperTrade

        qs = PaperTrade.objects.select_related('user', 'stock').order_by('-created_at')

        search = request.query_params.get('search', '').strip()
        if search:
            qs = qs.filter(
                Q(stock__symbol__icontains=search)
                | Q(user__name__icontains=search)
                | Q(user__email__icontains=search)
            )

        side = request.query_params.get('side', '').strip().upper()
        if side in ('BUY', 'SELL'):
            qs = qs.filter(side=side)

        trade_status = request.query_params.get('status', '').strip().capitalize()
        if trade_status in ('Executed', 'Pending', 'Cancelled'):
            qs = qs.filter(status=trade_status)

        paginator = AdminKycPagination()
        page = paginator.paginate_queryset(qs, request)
        data = [serialize_paper_trade(t) for t in page]
        return paginator.get_paginated_response(data)


class AdminDashboardActivityView(APIView):
    """GET /api/v1/admin/dashboard/activity/ — a real recent-events feed:
    new signups, KYC decisions, and completed deposits, merged and sorted.
    """

    permission_classes = [IsAdminStaff]

    def get(self, request):
        from finance.models import WalletTransaction
        from kyc.models import KYCRequest

        events = []

        for u in User.objects.order_by('-date_joined')[:8]:
            events.append(
                {
                    'id': f'signup-{u.id}',
                    'type': 'user',
                    'title': 'New user registered',
                    'description': f'{u.name or u.phone} created a new account.',
                    'time': u.date_joined,
                }
            )

        for req in KYCRequest.objects.exclude(reviewed_at=None).order_by('-reviewed_at')[:8]:
            approved = req.status == KYCRequest.Status.APPROVED
            events.append(
                {
                    'id': f'kyc-{req.id}',
                    'type': 'success' if approved else 'warning',
                    'title': f'KYC {"Approved" if approved else "Rejected"}',
                    'description': f"{req.user.name or req.user.phone}'s KYC was {'approved' if approved else 'rejected'}.",
                    'time': req.reviewed_at,
                }
            )

        for tx in WalletTransaction.objects.select_related('wallet__user').filter(
            type=WalletTransaction.TxType.DEPOSIT, status=WalletTransaction.Status.COMPLETED
        ).order_by('-created_at')[:8]:
            events.append(
                {
                    'id': f'deposit-{tx.id}',
                    'type': 'payment',
                    'title': 'Deposit received',
                    'description': f'₹{tx.amount} deposited by {tx.wallet.user.name or tx.wallet.user.phone}.',
                    'time': tx.created_at,
                }
            )

        # Returning-user logins — only count a login as its own event when it
        # happened well after signup, so a brand new user's first (automatic)
        # login isn't shown twice alongside "New user registered".
        for u in User.objects.exclude(last_login=None).order_by('-last_login')[:8]:
            if (u.last_login - u.date_joined).total_seconds() > 300:
                events.append(
                    {
                        'id': f'login-{u.id}-{u.last_login.isoformat()}',
                        'type': 'user',
                        'title': 'User logged in',
                        'description': f'{u.name or u.phone} signed back in.',
                        'time': u.last_login,
                    }
                )

        events.sort(key=lambda e: e['time'], reverse=True)
        for e in events:
            e['time'] = _relative_time(e['time'])

        return Response(events[:10])


class AdminDashboardRevenueView(APIView):
    """GET /api/v1/admin/dashboard/revenue/ — total deposits per month for
    the last 12 months.
    """

    permission_classes = [IsAdminStaff]

    def get(self, request):
        from django.db.models import Sum
        from django.db.models.functions import TruncMonth

        from finance.models import WalletTransaction

        rows = (
            WalletTransaction.objects.filter(
                type=WalletTransaction.TxType.DEPOSIT, status=WalletTransaction.Status.COMPLETED
            )
            .annotate(month=TruncMonth('created_at'))
            .values('month')
            .annotate(total=Sum('amount'))
            .order_by('month')[:12]
        )
        return Response([{'month': r['month'].strftime('%b'), 'revenue': float(r['total'])} for r in rows])


def _relative_time(dt) -> str:
    delta = timezone.now() - dt
    seconds = delta.total_seconds()
    if seconds < 60:
        return 'just now'
    if seconds < 3600:
        mins = int(seconds // 60)
        return f'{mins} minute{"s" if mins != 1 else ""} ago'
    if seconds < 86400:
        hours = int(seconds // 3600)
        return f'{hours} hour{"s" if hours != 1 else ""} ago'
    days = int(seconds // 86400)
    return f'{days} day{"s" if days != 1 else ""} ago'


class AdminMeView(APIView):
    """GET /api/v1/admin/me/ — used by the frontend to validate a stored token on load."""

    permission_classes = [IsAdminStaff]

    def get(self, request):
        user = request.user
        return Response(
            {
                'id': str(user.id),
                'name': user.name or user.phone,
                'phone': user.phone,
                'email': user.email,
                'isSuperuser': user.is_superuser,
            }
        )
