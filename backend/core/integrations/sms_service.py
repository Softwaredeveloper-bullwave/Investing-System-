"""SMS OTP delivery — MSG91, Twilio Messages, Twilio Verify, or console (dev)."""

import logging
import re
import socket

import httpx
from django.conf import settings

logger = logging.getLogger('bullwave.integrations')


class SMSError(Exception):
    pass


def _twilio_credentials_ready() -> bool:
    account_sid = (getattr(settings, 'TWILIO_ACCOUNT_SID', '') or '').strip()
    auth_token = (getattr(settings, 'TWILIO_AUTH_TOKEN', '') or '').strip()
    return bool(account_sid and auth_token)


def _twilio_verify_ready() -> bool:
    service_sid = (getattr(settings, 'TWILIO_SERVICE_SID', '') or '').strip()
    return _twilio_credentials_ready() and bool(service_sid)


def _twilio_message_ready() -> bool:
    from_number = (getattr(settings, 'TWILIO_FROM_NUMBER', '') or '').strip()
    return _twilio_credentials_ready() and bool(from_number)


def _msg91_ready() -> bool:
    auth_key = (getattr(settings, 'MSG91_AUTH_KEY', '') or '').strip()
    template_id = (getattr(settings, 'MSG91_TEMPLATE_ID', '') or '').strip()
    return bool(auth_key and template_id)


def resolve_sms_provider() -> str:
    """Effective SMS provider — settings layer auto-promotes console → twilio/msg91 when keys exist."""
    provider = (getattr(settings, 'SMS_PROVIDER', 'console') or 'console').lower().strip()
    if provider == 'twilio' and not (_twilio_verify_ready() or _twilio_message_ready()):
        return 'console'
    if provider == 'msg91' and not _msg91_ready():
        return 'console'
    return provider


def uses_twilio_verify() -> bool:
    return resolve_sms_provider() == 'twilio' and _twilio_verify_ready()


def is_live_sms() -> bool:
    return resolve_sms_provider() != 'console'


def validate_twilio_config() -> list[str]:
    """Return list of configuration problems (empty = OK)."""
    provider = (getattr(settings, 'SMS_PROVIDER', 'console') or 'console').lower().strip()
    if provider != 'twilio':
        return []

    problems = []
    sid = (getattr(settings, 'TWILIO_ACCOUNT_SID', '') or '').strip()
    token = (getattr(settings, 'TWILIO_AUTH_TOKEN', '') or '').strip()
    service_sid = (getattr(settings, 'TWILIO_SERVICE_SID', '') or '').strip()
    from_number = (getattr(settings, 'TWILIO_FROM_NUMBER', '') or '').strip()

    if not sid:
        problems.append('TWILIO_ACCOUNT_SID is missing in backend/.env')
    elif not sid.startswith('AC'):
        problems.append('TWILIO_ACCOUNT_SID should start with AC')

    if not token:
        problems.append('TWILIO_AUTH_TOKEN is missing in backend/.env')

    if not service_sid and not from_number:
        problems.append(
            'Set TWILIO_SERVICE_SID (Verify, recommended) or TWILIO_FROM_NUMBER (Messages) in backend/.env'
        )
    if service_sid and not service_sid.startswith('VA'):
        problems.append('TWILIO_SERVICE_SID should start with VA (Twilio Verify Service SID)')

    return problems


def sms_config_status() -> dict:
    provider = resolve_sms_provider()
    explicit = (getattr(settings, 'SMS_PROVIDER', 'console') or 'console').lower().strip()
    twilio_verify = uses_twilio_verify()
    mode = 'sms' if provider != 'console' else 'console'
    twilio_problems = validate_twilio_config()
    ready = mode == 'sms' and not twilio_problems

    hints = []
    if explicit == 'twilio' and twilio_problems:
        hints.extend(twilio_problems)
    elif mode == 'console':
        hints.append(
            'OTP is NOT sent to the phone — add Twilio keys to backend/.env (not investingapp/env).'
        )
        hints.append(
            'Required: TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_SERVICE_SID (Verify) '
            'or TWILIO_FROM_NUMBER (Messages). Set SMS_PROVIDER=twilio.'
        )

    return {
        'explicit_provider': explicit,
        'provider': 'twilio_verify' if twilio_verify else provider,
        'mode': mode,
        'ready': ready,
        'twilio_verify': twilio_verify,
        'msg91_configured': _msg91_ready(),
        'twilio_configured': _twilio_verify_ready() or _twilio_message_ready(),
        'twilio_problems': twilio_problems,
        'hints': hints,
        'env_file': str(getattr(settings, 'BASE_DIR', '')) + '/.env',
    }


