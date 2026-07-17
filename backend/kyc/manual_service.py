"""Manual KYC — admin review workflow (replaces Cashfree PAN verification)."""

from datetime import date

from django.db import transaction
from django.utils import timezone

from accounts.models import User

from .models import KYCRequest, KYCRequestImage, KycProfile
from .notifications import (
    notify_admin_new_kyc_request,
    notify_user_kyc_approved,
    notify_user_kyc_rejected,
)


class ManualKycError(Exception):
    pass


from .constants import KYC_WRONG_INFO_REJECTION_REASON


def _normalize_pan(pan: str) -> str:
    return pan.upper().strip().replace(' ', '')


def _validate_pan(pan: str) -> None:
    import re

    if not re.fullmatch(r'[A-Z]{5}[0-9]{4}[A-Z]', pan):
        raise ManualKycError('Invalid PAN format. Example: ABCDE1234F')


def user_kyc_is_verified(user: User) -> bool:
    status = (user.kyc_status or '').lower()
    return status in (User.KycStatus.VERIFIED, User.KycStatus.COMPLETED)


def serialize_request(req: KYCRequest, request=None) -> dict:
    pan_image_url = ''
    if req.pan_image:
        if request is not None:
            pan_image_url = request.build_absolute_uri(req.pan_image.url)
        else:
            pan_image_url = req.pan_image.url

    extra_urls = []
    for img in req.images.all():
        if request is not None:
            extra_urls.append(request.build_absolute_uri(img.image.url))
        else:
            extra_urls.append(img.image.url)

    return {
        'id': str(req.id),
        'pan_number': req.pan_number,
        'full_name': req.full_name,
        'dob': req.dob.isoformat(),
        'pan_image_url': pan_image_url,
        'pan_image_urls': [pan_image_url, *extra_urls] if pan_image_url else extra_urls,
        'status': req.status,
        'rejection_reason': req.rejection_reason,
        'reviewed_at': req.reviewed_at.isoformat() if req.reviewed_at else None,
        'created_at': req.created_at.isoformat(),
        'updated_at': req.updated_at.isoformat(),
    }


def get_kyc_me_payload(user: User, request=None) -> dict:
    latest = user.kyc_requests.order_by('-created_at').first()
    status = user.kyc_status
    if status == User.KycStatus.COMPLETED:
        status = User.KycStatus.VERIFIED
    return {
        'kyc_status': status,
        'latest_request': serialize_request(latest, request) if latest else None,
    }


@transaction.atomic
def submit_kyc_request(
    user: User,
    *,
    pan_number: str,
    full_name: str,
    dob: date,
    pan_images: list,
) -> KYCRequest:
    if not pan_images:
        raise ManualKycError('At least one PAN photo is required.')
    if len(pan_images) > 5:
        raise ManualKycError('You can upload up to 5 photos.')
    if user_kyc_is_verified(user):
        raise ManualKycError('KYC is already verified.')

    pending = user.kyc_requests.filter(status=KYCRequest.Status.PENDING).exists()
    if pending:
        raise ManualKycError('You already have a KYC request under review.')

    pan = _normalize_pan(pan_number)
    _validate_pan(pan)
    name = full_name.strip()
    if len(name) < 2:
        raise ManualKycError('Enter your full name as per PAN.')

    req = KYCRequest.objects.create(
        user=user,
        pan_number=pan,
        full_name=name,
        dob=dob,
        pan_image=pan_images[0],
        status=KYCRequest.Status.PENDING,
    )
    for idx, img in enumerate(pan_images[1:], start=1):
        KYCRequestImage.objects.create(request=req, image=img, sort_order=idx)
    user.kyc_status = User.KycStatus.PENDING
    user.name = name
    user.date_of_birth = dob
    user.pan_status = User.PanStatus.PENDING
    user.save(update_fields=['kyc_status', 'name', 'date_of_birth', 'pan_status'])

    profile, _ = KycProfile.objects.get_or_create(user=user)
    profile.pan_number = pan
    profile.pan_name = name
    profile.overall_status = KycProfile.OverallStatus.PENDING
    profile.save(update_fields=['pan_number', 'pan_name', 'overall_status'])

    req_id = str(req.id)
    image_paths = [getattr(req.pan_image, 'path', '') or '']
    image_paths.extend(
        getattr(img.image, 'path', '') or '' for img in req.images.all()
    )
    image_paths = [p for p in image_paths if p]

    pan_urls = []
    if req.pan_image:
        pan_urls.append(req.pan_image.url)
    pan_urls.extend(img.image.url for img in req.images.all() if img.image)

    user_phone = user.phone
    user_email = user.email or ''
    user_city = user.city or ''
    submitted_at = req.created_at.isoformat()
    transaction.on_commit(
        lambda: notify_admin_new_kyc_request(
            user_phone=user_phone,
            user_email=user_email,
            user_city=user_city,
            pan_number=pan,
            full_name=name,
            dob=dob.isoformat(),
            request_id=req_id,
            pan_image_paths=image_paths,
            pan_image_urls=pan_urls,
            submitted_at=submitted_at,
        )
    )
    return req


