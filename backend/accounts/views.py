from __future__ import annotations

import logging
import random
from datetime import timedelta

from django.conf import settings
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from core.integrations.bank_service import BankValidationError, validate_account_number, validate_ifsc
from core.integrations.cashfree_service import CashfreeError, is_configured as cashfree_configured
from core.integrations.cashfree_bypass import verify_bank_with_bypass, verify_pan_with_bypass
from core.integrations.email_service import EmailError, send_email_otp
from core.integrations.sms_service import (
    SMSError,
    check_otp_twilio_verify,
    is_live_sms,
    send_otp_sms,
    send_otp_sms_fallback,
    uses_twilio_verify,
)
from kyc.service import get_or_create_profile

from core.serializers import CamelCaseSerializer
from .models import BankAccount, EmailOTPVerification, KycDocument, OTPVerification, User
from .otp_utils import normalize_otp, normalize_phone
from .serializers import (
    BankAccountSerializer,
    CompleteProfileSerializer,
    KycDocumentSerializer,
    KycStatusSerializer,
    ProfileUpdateSerializer,
    UserSerializer,
)

logger = logging.getLogger('bullwave.accounts')

DEV_AUTH_PHONE = '9999999999'


def _issue_auth_tokens(user, request, *, created=False):
    # Record the login so it's reflected in the admin panel (Users list
    # "last login" column, Recent Activity feed) even for returning users
    # who already existed before this login.
    user.last_login = timezone.now()
    user.save(update_fields=['last_login'])

    refresh = RefreshToken.for_user(user)
    return Response(
        {
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'user': UserSerializer(user, context={'request': request}).data,
            'isNewUser': created,
        }
    )


def _mask_email(email: str) -> str:
    if not email or '@' not in email:
        return email
    local, domain = email.split('@', 1)
    if len(local) <= 2:
        masked_local = local[0] + '*' * max(len(local) - 1, 1)
    else:
        masked_local = local[0] + '*' * (len(local) - 2) + local[-1]
    return f'{masked_local}@{domain}'


def _send_login_email_otp(user, *, created=False):
    """Generates + sends the email second-factor OTP and returns a Response
    describing the pending step (no JWTs yet — those are only issued once
    `VerifyEmailOTPView` confirms this code). Raises EmailError if Brevo
    itself fails so the caller can decide how to degrade."""
    otp = f'{random.randint(100000, 999999):06d}'
    expires_at = timezone.now() + timedelta(minutes=settings.EMAIL_OTP_EXPIRY_MINUTES)
    EmailOTPVerification.objects.filter(user=user, is_used=False).update(is_used=True)
    EmailOTPVerification.objects.create(
        user=user, otp_code=otp, expires_at=expires_at, is_new_user=created,
    )
    live = send_email_otp(user.email, user.name, otp)
    payload = {
        'requiresEmailOtp': True,
        'message': 'Enter the verification code sent to your email.',
        'phone': user.phone,
        'maskedEmail': _mask_email(user.email),
        'emailOtpMode': 'email' if live else 'console',
    }
    if settings.DEBUG and not live:
        payload['devEmailOtp'] = otp
    return Response(payload)


def _ensure_user_bootstrap(user, *, created=False):
    get_or_create_profile(user)
    if created:
        from finance.models import Wallet
        from engagement.models import Notification

        Wallet.objects.create(user=user)
        Notification.objects.create(
            user=user,
            title='Welcome to BullWave',
            message='Complete your KYC to start investing.',
            type='general',
        )


