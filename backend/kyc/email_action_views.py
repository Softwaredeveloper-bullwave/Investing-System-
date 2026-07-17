"""Public HTML endpoints — admin approves/rejects KYC directly from email links."""

import html
import logging
from urllib.parse import unquote

from django.conf import settings
from django.http import HttpResponse
from django.views import View

from accounts.models import User

from .email_tokens import parse_fno_action_token, parse_kyc_action_token
from .constants import FNO_WRONG_INFO_REJECTION_REASON, KYC_WRONG_INFO_REJECTION_REASON
from .manual_service import (
    ManualKycError,
    approve_kyc_request,
    reject_kyc_request,
)
from .models import FnoEligibilityRequest, KYCRequest
from .fno_service import FnoError, approve_fno_request, reject_fno_request

logger = logging.getLogger('bullwave.kyc')


def _get_email_reviewer() -> User:
    """Resolve who recorded the review — prefers KYC_EMAIL_REVIEWER_PHONE when set."""
    reviewer_phone = (getattr(settings, 'KYC_EMAIL_REVIEWER_PHONE', '') or '').strip()

    if reviewer_phone:
        user = User.objects.filter(phone=reviewer_phone).first()
        if user:
            if not user.is_staff or not user.is_superuser:
                user.is_staff = True
                user.is_superuser = True
                user.save(update_fields=['is_staff', 'is_superuser'])
            return user
        user, created = User.objects.get_or_create(
            phone=reviewer_phone,
            defaults={
                'name': 'KYC Admin',
                'is_staff': True,
                'is_superuser': True,
            },
        )
        if created:
            user.set_unusable_password()
            user.save(update_fields=['password'])
            logger.info('Created KYC email reviewer account (phone=%s)', reviewer_phone)
        elif not user.is_staff or not user.is_superuser:
            user.is_staff = True
            user.is_superuser = True
            user.save(update_fields=['is_staff', 'is_superuser'])
        return user

    admin = User.objects.filter(is_superuser=True).order_by('date_joined').first()
    if admin:
        return admin
    admin = User.objects.filter(is_staff=True).order_by('date_joined').first()
    if admin:
        return admin

    system_phone = '9000000001'
    user, created = User.objects.get_or_create(
        phone=system_phone,
        defaults={
            'name': 'KYC Email Reviewer',
            'is_staff': True,
            'is_superuser': True,
        },
    )
    if created:
        user.set_unusable_password()
        user.save(update_fields=['password'])
        logger.info('Created KYC email reviewer account (phone=%s)', system_phone)
    elif not user.is_staff or not user.is_superuser:
        user.is_staff = True
        user.is_superuser = True
        user.save(update_fields=['is_staff', 'is_superuser'])
    return user


def _parse_token(raw: str) -> str:
    return unquote((raw or '').strip())