@transaction.atomic
def approve_kyc_request(req: KYCRequest, admin_user: User) -> KYCRequest:
    if req.status != KYCRequest.Status.PENDING:
        raise ManualKycError('Only pending requests can be approved.')

    now = timezone.now()
    req.status = KYCRequest.Status.APPROVED
    req.reviewed_by = admin_user
    req.reviewed_at = now
    req.rejection_reason = ''
    req.save(update_fields=['status', 'reviewed_by', 'reviewed_at', 'rejection_reason', 'updated_at'])

    user = req.user
    user.kyc_status = User.KycStatus.VERIFIED
    user.pan_status = User.PanStatus.VERIFIED
    user.save(update_fields=['kyc_status', 'pan_status'])

    profile, _ = KycProfile.objects.get_or_create(user=user)
    profile.pan_number = req.pan_number
    profile.pan_name = req.full_name
    profile.pan_status = KycProfile.VerificationStatus.VERIFIED
    profile.pan_verified_at = now
    profile.overall_status = KycProfile.OverallStatus.VERIFIED
    profile.verified_at = now
    profile.mobile_verified = True
    profile.save()

    user_phone = user.phone
    user_email = user.email or ''
    full_name = req.full_name
    transaction.on_commit(
        lambda: notify_user_kyc_approved(
            user_phone=user_phone,
            full_name=full_name,
            user_email=user_email,
        )
    )
    return req


@transaction.atomic
def reject_kyc_request(req: KYCRequest, admin_user: User, reason: str) -> KYCRequest:
    if req.status != KYCRequest.Status.PENDING:
        raise ManualKycError('Only pending requests can be rejected.')

    reason = (reason or '').strip()
    if len(reason) < 3:
        reason = KYC_WRONG_INFO_REJECTION_REASON

    now = timezone.now()
    req.status = KYCRequest.Status.REJECTED
    req.reviewed_by = admin_user
    req.reviewed_at = now
    req.rejection_reason = reason[:500]
    req.save(update_fields=['status', 'reviewed_by', 'reviewed_at', 'rejection_reason', 'updated_at'])

    user = req.user
    user.kyc_status = User.KycStatus.REJECTED
    user.pan_status = User.PanStatus.REJECTED
    user.save(update_fields=['kyc_status', 'pan_status'])

    profile, _ = KycProfile.objects.get_or_create(user=user)
    profile.overall_status = KycProfile.OverallStatus.REJECTED
    profile.pan_failure_reason = reason[:280]
    profile.save(update_fields=['overall_status', 'pan_failure_reason'])

    user_phone = user.phone
    user_email = user.email or ''
    full_name = req.full_name
    rejection = reason
    transaction.on_commit(
        lambda: notify_user_kyc_rejected(
            user_phone=user_phone,
            full_name=full_name,
            user_email=user_email,
            reason=rejection,
        )
    )
    return req