class SendOTPView(APIView):
    permission_classes = [AllowAny]

    def _issue_local_otp(self, phone: str) -> str:
        otp = f'{random.randint(100000, 999999):06d}'
        expires_at = timezone.now() + timedelta(minutes=settings.OTP_EXPIRY_MINUTES)
        OTPVerification.objects.filter(phone=phone, is_used=False).update(is_used=True)
        OTPVerification.objects.create(phone=phone, otp_code=otp, expires_at=expires_at)
        return otp

    def post(self, request):
        phone = normalize_phone(request.data.get('phone', ''))
        if not phone:
            return Response({'detail': 'Enter a valid 10-digit phone number.'}, status=400)

        live = is_live_sms()

        if uses_twilio_verify():
            try:
                send_otp_sms(phone, '')
                return Response(
                    {
                        'success': True,
                        'message': 'OTP sent successfully.',
                        'otpMode': 'sms',
                    }
                )
            except SMSError as exc:
                # Verify itself failed to send (trial-account restriction, bad
                # number, misconfigured service, Twilio outage, etc). Don't
                # dead-end the user — fall back to a locally-generated OTP
                # delivered through a different channel instead of a hard 503.
                logger.error(
                    'Twilio Verify failed for %s: %s — falling back to local OTP delivery.',
                    phone,
                    exc,
                )
                otp = self._issue_local_otp(phone)
                try:
                    fallback_live = send_otp_sms_fallback(phone, otp)
                except SMSError as fallback_exc:
                    logger.error('Fallback SMS also failed for %s: %s', phone, fallback_exc)
                    return Response(
                        {'detail': 'Could not send OTP right now. Please try again shortly.'},
                        status=503,
                    )
                if not fallback_live:
                    logger.warning(
                        'OTP for %s only logged to console (no TWILIO_FROM_NUMBER configured) — '
                        'it was NOT actually sent to the phone.',
                        phone,
                    )
                payload = {
                    'success': True,
                    'message': 'OTP sent successfully.',
                    'otpMode': 'sms' if fallback_live else 'console',
                }
                if settings.DEBUG and not fallback_live:
                    payload['devOtp'] = otp
                return Response(payload)

        otp = self._issue_local_otp(phone)

        try:
            send_otp_sms(phone, otp)
        except SMSError as exc:
            logger.error('SMS OTP failed for %s: %s', phone, exc)
            return Response({'detail': str(exc)}, status=503)

        payload = {
            'success': True,
            'message': 'OTP sent successfully.',
            'otpMode': 'sms' if live else 'console',
        }
        # DEBUG dev phone — expose OTP so Flutter dev mode can auto-login without Twilio.
        if settings.DEBUG and phone == DEV_AUTH_PHONE:
            payload['devOtp'] = otp
            payload['otpMode'] = 'console'
        elif not live and settings.DEBUG:
            payload['devOtp'] = otp
        return Response(payload)


class VerifyOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        phone = normalize_phone(request.data.get('phone', ''))
        otp = normalize_otp(request.data.get('otp', ''))

        if not phone:
            return Response({'detail': 'Enter a valid 10-digit phone number.'}, status=400)
        if len(otp) != 6:
            return Response({'detail': 'Enter the 6-digit OTP.'}, status=400)

        if uses_twilio_verify():
            # If SendOTPView fell back to a locally-generated OTP (because the
            # Verify API call itself failed), there's a pending local record
            # for this phone — check that instead of asking Twilio Verify
            # about a verification it never created.
            local_pending = (
                OTPVerification.objects.filter(
                    phone=phone, is_used=False, expires_at__gte=timezone.now()
                )
                .order_by('-created_at')
                .first()
            )
            if local_pending is not None:
                if local_pending.otp_code != otp:
                    return Response({'detail': 'Incorrect OTP. Please check and try again.'}, status=400)
                local_pending.is_used = True
                local_pending.save(update_fields=['is_used'])
            else:
                try:
                    approved = check_otp_twilio_verify(phone, otp)
                except SMSError as exc:
                    # Twilio Verify throws a raw API error (e.g. 20404
                    # "VerificationCheck was not found") once a code has
                    # expired or was already checked — that's expected
                    # Twilio Verify behavior, not a real server bug, so log
                    # the technical detail server-side (visible in the admin
                    # panel's Logs page) but never surface raw provider JSON
                    # to the user — it read as a crash, not "try again".
                    logger.warning(
                        'Twilio Verify check failed for %s (likely expired/already-used code): %s',
                        phone,
                        exc,
                    )
                    return Response(
                        {'detail': 'This code has expired or was already used. Tap Resend OTP to get a new code.'},
                        status=400,
                    )
                if not approved:
                    return Response({'detail': 'Incorrect OTP. Please check and try again.'}, status=400)
        else:
            now = timezone.now()
            latest = (
                OTPVerification.objects.filter(phone=phone, is_used=False, expires_at__gte=now)
                .order_by('-created_at')
                .first()
            )

            if not latest:
                return Response(
                    {'detail': 'OTP expired. Tap Resend OTP to get a new code.'},
                    status=400,
                )

            if latest.otp_code != otp:
                return Response({'detail': 'Incorrect OTP. Please check and try again.'}, status=400)

            latest.is_used = True
            latest.save(update_fields=['is_used'])

        user, created = User.objects.get_or_create(phone=phone)
        _ensure_user_bootstrap(user, created=created)

        # True two-factor: if this account has an email on file, a second
        # OTP goes there and login isn't complete (no JWTs issued) until
        # `VerifyEmailOTPView` confirms it. Accounts with no email yet
        # (e.g. a brand new signup that hasn't completed their profile)
        # can't be sent a code, so they fall back to phone-only login —
        # same behavior as before this feature existed.
        if user.email:
            try:
                return _send_login_email_otp(user, created=created)
            except EmailError as exc:
                logger.error(
                    'Email OTP send failed for %s (%s): %s — falling back to phone-only login.',
                    user.phone,
                    user.email,
                    exc,
                )
                return _issue_auth_tokens(user, request, created=created)

        return _issue_auth_tokens(user, request, created=created)


