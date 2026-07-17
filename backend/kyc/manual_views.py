"""Manual KYC API views — user submit/me and admin review."""

import logging
from datetime import datetime

from rest_framework import status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from core.utils import camelize

from .manual_service import (
    ManualKycError,
    approve_kyc_request,
    get_kyc_me_payload,
    reject_kyc_request,
    serialize_request,
    submit_kyc_request,
)
from .models import KYCRequest

logger = logging.getLogger('bullwave.kyc')


class KycSubmitView(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        pan_number = request.data.get('pan_number') or request.data.get('panNumber') or ''
        full_name = request.data.get('full_name') or request.data.get('fullName') or ''
        dob_raw = request.data.get('dob') or ''
        pan_images = list(request.FILES.getlist('pan_image') or request.FILES.getlist('panImage'))
        if not pan_images:
            single = request.FILES.get('pan_image') or request.FILES.get('panImage')
            if single:
                pan_images = [single]

        if not pan_images:
            return Response({'detail': 'At least one PAN photo is required.'}, status=400)
        try:
            dob = datetime.strptime(str(dob_raw).strip()[:10], '%Y-%m-%d').date()
        except ValueError:
            return Response({'detail': 'Invalid date of birth. Use YYYY-MM-DD.'}, status=400)

        try:
            req = submit_kyc_request(
                request.user,
                pan_number=pan_number,
                full_name=full_name,
                dob=dob,
                pan_images=pan_images,
            )
        except ManualKycError as exc:
            return Response({'detail': str(exc)}, status=400)
        except Exception as exc:
            logger.exception('KYC submit failed: %s', exc)
            return Response({'detail': 'Could not save KYC. Try again.'}, status=500)

        return Response(
            camelize({
                'success': True,
                'message': 'KYC submitted successfully. Verification is under review.',
                'request': serialize_request(req, request),
                **get_kyc_me_payload(request.user, request),
            }),
            status=status.HTTP_201_CREATED,
        )


class KycMeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(camelize(get_kyc_me_payload(request.user, request)))


class AdminKycPendingListView(APIView):
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request):
        rows = (
            KYCRequest.objects.filter(status=KYCRequest.Status.PENDING)
            .select_related('user')
            .order_by('created_at')
        )
        data = [
            {
                'id': str(r.id),
                'user_id': str(r.user_id),
                'user_phone': r.user.phone,
                'user_name': r.user.name,
                'pan_number': r.pan_number,
                'full_name': r.full_name,
                'dob': r.dob.isoformat(),
                'pan_image_url': request.build_absolute_uri(r.pan_image.url) if r.pan_image else '',
                'status': r.status,
                'created_at': r.created_at.isoformat(),
            }
            for r in rows
        ]
        return Response(camelize({'results': data, 'count': len(data)}))


class AdminKycDetailView(APIView):
    permission_classes = [IsAuthenticated, IsAdminUser]

    def get(self, request, pk):
        try:
            req = KYCRequest.objects.select_related('user', 'reviewed_by').get(pk=pk)
        except KYCRequest.DoesNotExist:
            return Response({'detail': 'KYC request not found.'}, status=404)

        data = serialize_request(req, request)
        data['user'] = {
            'id': str(req.user_id),
            'phone': req.user.phone,
            'name': req.user.name,
            'email': req.user.email,
            'kyc_status': req.user.kyc_status,
        }
        if req.reviewed_by:
            data['reviewed_by'] = req.reviewed_by.phone
        return Response(camelize(data))


class AdminKycApproveView(APIView):
    permission_classes = [IsAuthenticated, IsAdminUser]

    def post(self, request, pk):
        try:
            req = KYCRequest.objects.get(pk=pk)
        except KYCRequest.DoesNotExist:
            return Response({'detail': 'KYC request not found.'}, status=404)
        try:
            req = approve_kyc_request(req, request.user)
        except ManualKycError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(
            camelize({
                'success': True,
                'message': 'KYC approved.',
                'request': serialize_request(req, request),
            })
        )


class AdminKycRejectView(APIView):
    permission_classes = [IsAuthenticated, IsAdminUser]

    def post(self, request, pk):
        reason = request.data.get('rejection_reason') or request.data.get('rejectionReason') or ''
        try:
            req = KYCRequest.objects.get(pk=pk)
        except KYCRequest.DoesNotExist:
            return Response({'detail': 'KYC request not found.'}, status=404)
        try:
            req = reject_kyc_request(req, request.user, reason)
        except ManualKycError as exc:
            return Response({'detail': str(exc)}, status=400)
        return Response(
            camelize({
                'success': True,
                'message': 'KYC rejected.',
                'request': serialize_request(req, request),
            })
        )
