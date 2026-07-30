"""Instant KYC API views — typed PAN + DigiLocker Aadhaar, no photo
uploads, no admin review. See kyc/instant_service.py."""

import logging
from datetime import datetime

from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.utils import camelize

from .instant_service import (
    InstantKycError,
    check_aadhaar_verification,
    get_instant_kyc_status,
    start_aadhaar_verification,
    verify_pan_instant,
)

logger = logging.getLogger('bullwave.kyc')


class InstantKycStatusView(APIView):
    """GET /kyc/instant/status/ — current state of the instant flow."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(camelize(get_instant_kyc_status(request.user)))


class InstantPanVerifyView(APIView):
    """POST /kyc/instant/verify-pan/ {panNumber, fullName, dob}"""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        pan_number = (request.data.get('pan_number') or request.data.get('panNumber') or '').strip()
        full_name = (request.data.get('full_name') or request.data.get('fullName') or '').strip()
        dob_raw = request.data.get('dob') or ''

        if not pan_number:
            return Response({'detail': 'Enter your PAN number.'}, status=400)

        try:
            dob = datetime.strptime(str(dob_raw).strip()[:10], '%Y-%m-%d').date()
        except ValueError:
            return Response({'detail': 'Invalid date of birth. Use YYYY-MM-DD.'}, status=400)

        try:
            result = verify_pan_instant(
                request.user, pan_number=pan_number, full_name=full_name, dob=dob,
            )
        except InstantKycError as exc:
            return Response({'detail': str(exc)}, status=400)
        except Exception as exc:
            logger.exception('Instant PAN verify crashed for %s: %s', request.user.phone, exc)
            return Response({'detail': 'Could not verify PAN right now. Please try again.'}, status=500)

        return Response(camelize({'success': True, **result}))


class InstantAadhaarStartView(APIView):
    """POST /kyc/instant/aadhaar/start/ — begins DigiLocker verification,
    returns the URL to open."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        redirect_url = (request.data.get('redirect_url') or request.data.get('redirectUrl') or '').strip()
        try:
            result = start_aadhaar_verification(request.user, redirect_url=redirect_url)
        except InstantKycError as exc:
            return Response({'detail': str(exc)}, status=400)
        except Exception as exc:
            logger.exception('DigiLocker start crashed for %s: %s', request.user.phone, exc)
            return Response({'detail': 'Could not start Aadhaar verification. Please try again.'}, status=500)

        return Response(camelize({'success': True, **result}))


class InstantAadhaarStatusView(APIView):
    """GET /kyc/instant/aadhaar/status/ — poll after the user completes
    (or is still completing) the DigiLocker journey."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        try:
            result = check_aadhaar_verification(request.user)
        except InstantKycError as exc:
            return Response({'detail': str(exc)}, status=400)
        except Exception as exc:
            logger.exception('DigiLocker status check crashed for %s: %s', request.user.phone, exc)
            return Response({'detail': 'Could not check Aadhaar verification status. Please try again.'}, status=500)

        return Response(camelize({'success': True, **result}))
