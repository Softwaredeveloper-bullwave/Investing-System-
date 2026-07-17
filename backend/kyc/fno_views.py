"""F&O eligibility API — proof upload or portfolio holding check."""

import logging

from rest_framework import status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.utils import camelize

from .models import FnoEligibilityRequest
from .fno_service import FnoError, get_fno_me_payload, submit_fno_eligibility

logger = logging.getLogger('bullwave.kyc')


class FnoMeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(camelize(get_fno_me_payload(request.user, request)))


class FnoSubmitView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        proof_type = (
            request.data.get('proof_type')
            or request.data.get('proofType')
            or ''
        )
        document = request.FILES.get('document')

        try:
            req = submit_fno_eligibility(
                request.user,
                proof_type=proof_type,
                document=document,
            )
        except FnoError as exc:
            return Response({'detail': str(exc)}, status=400)
        except Exception as exc:
            logger.exception('F&O submit failed: %s', exc)
            return Response({'detail': 'Could not submit F&O verification.'}, status=500)

        payload = get_fno_me_payload(request.user, request)
        if req.status == FnoEligibilityRequest.Status.APPROVED:
            message = 'F&O access enabled. You can now trade futures and options.'
            code = status.HTTP_200_OK
        else:
            message = 'F&O verification submitted. Admin will review your document via email shortly.'
            code = status.HTTP_201_CREATED

        return Response(
            camelize({
                'success': True,
                'message': message,
                'request': payload.get('latest_request'),
                **payload,
            }),
            status=code,
        )