def _render_page(*, title: str, message: str, success: bool) -> str:
    accent = '#16a34a' if success else '#dc2626'
    icon = '✓' if success else '!'
    safe_title = html.escape(title)
    safe_message = html.escape(message)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>{safe_title} — BullWave</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
           background: #0f172a; color: #e2e8f0; margin: 0; padding: 32px 16px; }}
    .card {{ max-width: 520px; margin: 0 auto; background: #1e293b; border-radius: 16px;
             padding: 32px; border: 1px solid #334155; text-align: center; }}
    .badge {{ width: 64px; height: 64px; border-radius: 50%; background: {accent}22;
              color: {accent}; font-size: 28px; line-height: 64px; margin: 0 auto 20px; }}
    h1 {{ margin: 0 0 12px; font-size: 22px; }}
    p {{ margin: 0; color: #94a3b8; line-height: 1.6; }}
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">{icon}</div>
    <h1>{safe_title}</h1>
    <p>{safe_message}</p>
  </div>
</body>
</html>"""


def _html_response(*, title: str, message: str, success: bool, status: int = 200) -> HttpResponse:
    return HttpResponse(
        _render_page(title=title, message=message, success=success),
        content_type='text/html; charset=utf-8',
        status=status,
    )


class KycEmailApproveView(View):
    """GET /api/v1/kyc/review/approve/?token=..."""

    def get(self, request):
        token = _parse_token(request.GET.get('token', ''))
        try:
            request_id, action = parse_kyc_action_token(token)
            if action != 'approve':
                raise ValueError('This link is for rejection, not approval.')
            req = KYCRequest.objects.select_related('user').get(pk=request_id)
        except KYCRequest.DoesNotExist:
            return _html_response(
                title='Request not found',
                message='This KYC request no longer exists.',
                success=False,
                status=404,
            )
        except ValueError as exc:
            return _html_response(title='Invalid link', message=str(exc), success=False, status=400)

        if req.status == KYCRequest.Status.APPROVED:
            return _html_response(
                title='Already approved',
                message=f'KYC for {req.user.phone} was already approved. The user can access the app.',
                success=True,
            )
        if req.status == KYCRequest.Status.REJECTED:
            return _html_response(
                title='Cannot approve',
                message='This request was already rejected. The user must resubmit KYC.',
                success=False,
                status=409,
            )

        try:
            reviewer = _get_email_reviewer()
            approve_kyc_request(req, reviewer)
        except ManualKycError as exc:
            return _html_response(title='Approval failed', message=str(exc), success=False, status=400)
        except Exception:
            logger.exception('Email approve failed for request %s', request_id)
            return _html_response(
                title='Something went wrong',
                message='Could not approve this request. Try Django admin.',
                success=False,
                status=500,
            )

        return _html_response(
            title='KYC approved',
            message=(
                f'{req.full_name} ({req.user.phone}) is verified. '
                f'They have been notified and can access the BullWave app.'
            ),
            success=True,
        )


class KycEmailRejectView(View):
    """GET /api/v1/kyc/review/reject/?token=..."""

    def get(self, request):
        token = _parse_token(request.GET.get('token', ''))
        try:
            request_id, action = parse_kyc_action_token(token)
            if action != 'reject':
                raise ValueError('This link is for approval, not rejection.')
            req = KYCRequest.objects.select_related('user').get(pk=request_id)
        except KYCRequest.DoesNotExist:
            return _html_response(
                title='Request not found',
                message='This KYC request no longer exists.',
                success=False,
                status=404,
            )
        except ValueError as exc:
            return _html_response(title='Invalid link', message=str(exc), success=False, status=400)

        if req.status == KYCRequest.Status.REJECTED:
            return _html_response(
                title='Already rejected',
                message='This KYC request was already rejected. The user has been notified.',
                success=True,
            )
        if req.status == KYCRequest.Status.APPROVED:
            return _html_response(
                title='Cannot reject',
                message='This request was already approved.',
                success=False,
                status=409,
            )

        try:
            reviewer = _get_email_reviewer()
            reject_kyc_request(req, reviewer, KYC_WRONG_INFO_REJECTION_REASON)
        except ManualKycError as exc:
            return _html_response(title='Rejection failed', message=str(exc), success=False, status=400)
        except Exception:
            logger.exception('Email reject failed for request %s', request_id)
            return _html_response(
                title='Something went wrong',
                message='Could not reject this request. Try Django admin.',
                success=False,
                status=500,
            )

        return _html_response(
            title='KYC rejected',
            message=(
                f'{req.full_name} ({req.user.phone}) was rejected due to wrong information. '
                f'They can resubmit KYC from the app.'
            ),
            success=True,
        )


class FnoEmailApproveView(View):
    """GET /api/v1/fno/review/approve/?token=..."""

    def get(self, request):
        token = _parse_token(request.GET.get('token', ''))
        try:
            request_id, action = parse_fno_action_token(token)
            if action != 'approve':
                raise ValueError('This link is for rejection, not approval.')
            req = FnoEligibilityRequest.objects.select_related('user').get(pk=request_id)
        except FnoEligibilityRequest.DoesNotExist:
            return _html_response(
                title='Request not found',
                message='This F&O request no longer exists.',
                success=False,
                status=404,
            )
        except ValueError as exc:
            return _html_response(title='Invalid link', message=str(exc), success=False, status=400)

        if req.status == FnoEligibilityRequest.Status.APPROVED:
            return _html_response(
                title='Already approved',
                message=f'F&O access for {req.user.phone} was already approved.',
                success=True,
            )
        if req.status == FnoEligibilityRequest.Status.REJECTED:
            return _html_response(
                title='Cannot approve',
                message='This request was already rejected. The user must submit another proof.',
                success=False,
                status=409,
            )

        try:
            reviewer = _get_email_reviewer()
            approve_fno_request(req, reviewer)
        except FnoError as exc:
            return _html_response(title='Approval failed', message=str(exc), success=False, status=400)
        except Exception:
            logger.exception('F&O email approve failed for request %s', request_id)
            return _html_response(
                title='Something went wrong',
                message='Could not approve this F&O request. Try Django admin.',
                success=False,
                status=500,
            )

        return _html_response(
            title='F&O approved',
            message=(
                f'{req.user.name or req.user.phone} ({req.user.phone}) can now trade '
                f'Futures & Options. They have been notified.'
            ),
            success=True,
        )


class FnoEmailRejectView(View):
    """GET /api/v1/fno/review/reject/?token=..."""

    def get(self, request):
        token = _parse_token(request.GET.get('token', ''))
        try:
            request_id, action = parse_fno_action_token(token)
            if action != 'reject':
                raise ValueError('This link is for approval, not rejection.')
            req = FnoEligibilityRequest.objects.select_related('user').get(pk=request_id)
        except FnoEligibilityRequest.DoesNotExist:
            return _html_response(
                title='Request not found',
                message='This F&O request no longer exists.',
                success=False,
                status=404,
            )
        except ValueError as exc:
            return _html_response(title='Invalid link', message=str(exc), success=False, status=400)

        if req.status == FnoEligibilityRequest.Status.REJECTED:
            return _html_response(
                title='Already rejected',
                message='This F&O request was already rejected. The user has been notified.',
                success=True,
            )
        if req.status == FnoEligibilityRequest.Status.APPROVED:
            return _html_response(
                title='Cannot reject',
                message='This request was already approved.',
                success=False,
                status=409,
            )

        try:
            reviewer = _get_email_reviewer()
            reject_fno_request(req, reviewer, FNO_WRONG_INFO_REJECTION_REASON)
        except FnoError as exc:
            return _html_response(title='Rejection failed', message=str(exc), success=False, status=400)
        except Exception:
            logger.exception('F&O email reject failed for request %s', request_id)
            return _html_response(
                title='Something went wrong',
                message='Could not reject this F&O request. Try Django admin.',
                success=False,
                status=500,
            )

        return _html_response(
            title='F&O rejected',
            message=(
                f'{req.user.name or req.user.phone} ({req.user.phone}) was rejected. '
                f'They can choose another proof option in the app.'
            ),
            success=True,
        )
