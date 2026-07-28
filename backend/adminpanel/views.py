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
from .serializers import AdminLoginSerializer, serialize_user_detail, serialize_user_list_item

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
