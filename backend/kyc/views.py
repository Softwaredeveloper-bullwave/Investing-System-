import logging

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.views import SendOTPView, VerifyOTPView
from services.providers.cashfree_secure_id import CashfreeSecureIdError

from .rate_limit import RateLimitExceeded, check_rate_limit
from .serializers import VerifyBankSerializer, VerifyPanSerializer
from .service import (
    build_status_payload,
    get_or_create_profile,
    name_match_step,
    verify_bank_step,
    verify_pan_step,
)

logger = logging.getLogger('bullwave.kyc')


class SendOtpAliasView(SendOTPView):
    """Alias: POST /api/v1/send-otp/"""


class VerifyOtpAliasView(VerifyOTPView):
    """Alias: POST /api/v1/verify-otp/"""


class VerifyPanView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:pan:{request.user.id}', limit=5, window_seconds=300)
        except RateLimitExceeded as exc:
            return Response({'detail': str(exc)}, status=429)

        serializer = VerifyPanSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            profile = verify_pan_step(
                request.user,
                data['pan_number'],
                data.get('holder_name', ''),
            )
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)
        except CashfreeSecureIdError as exc:
            return Response({'detail': str(exc), 'code': exc.code}, status=400)

        payload = build_status_payload(profile)
        response = {
            **payload,
            'success': True,
            'message': 'PAN verified successfully.',
        }
        if (profile.pan_reference_id or '').startswith('sandbox-'):
            response['devBypass'] = True
            response['message'] = (
                'PAN accepted in sandbox dev mode. Real PAN verification requires '
                'Cashfree production keys (CASHFREE_ENV=production).'
            )
        return Response(response)


class VerifyBankView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:bank:{request.user.id}', limit=5, window_seconds=300)
        except RateLimitExceeded as exc:
            return Response({'detail': str(exc)}, status=429)

        serializer = VerifyBankSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            profile = verify_bank_step(request.user, **data)
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)
        except CashfreeSecureIdError as exc:
            return Response({'detail': str(exc), 'code': exc.code}, status=400)

        payload = build_status_payload(profile)
        return Response(
            {
                **payload,
                'success': True,
                'message': 'Bank account verified successfully.',
            }
        )


class NameMatchView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            check_rate_limit(f'kyc:match:{request.user.id}', limit=10, window_seconds=300)
        except RateLimitExceeded as exc:
            return Response({'detail': str(exc)}, status=429)

        try:
            profile = name_match_step(request.user)
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)

        payload = build_status_payload(profile)
        if not profile.name_match_passed:
            return Response(
                {
                    **payload,
                    'success': False,
                    'message': 'Name on PAN does not match bank account holder name.',
                },
                status=400,
            )

        return Response(
            {
                **payload,
                'success': True,
                'message': 'Name match verified.',
            }
        )


class KycStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = get_or_create_profile(request.user)
        return Response(build_status_payload(profile))