class VerifyEmailOTPView(APIView):
    """Step 2 of login for accounts with an email on file — verifies the
    code `VerifyOTPView` sent via Brevo and only then issues JWTs.
    """

    permission_classes = [AllowAny]

    def post(self, request):
        phone = normalize_phone(request.data.get('phone', ''))
        otp = normalize_otp(request.data.get('otp', ''))

        if not phone:
            return Response({'detail': 'Enter a valid 10-digit phone number.'}, status=400)
        if len(otp) != 6:
            return Response({'detail': 'Enter the 6-digit code sent to your email.'}, status=400)

        user = User.objects.filter(phone=phone).first()
        if user is None or not user.email:
            return Response({'detail': 'No pending email verification for this account.'}, status=400)

        pending = (
            EmailOTPVerification.objects.filter(user=user, is_used=False, expires_at__gte=timezone.now())
            .order_by('-created_at')
            .first()
        )
        if pending is None:
            return Response({'detail': 'Code expired. Tap Resend to get a new one.'}, status=400)
        if pending.otp_code != otp:
            return Response({'detail': 'Incorrect code. Please check and try again.'}, status=400)

        pending.is_used = True
        pending.save(update_fields=['is_used'])

        return _issue_auth_tokens(user, request, created=pending.is_new_user)


class ResendEmailOTPView(APIView):
    """POST /auth/resend-email-otp/ { "phone": "..." } — re-sends the email
    second-factor code for an account already mid-login (i.e. that already
    passed phone-OTP verification in this attempt).
    """

    permission_classes = [AllowAny]

    def post(self, request):
        phone = normalize_phone(request.data.get('phone', ''))
        if not phone:
            return Response({'detail': 'Enter a valid 10-digit phone number.'}, status=400)

        user = User.objects.filter(phone=phone).first()
        if user is None or not user.email:
            return Response({'detail': 'No pending email verification for this account.'}, status=400)

        # Carry the same is_new_user flag forward from whatever the most
        # recent pending/used code had, so a resend doesn't lose track of
        # whether this login is for a brand-new account.
        last = EmailOTPVerification.objects.filter(user=user).order_by('-created_at').first()
        created = bool(last and last.is_new_user)

        try:
            return _send_login_email_otp(user, created=created)
        except EmailError as exc:
            logger.error('Resend email OTP failed for %s (%s): %s', user.phone, user.email, exc)
            return Response({'detail': 'Could not send the code right now. Please try again shortly.'}, status=503)


class DevLoginView(APIView):
    """DEBUG-only instant JWT for Flutter dev mode (no OTP / Twilio required).

    TEMPORARY (requested for testing, 2026-07-18): accepts ANY phone number,
    not just DEV_AUTH_PHONE, so the login screen can skip the OTP step for
    whatever number the user types while testing. Still hard-gated behind
    `settings.DEBUG` — impossible to hit in a production deployment either
    way. To restore the original "test phone only" restriction, put back:
        if phone != DEV_AUTH_PHONE:
            return Response({'detail': 'Dev login is limited to the test phone number.'}, status=400)
    """

    permission_classes = [AllowAny]

    def post(self, request):
        if not settings.DEBUG:
            return Response({'detail': 'Not available.'}, status=status.HTTP_404_NOT_FOUND)

        phone = normalize_phone(request.data.get('phone', DEV_AUTH_PHONE))
        if len(phone) != 10 or not phone.isdigit():
            return Response({'detail': 'Enter a valid 10-digit phone number.'}, status=400)

        user, created = User.objects.get_or_create(phone=phone)
        _ensure_user_bootstrap(user, created=created)
        logger.info('Dev login issued JWT for %s (OTP skipped for testing)', phone)
        return _issue_auth_tokens(user, request, created=created)


class ProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user, context={'request': request}).data)

    def patch(self, request):
        serializer = ProfileUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = request.user
        for field, value in serializer.validated_data.items():
            setattr(user, field, value)
        user.save()
        return Response(UserSerializer(user, context={'request': request}).data)