def local_lan_ip() -> str:
    """Best-effort LAN IP for physical-device testing hints."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.connect(('8.8.8.8', 80))
            return sock.getsockname()[0]
    except OSError:
        return ''


def _normalize_phone_e164(phone: str) -> str:
    digits = re.sub(r'\D', '', phone or '')
    if len(digits) == 10:
        return f'+91{digits}'
    if len(digits) == 12 and digits.startswith('91'):
        return f'+{digits}'
    if phone and str(phone).strip().startswith('+'):
        return re.sub(r'\s', '', str(phone).strip())
    return f'+{digits}' if digits else ''


def send_notification_sms(phone: str, message: str) -> None:
    """Generic transactional SMS (KYC approved, etc.). Falls back to console in dev."""
    provider = resolve_sms_provider()
    body = (message or '').strip()
    if not phone or not body:
        return
    if provider == 'twilio' and not uses_twilio_verify():
        _send_twilio_message(phone, body)
    elif provider == 'console':
        msg = f'[BullWave SMS] Phone: {phone} | {body}'
        logger.info(msg)
        if settings.DEBUG:
            import sys

            print(msg, flush=True)
            sys.stderr.write(msg + '\n')


def send_otp_sms(phone: str, otp: str) -> None:
    provider = resolve_sms_provider()
    if provider == 'msg91':
        _send_msg91(phone, otp)
    elif provider == 'twilio':
        if uses_twilio_verify():
            _send_twilio_verify(phone)
        else:
            _send_twilio(phone, otp)
    else:
        _send_console(phone, otp)


def check_otp_twilio_verify(phone: str, otp: str) -> bool:
    account_sid = (getattr(settings, 'TWILIO_ACCOUNT_SID', '') or '').strip()
    auth_token = (getattr(settings, 'TWILIO_AUTH_TOKEN', '') or '').strip()
    service_sid = (getattr(settings, 'TWILIO_SERVICE_SID', '') or '').strip()
    channel = (getattr(settings, 'TWILIO_VERIFY_CHANNEL', 'sms') or 'sms').strip()

    url = f'https://verify.twilio.com/v2/Services/{service_sid}/VerificationCheck'
    try:
        with httpx.Client(timeout=15) as client:
            response = client.post(
                url,
                data={'To': _normalize_phone_e164(phone), 'Code': otp, 'Channel': channel},
                auth=(account_sid, auth_token),
            )
    except httpx.HTTPError as exc:
        raise SMSError(f'Twilio Verify connection failed: {exc}') from exc

    if response.is_error:
        raise SMSError(f'Twilio Verify error ({response.status_code}): {response.text[:200]}')

    data = response.json()
    return (data.get('status') or '').lower() == 'approved'


def _send_console(phone: str, otp: str) -> None:
    msg = f'[BullWave OTP] Phone: {phone} | OTP: {otp}'
    logger.info(msg)
    if settings.DEBUG:
        import sys

        print(msg, flush=True)
        sys.stderr.write(msg + '\n')


def _send_msg91(phone: str, otp: str) -> None:
    auth_key = (getattr(settings, 'MSG91_AUTH_KEY', '') or '').strip()
    template_id = (getattr(settings, 'MSG91_TEMPLATE_ID', '') or '').strip()
    if not auth_key or not template_id:
        raise SMSError('MSG91_AUTH_KEY and MSG91_TEMPLATE_ID are required when SMS_PROVIDER=msg91')

    payload = {
        'template_id': template_id,
        'short_url': '0',
        'recipients': [{'mobiles': f'91{phone}', 'otp': otp}],
    }
    try:
        with httpx.Client(timeout=15) as client:
            response = client.post(
                'https://control.msg91.com/api/v5/flow/',
                json=payload,
                headers={'authkey': auth_key, 'Content-Type': 'application/json'},
            )
    except httpx.HTTPError as exc:
        raise SMSError(f'MSG91 connection failed: {exc}') from exc

    if response.is_error:
        raise SMSError(f'MSG91 error ({response.status_code}): {response.text[:200]}')

    logger.info('MSG91 OTP sent to +91%s', phone)


def _send_twilio_verify(phone: str) -> None:
    account_sid = (getattr(settings, 'TWILIO_ACCOUNT_SID', '') or '').strip()
    auth_token = (getattr(settings, 'TWILIO_AUTH_TOKEN', '') or '').strip()
    service_sid = (getattr(settings, 'TWILIO_SERVICE_SID', '') or '').strip()
    channel = (getattr(settings, 'TWILIO_VERIFY_CHANNEL', 'sms') or 'sms').strip()
    to = _normalize_phone_e164(phone)

    url = f'https://verify.twilio.com/v2/Services/{service_sid}/Verifications'
    try:
        with httpx.Client(timeout=15) as client:
            response = client.post(
                url,
                data={'To': to, 'Channel': channel},
                auth=(account_sid, auth_token),
            )
    except httpx.HTTPError as exc:
        raise SMSError(f'Twilio Verify connection failed: {exc}') from exc

    if response.is_error:
        raise SMSError(f'Twilio Verify error ({response.status_code}): {response.text[:200]}')

    logger.info('Twilio Verify OTP sent to %s', to)


def _send_twilio_message(phone: str, body: str) -> None:
    account_sid = (getattr(settings, 'TWILIO_ACCOUNT_SID', '') or '').strip()
    auth_token = (getattr(settings, 'TWILIO_AUTH_TOKEN', '') or '').strip()
    from_number = (getattr(settings, 'TWILIO_FROM_NUMBER', '') or '').strip()
    if not all([account_sid, auth_token, from_number]):
        raise SMSError(
            'TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER required for SMS notifications'
        )

    to = _normalize_phone_e164(phone)
    url = f'https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json'
    try:
        with httpx.Client(timeout=15) as client:
            response = client.post(
                url,
                data={'To': to, 'From': from_number, 'Body': body},
                auth=(account_sid, auth_token),
            )
    except httpx.HTTPError as exc:
        raise SMSError(f'Twilio connection failed: {exc}') from exc

    if response.is_error:
        raise SMSError(f'Twilio error ({response.status_code}): {response.text[:200]}')

    logger.info('Twilio SMS sent to %s', to)


def _send_twilio(phone: str, otp: str) -> None:
    body = f'Your BullWave Capital OTP is {otp}. Valid for {settings.OTP_EXPIRY_MINUTES} minutes.'
    _send_twilio_message(phone, body)
