"""Transactional email delivery via Brevo (formerly Sendinblue).

Used for the email-OTP second factor (see `accounts.views.VerifyOTPView` /
`VerifyEmailOTPView`) — after a user verifies their phone OTP, if they have
an email on file, this sends a second OTP to that email before JWTs are
issued, so logging in requires proving control of both the phone number and
the inbox (true two-factor, not just two single-factor checks in a row).

Mirrors the shape of `core.integrations.sms_service` (settings-driven
readiness check, console fallback in DEBUG when not configured) so both
"real" delivery channels behave consistently in dev vs production.
"""

from __future__ import annotations

import logging

import httpx
from django.conf import settings

logger = logging.getLogger('bullwave.integrations')

BREVO_SEND_URL = 'https://api.brevo.com/v3/smtp/email'


class EmailError(Exception):
    pass


def is_brevo_ready() -> bool:
    api_key = (getattr(settings, 'BREVO_API_KEY', '') or '').strip()
    sender_email = (getattr(settings, 'BREVO_SENDER_EMAIL', '') or '').strip()
    return bool(api_key and sender_email)


def is_live_email() -> bool:
    return is_brevo_ready()


def _send_console(to_email: str, subject: str, otp: str) -> None:
    msg = f'[BullWave Email OTP] To: {to_email} | Subject: {subject} | OTP: {otp}'
    logger.info(msg)
    if settings.DEBUG:
        import sys

        print(msg, flush=True)
        sys.stderr.write(msg + '\n')


def _otp_email_html(name: str, otp: str, expiry_minutes: int) -> str:
    greeting = f'Hi {name},' if name else 'Hi,'
    return f"""
    <div style="font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
      <h2 style="color: #111827;">Capital Bullwave</h2>
      <p style="color: #374151; font-size: 15px;">{greeting}</p>
      <p style="color: #374151; font-size: 15px;">
        Your email verification code is:
      </p>
      <div style="font-size: 32px; font-weight: 700; letter-spacing: 8px; color: #111827; background: #F3F4F6; padding: 16px 24px; border-radius: 12px; text-align: center; margin: 16px 0;">
        {otp}
      </div>
      <p style="color: #6B7280; font-size: 13px;">
        This code expires in {expiry_minutes} minutes. If you didn't try to log in, you can safely ignore this email —
        do not share this code with anyone, including someone claiming to be from Capital Bullwave support.
      </p>
    </div>
    """


def send_email_otp(to_email: str, name: str, otp: str) -> bool:
    """Sends the OTP email. Returns True if actually sent via Brevo, False if
    it only logged to console (dev/unconfigured). Raises EmailError on a
    genuine Brevo API failure so the caller can decide how to respond.
    """
    expiry_minutes = getattr(settings, 'EMAIL_OTP_EXPIRY_MINUTES', 10)
    subject = 'Your Capital Bullwave verification code'

    if not is_brevo_ready():
        _send_console(to_email, subject, otp)
        return False

    api_key = settings.BREVO_API_KEY
    sender_email = settings.BREVO_SENDER_EMAIL
    sender_name = getattr(settings, 'BREVO_SENDER_NAME', '') or 'Capital Bullwave'

    payload = {
        'sender': {'name': sender_name, 'email': sender_email},
        'to': [{'email': to_email, 'name': name or to_email}],
        'subject': subject,
        'htmlContent': _otp_email_html(name, otp, expiry_minutes),
    }

    try:
        with httpx.Client(timeout=15) as client:
            response = client.post(
                BREVO_SEND_URL,
                json=payload,
                headers={
                    'api-key': api_key,
                    'Content-Type': 'application/json',
                    'accept': 'application/json',
                },
            )
    except httpx.HTTPError as exc:
        raise EmailError(f'Brevo connection failed: {exc}') from exc

    if response.is_error:
        raise EmailError(f'Brevo error ({response.status_code}): {response.text[:200]}')

    logger.info('Brevo email OTP sent to %s', to_email)
    return True