class CompleteProfileView(APIView):
    """First-time profile setup after OTP — unlocks markets and stock data."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = CompleteProfileSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = request.user

        referral_code = serializer.validated_data.pop('referral_code', '')
        profile_fields = serializer.validated_data

        for field, value in profile_fields.items():
            setattr(user, field, value)
        user.has_completed_onboarding = True
        user.save()

        if referral_code and not user.referred_by_id:
            from engagement.referral_service import apply_referral_code

            apply_referral_code(user, referral_code)

        from engagement.referral_service import credit_referral_reward

        credit_referral_reward(user)

        return Response(UserSerializer(user, context={'request': request}).data)


class ProfileAvatarView(APIView):
    permission_classes = [IsAuthenticated]

    _ALLOWED_TYPES = frozenset({'image/jpeg', 'image/png', 'image/webp', 'image/jpg'})

    @staticmethod
    def _detect_image_type(uploaded_file) -> str | None:
        content_type = (getattr(uploaded_file, 'content_type', '') or '').split(';')[0].strip().lower()
        if content_type in ProfileAvatarView._ALLOWED_TYPES:
            return content_type

        import mimetypes

        name = getattr(uploaded_file, 'name', '') or ''
        guessed, _ = mimetypes.guess_type(name)
        if guessed in ProfileAvatarView._ALLOWED_TYPES:
            return guessed

        if content_type not in ('', 'application/octet-stream', 'binary/octet-stream'):
            return None

        try:
            head = uploaded_file.read(16)
            uploaded_file.seek(0)
        except Exception:
            return None

        if head.startswith(b'\xff\xd8\xff'):
            return 'image/jpeg'
        if head.startswith(b'\x89PNG\r\n\x1a\n'):
            return 'image/png'
        if len(head) >= 12 and head[:4] == b'RIFF' and head[8:12] == b'WEBP':
            return 'image/webp'
        return None

    def post(self, request):
        avatar = request.FILES.get('avatar')
        if not avatar:
            return Response({'detail': 'No image file provided.'}, status=400)

        if not self._detect_image_type(avatar):
            return Response({'detail': 'Use JPEG, PNG, or WebP image.'}, status=400)

        if avatar.size > 5 * 1024 * 1024:
            return Response({'detail': 'Image must be under 5 MB.'}, status=400)

        user = request.user
        if user.avatar:
            user.avatar.delete(save=False)
        user.avatar = avatar
        user.avatar_url = ''
        user.save()
        return Response(UserSerializer(user, context={'request': request}).data)

    def delete(self, request):
        user = request.user
        if user.avatar:
            user.avatar.delete(save=False)
        user.avatar = None
        user.avatar_url = ''
        user.save(update_fields=['avatar', 'avatar_url'])
        return Response(UserSerializer(user, context={'request': request}).data)


class BankAccountView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        account = getattr(request.user, 'bank_account', None)
        if not account:
            return Response({'detail': 'Bank account not found.'}, status=404)
        return Response(BankAccountSerializer(account).data)

    def post(self, request):
        serializer = BankAccountSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        account, _ = BankAccount.objects.update_or_create(
            user=request.user,
            defaults={
                **serializer.validated_data,
                'is_verified': False,
                'verification_status': 'pending',
                'verification_provider': '',
                'verification_reference_id': '',
                'verification_message': '',
                'name_at_bank': '',
                'name_match_result': '',
                'pan_registered_name': '',
                'verified_at': None,
            },
        )
        return Response(BankAccountSerializer(account).data, status=201)


class BankVerifyView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        account = getattr(request.user, 'bank_account', None)
        if not account:
            return Response({'detail': 'Add bank details first.'}, status=400)

        try:
            ifsc_data = validate_ifsc(account.ifsc)
            validate_account_number(account.account_number)
        except BankValidationError as exc:
            account.verification_status = 'failed'
            account.verification_message = str(exc)
            account.save(update_fields=['verification_status', 'verification_message'])
            return Response({'detail': str(exc)}, status=400)

        user = request.user

        if not cashfree_configured():
            if settings.DEBUG:
                return self._verify_fallback(account, user, ifsc_data)
            return Response(
                {
                    'detail': (
                        'Bank verification is not configured. '
                        'Set CASHFREE_CLIENT_ID and CASHFREE_CLIENT_SECRET.'
                    )
                },
                status=503,
            )

        try:
            pan_result = verify_pan_with_bypass(account.pan_number, account.account_holder_name)
            bank_result = verify_bank_with_bypass(
                bank_account=account.account_number,
                ifsc=account.ifsc,
                name=account.account_holder_name,
                phone=user.phone,
            )
        except CashfreeError as exc:
            account.verification_status = 'failed'
            account.verification_message = str(exc)
            account.is_verified = False
            account.save(
                update_fields=['verification_status', 'verification_message', 'is_verified']
            )
            return Response({'detail': str(exc), 'code': exc.code}, status=400)

        account.is_verified = True
        account.verification_status = 'verified'
        dev_bypass = bool(pan_result.get('dev_bypass') or bank_result.get('dev_bypass'))
        account.verification_provider = 'cashfree_sandbox' if dev_bypass else 'cashfree'
        account.verification_reference_id = bank_result.get('reference_id', '')
        if dev_bypass:
            account.verification_message = (
                'Verified in sandbox (Cashfree IP not whitelisted). '
                'Whitelist your server IP in Cashfree for production.'
            )
        else:
            account.verification_message = 'Verified via Cashfree Secure ID'
        account.name_at_bank = bank_result.get('name_at_bank', '')[:120]
        account.name_match_result = bank_result.get('name_match_result', '')[:40]
        account.pan_registered_name = pan_result.get('registered_name', '')[:120]
        if bank_result.get('bank_name') and not account.bank_name:
            account.bank_name = bank_result['bank_name'][:120]
        account.verified_at = timezone.now()
        account.save()

        user.pan_status = User.PanStatus.VERIFIED
        user.save(update_fields=['pan_status'])

        from engagement.models import Notification

        Notification.objects.create(
            user=user,
            title='Bank Account Verified',
            message='Your bank account and PAN have been verified successfully.',
            type='kyc',
        )

        return Response(
            {
                'success': True,
                'message': (
                    'Bank account and PAN verified (sandbox mode).'
                    if dev_bypass
                    else 'Bank account and PAN verified successfully.'
                ),
                'isVerified': True,
                'provider': account.verification_provider,
                'nameAtBank': account.name_at_bank,
                'nameMatchResult': account.name_match_result,
                'panRegisteredName': account.pan_registered_name,
                'bank': bank_result.get('bank_name') or account.bank_name,
                'branch': bank_result.get('branch') or ifsc_data.get('branch', ''),
            }
        )

    def _verify_fallback(self, account, user, ifsc_data):
        """Dev-only fallback when Cashfree keys are not set."""
        if ifsc_data.get('bank') and not account.bank_name:
            account.bank_name = ifsc_data['bank'][:120]
        account.is_verified = True
        account.verification_status = 'verified'
        account.verification_provider = 'ifsc_dev'
        account.verification_message = 'Dev mode: IFSC validated only (configure Cashfree for production).'
        account.verified_at = timezone.now()
        account.save()

        if getattr(settings, 'KYC_AUTO_APPROVE', False):
            user.pan_status = User.PanStatus.VERIFIED
            user.save(update_fields=['pan_status'])

        return Response(
            {
                'success': True,
                'message': account.verification_message,
                'isVerified': True,
                'provider': 'ifsc_dev',
                'bank': ifsc_data.get('bank', account.bank_name),
                'branch': ifsc_data.get('branch', ''),
            }
        )


class KycDocumentListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        docs = request.user.kyc_documents.all()
        return Response(KycDocumentSerializer(docs, many=True).data)

    def post(self, request):
        serializer = KycDocumentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        doc, _ = KycDocument.objects.update_or_create(
            user=request.user,
            document_type=serializer.validated_data['document_type'],
            defaults={'file': serializer.validated_data['file']},
        )
        user = request.user
        if user.kyc_status == User.KycStatus.PENDING:
            user.kyc_status = User.KycStatus.IN_PROGRESS
            user.save(update_fields=['kyc_status'])
        return Response(KycDocumentSerializer(doc).data, status=201)


class KycSubmitView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        required = {c[0] for c in KycDocument.DocumentType.choices}
        uploaded = set(request.user.kyc_documents.values_list('document_type', flat=True))
        if not required.issubset(uploaded):
            missing = required - uploaded
            return Response(
                {'detail': f'Missing documents: {", ".join(sorted(missing))}'},
                status=400,
            )

        user = request.user
        if getattr(settings, 'KYC_AUTO_APPROVE', True):
            user.kyc_status = User.KycStatus.COMPLETED
            notif_title = 'KYC Verified'
            notif_msg = 'Your KYC verification has been completed successfully.'
        else:
            user.kyc_status = User.KycStatus.IN_PROGRESS
            notif_title = 'KYC Submitted'
            notif_msg = 'Your documents are under review. We will notify you once verified.'
        user.save(update_fields=['kyc_status'])

        from engagement.models import Notification

        Notification.objects.create(
            user=user,
            title=notif_title,
            message=notif_msg,
            type='kyc',
        )
        return Response(KycStatusSerializer(user).data)


class KycStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(KycStatusSerializer(request.user).data)
