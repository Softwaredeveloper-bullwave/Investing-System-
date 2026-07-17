"""Email alerts for manual KYC.

Providers: smtp | sendgrid | brevo
Admin emails include full user details + one-click Approve / Reject links.
"""

from __future__ import annotations

import base64
import html
import json
import logging
import mimetypes
from pathlib import Path

from django.conf import settings
from django.core.mail import EmailMessage, EmailMultiAlternatives

from urllib.parse import quote

from .email_tokens import make_fno_action_token, make_kyc_action_token

logger = logging.getLogger('bullwave.kyc')


class EmailDeliveryError(RuntimeError):
    """Email could not be sent (provider API or SMTP)."""


def _email_provider() -> str:
    return (getattr(settings, 'EMAIL_PROVIDER', 'smtp') or 'smtp').strip().lower()


def _smtp_is_configured() -> bool:
    return bool(
        (getattr(settings, 'EMAIL_HOST_USER', '') or '').strip()
        and (getattr(settings, 'EMAIL_HOST_PASSWORD', '') or '').strip()
    )


def _brevo_is_configured() -> bool:
    return bool(
        (getattr(settings, 'BREVO_API_KEY', '') or '').strip()
        and (getattr(settings, 'BREVO_FROM_EMAIL', '') or '').strip()
    )


def _sendgrid_is_configured() -> bool:
    return bool(
        (getattr(settings, 'SENDGRID_API_KEY', '') or '').strip()
        and (getattr(settings, 'SENDGRID_FROM_EMAIL', '') or '').strip()
    )


def email_delivery_chain() -> list[str]:
    """Ordered providers to try: primary first, then other configured APIs, then SMTP."""
    primary = _email_provider()
    chain: list[str] = []
    for candidate in (primary, 'brevo', 'sendgrid', 'smtp'):
        if candidate in chain:
            continue
        if candidate == 'brevo' and not _brevo_is_configured():
            continue
        if candidate == 'sendgrid' and not _sendgrid_is_configured():
            continue
        if candidate == 'smtp' and not _smtp_is_configured():
            continue
        chain.append(candidate)
    return chain


def email_config_status() -> dict:
    """Summary for health checks / manage.py check_email."""
    chain = email_delivery_chain()
    admin_kyc = (getattr(settings, 'ADMIN_KYC_EMAIL', '') or '').strip() or 'bullwaveteam5@gmail.com'
    admin_fno = _admin_fno_email()
    return {
        'primary': _email_provider(),
        'admin_email': admin_kyc,
        'admin_fno_email': admin_fno,
        'backend_public_url': (getattr(settings, 'BACKEND_PUBLIC_URL', '') or '').strip(),
        'delivery_chain': chain,
        'brevo': _brevo_is_configured(),
        'sendgrid': _sendgrid_is_configured(),
        'smtp': _smtp_is_configured(),
        'ready': bool(chain),
    }


def _format_brevo_error(status_code: int, body: str) -> str:
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        return f'Brevo error {status_code}: {body[:400]}'

    message = (data.get('message') or data.get('error') or body)[:400]
    code = (data.get('code') or '').lower()
    hint = ''
    if status_code == 401 and 'ip' in message.lower():
        hint = (
            ' Add this server IP under Brevo → Settings → Security → Authorized IPs, '
            'or disable IP restriction. SMTP fallback will be used if configured.'
        )
    elif 'sender' in message.lower() or code == 'invalid_parameter':
        hint = (
            ' Verify BREVO_FROM_EMAIL under Brevo → Senders & Domains '
            '(must be a confirmed sender, not an unverified Gmail address).'
        )
    return f'Brevo error {status_code}: {message}{hint}'


def _public_url(relative_or_absolute: str) -> str:
    path = (relative_or_absolute or '').strip()
    if not path:
        return ''
    if path.startswith('http://') or path.startswith('https://'):
        return path
    base = (getattr(settings, 'BACKEND_PUBLIC_URL', '') or '').strip().rstrip('/')
    if not base:
        return path
    return f'{base}{path if path.startswith("/") else f"/{path}"}'


def _get_from_email(*, for_smtp: bool = False) -> str:
    provider = _email_provider()
    smtp_user = (getattr(settings, 'EMAIL_HOST_USER', '') or '').strip()
    if for_smtp and smtp_user:
        return smtp_user
    if provider == 'brevo' and not for_smtp:
        brevo_from = (getattr(settings, 'BREVO_FROM_EMAIL', '') or '').strip()
        if brevo_from:
            return brevo_from
    if provider == 'sendgrid' and not for_smtp:
        sg_from = (getattr(settings, 'SENDGRID_FROM_EMAIL', '') or '').strip()
        if sg_from:
            return sg_from
    if provider == 'smtp' and smtp_user:
        return smtp_user
    return (
        (getattr(settings, 'DEFAULT_FROM_EMAIL', '') or '').strip()
        or smtp_user
        or 'noreply@bullwave.app'
    )


def _get_from_name() -> str:
    return (getattr(settings, 'BREVO_FROM_NAME', '') or '').strip() or 'BullWave Capital'


def _encode_attachments(paths: list[str]) -> list[dict]:
    encoded = []
    for path in paths:
        if not path:
            continue
        try:
            p = Path(path)
            if not p.exists():
                continue
            mime, _ = mimetypes.guess_type(str(p))
            mime = mime or 'application/octet-stream'
            encoded.append(
                {
                    'content': base64.b64encode(p.read_bytes()).decode('utf-8'),
                    'name': p.name,
                    'mime': mime,
                }
            )
        except Exception as exc:
            logger.warning('Could not encode attachment %s: %s', path, exc)
    return encoded


def _send_brevo_email(
    *,
    to_email: str,
    subject: str,
    text_body: str,
    html_body: str = '',
    to_name: str = '',
    attachments: list[str] | None = None,
) -> None:
    import httpx

    api_key = (getattr(settings, 'BREVO_API_KEY', '') or '').strip()
    from_email = (getattr(settings, 'BREVO_FROM_EMAIL', '') or '').strip()
    if not api_key:
        raise EmailDeliveryError('Brevo is selected but BREVO_API_KEY is missing.')
    if not from_email:
        raise EmailDeliveryError(
            'Brevo is selected but BREVO_FROM_EMAIL is missing. '
            'Set it to a sender verified in Brevo → Senders & Domains.'
        )

    payload: dict = {
        'sender': {'email': from_email, 'name': _get_from_name()},
        'to': [{'email': to_email, 'name': to_name or to_email}],
        'subject': subject,
        'textContent': text_body,
    }
    if html_body:
        payload['htmlContent'] = html_body

    att = _encode_attachments(attachments or [])
    if att:
        payload['attachment'] = [{'content': a['content'], 'name': a['name']} for a in att]

    r = httpx.post(
        'https://api.brevo.com/v3/smtp/email',
        headers={'api-key': api_key, 'Content-Type': 'application/json', 'accept': 'application/json'},
        json=payload,
        timeout=25.0,
    )
    if r.status_code >= 400:
        raise EmailDeliveryError(_format_brevo_error(r.status_code, r.text))


def _send_sendgrid_email(
    *,
    to_email: str,
    subject: str,
    text_body: str,
    html_body: str = '',
    attachments: list[str] | None = None,
) -> None:
    import httpx

    api_key = (getattr(settings, 'SENDGRID_API_KEY', '') or '').strip()
    from_email = (getattr(settings, 'SENDGRID_FROM_EMAIL', '') or '').strip()
    if not api_key or not from_email:
        raise EmailDeliveryError(
            'SendGrid is selected but SENDGRID_API_KEY/SENDGRID_FROM_EMAIL is missing.'
        )

    content = [{'type': 'text/plain', 'value': text_body}]
    if html_body:
        content.insert(0, {'type': 'text/html', 'value': html_body})

    data: dict = {
        'personalizations': [{'to': [{'email': to_email}]}],
        'from': {'email': from_email},
        'subject': subject,
        'content': content,
    }
    att = _encode_attachments(attachments or [])
    if att:
        data['attachments'] = [
            {'content': a['content'], 'type': a['mime'], 'filename': a['name'], 'disposition': 'attachment'}
            for a in att
        ]

    r = httpx.post(
        'https://api.sendgrid.com/v3/mail/send',
        headers={'Authorization': f'Bearer {api_key}', 'Content-Type': 'application/json'},
        json=data,
        timeout=25.0,
    )
    if r.status_code >= 400:
        raise EmailDeliveryError(f'SendGrid error {r.status_code}: {r.text[:400]}')


def _send_smtp_email(
    *,
    to_email: str,
    subject: str,
    text_body: str,
    html_body: str = '',
    attachments: list[str] | None = None,
) -> None:
    if not _smtp_is_configured():
        raise EmailDeliveryError(
            'SMTP is not configured. Set EMAIL_HOST_USER and EMAIL_HOST_PASSWORD in .env.'
        )

    paths = attachments or []
    from_email = _get_from_email(for_smtp=True)

    if html_body:
        msg = EmailMultiAlternatives(
            subject=subject,
            body=text_body,
            from_email=from_email,
            to=[to_email],
        )
        msg.attach_alternative(html_body, 'text/html')
        for idx, path in enumerate(paths, start=1):
            if path:
                try:
                    msg.attach_file(path)
                except Exception as exc:
                    logger.warning('SMTP attach failed %s: %s', idx, exc)
        msg.send(fail_silently=False)
        return

    email = EmailMessage(
        subject=subject,
        body=text_body,
        from_email=from_email,
        to=[to_email],
    )
    for idx, path in enumerate(paths, start=1):
        if path:
            try:
                email.attach_file(path)
            except Exception as exc:
                logger.warning('SMTP attach failed %s: %s', idx, exc)
    email.send(fail_silently=False)


def _send_email(
    *,
    to_email: str,
    subject: str,
    text_body: str,
    html_body: str = '',
    to_name: str = '',
    attachments: list[str] | None = None,
) -> str:
    """Send email; returns the provider name that succeeded (brevo | sendgrid | smtp)."""
    paths = attachments or []
    chain = email_delivery_chain()
    if not chain:
        raise EmailDeliveryError(
            'No email provider is configured. Set Brevo, SendGrid, or Gmail SMTP in .env.'
        )

    errors: list[str] = []
    for provider in chain:
        try:
            if provider == 'brevo':
                _send_brevo_email(
                    to_email=to_email,
                    to_name=to_name,
                    subject=subject,
                    text_body=text_body,
                    html_body=html_body,
                    attachments=paths,
                )
            elif provider == 'sendgrid':
                _send_sendgrid_email(
                    to_email=to_email,
                    subject=subject,
                    text_body=text_body,
                    html_body=html_body,
                    attachments=paths,
                )
            else:
                _send_smtp_email(
                    to_email=to_email,
                    subject=subject,
                    text_body=text_body,
                    html_body=html_body,
                    attachments=paths,
                )
            logger.info('Email sent via %s → %s (%s)', provider, to_email, subject[:60])
            return provider
        except EmailDeliveryError as exc:
            logger.warning('Email provider %s failed: %s', provider, exc)
            errors.append(f'{provider}: {exc}')

    raise EmailDeliveryError('All email providers failed. ' + ' | '.join(errors))


def _kyc_review_base_url() -> str:
    base = (getattr(settings, 'BACKEND_PUBLIC_URL', '') or '').strip().rstrip('/')
    if base:
        return base
    logger.warning(
        'BACKEND_PUBLIC_URL is not set — email approve/reject buttons will not work. '
        'Set e.g. BACKEND_PUBLIC_URL=https://api.yourdomain.com (or ngrok URL in dev).'
    )
    return 'http://127.0.0.1:8000'


def _warn_if_local_review_url(base: str) -> None:
    lowered = base.lower()
    if lowered.startswith('http://127.0.0.1') or lowered.startswith('http://localhost'):
        logger.warning(
            'BACKEND_PUBLIC_URL is %s — Approve/Reject links in admin email only work on this '
            'machine while Django is running. For phone/Gmail testing use ngrok or your deployed API URL.',
            base,
        )


def _build_admin_kyc_html(
    *,
    request_id: str,
    user_phone: str,
    user_email: str,
    user_city: str,
    pan_number: str,
    full_name: str,
    dob: str,
    submitted_at: str,
    pan_image_urls: list[str],
    approve_url: str,
    reject_url: str,
) -> str:
    rows = [
        ('Full name', full_name),
        ('Phone', user_phone),
        ('Email', user_email or '—'),
        ('City', user_city or '—'),
        ('PAN', pan_number),
        ('Date of birth', dob),
        ('Submitted', submitted_at.replace('T', ' ')[:19]),
        ('Request ID', request_id),
    ]
    table_rows = ''.join(
        f'<tr><td style="padding:8px 12px;color:#64748b;border-bottom:1px solid #e2e8f0;">{html.escape(k)}</td>'
        f'<td style="padding:8px 12px;font-weight:600;border-bottom:1px solid #e2e8f0;">{html.escape(v)}</td></tr>'
        for k, v in rows
    )
    photo_links = ''.join(
        f'<li style="margin:6px 0;"><a href="{html.escape(_public_url(u))}" style="color:#ea580c;">'
        f'View PAN photo {i}</a></li>'
        for i, u in enumerate(pan_image_urls, start=1)
        if u
    )
    if not photo_links:
        photo_links = '<li style="color:#64748b;">See email attachments</li>'

    return f"""<!DOCTYPE html>
<html><body style="margin:0;padding:0;background:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <div style="max-width:600px;margin:24px auto;background:#fff;border-radius:12px;overflow:hidden;border:1px solid #e2e8f0;">
    <div style="background:#0f172a;padding:20px 24px;">
      <h1 style="margin:0;color:#fff;font-size:20px;">New KYC submission</h1>
      <p style="margin:6px 0 0;color:#94a3b8;font-size:14px;">Review and take action below</p>
    </div>
    <div style="padding:24px;">
      <table style="width:100%;border-collapse:collapse;font-size:14px;margin-bottom:20px;">{table_rows}</table>
      <p style="margin:0 0 8px;font-weight:700;font-size:14px;">PAN photos</p>
      <ul style="margin:0 0 24px;padding-left:20px;">{photo_links}</ul>
      <table role="presentation" cellspacing="0" cellpadding="0" style="margin:0 auto;">
        <tr>
          <td style="padding-right:10px;">
            <a href="{html.escape(approve_url)}"
               style="display:inline-block;background:#16a34a;color:#fff;text-decoration:none;padding:14px 28px;border-radius:8px;font-weight:700;">
              ✓ Approve KYC
            </a>
          </td>
          <td>
            <a href="{html.escape(reject_url)}"
               style="display:inline-block;background:#dc2626;color:#fff;text-decoration:none;padding:14px 28px;border-radius:8px;font-weight:700;">
              ✕ Reject (wrong info)
            </a>
          </td>
        </tr>
      </table>
      <p style="margin:24px 0 0;font-size:12px;color:#94a3b8;line-height:1.5;">
        Links expire in 7 days. Approving unlocks trading in the app for this user.
        Rejecting sends them a message to resubmit with correct information.
      </p>
    </div>
  </div>
</body></html>"""


def notify_admin_new_kyc_request(
    *,
    user_phone: str,
    pan_number: str,
    full_name: str,
    request_id: str,
    pan_image_paths: list[str] | None = None,
    pan_image_urls: list[str] | None = None,
    user_email: str = '',
    user_city: str = '',
    dob: str = '',
    submitted_at: str = '',
) -> None:
    """Notify admin with full user details + one-click approve/reject links."""
    admin_email = (getattr(settings, 'ADMIN_KYC_EMAIL', '') or '').strip() or 'bullwaveteam5@gmail.com'
    if not admin_email:
        logger.warning('ADMIN_KYC_EMAIL not set — skipping KYC admin notification')
        return

    base = _kyc_review_base_url()
    _warn_if_local_review_url(base)

    approve_token = make_kyc_action_token(request_id, 'approve')
    reject_token = make_kyc_action_token(request_id, 'reject')
    approve_url = f'{base}/api/v1/kyc/review/approve/?token={quote(approve_token)}'
    reject_url = f'{base}/api/v1/kyc/review/reject/?token={quote(reject_token)}'

    paths = pan_image_paths or []
    urls = [_public_url(u) for u in (pan_image_urls or []) if u]
    subject = f'[BullWave] KYC review — {full_name} ({user_phone})'

    text_body = (
        f'New KYC submission — action required\n\n'
        f'Name: {full_name}\n'
        f'Phone: {user_phone}\n'
        f'Email: {user_email or "—"}\n'
        f'City: {user_city or "—"}\n'
        f'PAN: {pan_number}\n'
        f'DOB: {dob}\n'
        f'Submitted: {submitted_at}\n'
        f'Request ID: {request_id}\n\n'
        f'Approve: {approve_url}\n'
        f'Reject:  {reject_url}\n'
    )
    html_body = _build_admin_kyc_html(
        request_id=request_id,
        user_phone=user_phone,
        user_email=user_email,
        user_city=user_city,
        pan_number=pan_number,
        full_name=full_name,
        dob=dob,
        submitted_at=submitted_at,
        pan_image_urls=urls,
        approve_url=approve_url,
        reject_url=reject_url,
    )

    try:
        provider = _send_email(
            to_email=admin_email,
            subject=subject,
            text_body=text_body,
            html_body=html_body,
            attachments=paths,
        )
        logger.info('KYC admin notification sent via %s to %s', provider, admin_email)
    except Exception as exc:
        logger.exception(
            'Failed to send KYC admin email to %s. Providers tried: %s. Error: %s',
            admin_email,
            ' -> '.join(email_delivery_chain()) or '(none)',
            exc,
        )


def notify_user_kyc_approved(
    *,
    user_phone: str,
    full_name: str,
    user_email: str = '',
) -> None:
    """Tell the user their PAN/KYC is approved — unlocks app trading."""
    from core.integrations.sms_service import send_notification_sms

    name = (full_name or 'Investor').strip()
    subject = '[BullWave] KYC verified — you can start trading'
    text_body = (
        f'Hi {name},\n\n'
        f'Your PAN/KYC verification is complete.\n\n'
        f'Open the BullWave app — you now have full access to markets, '
        f'buy/sell stocks, and your portfolio.\n\n'
        f'Thank you for choosing BullWave Capital.'
    )
    html_body = f"""<html><body style="font-family:sans-serif;line-height:1.6;">
      <h2 style="color:#16a34a;">KYC verified ✓</h2>
      <p>Hi {html.escape(name)},</p>
      <p>Your PAN/KYC verification is <strong>complete</strong>.</p>
      <p>Open the <strong>BullWave</strong> app — you can now trade stocks and access your portfolio.</p>
      <p style="color:#64748b;">Thank you for choosing BullWave Capital.</p>
    </body></html>"""
    sms = (
        f'BullWave: Your KYC is verified. Open the app to start trading. '
        f'Welcome, {name.split()[0] if name else "Investor"}!'
    )

    email = (user_email or '').strip()
    if email:
        try:
            _send_email(to_email=email, subject=subject, text_body=text_body, html_body=html_body)
        except Exception as exc:
            logger.exception('Failed to send KYC approval email to %s: %s', email, exc)

    if user_phone:
        try:
            send_notification_sms(user_phone, sms)
        except Exception as exc:
            logger.warning('KYC approval SMS failed for %s: %s', user_phone, exc)


def notify_user_kyc_rejected(
    *,
    user_phone: str,
    full_name: str,
    user_email: str = '',
    reason: str = '',
) -> None:
    """Tell the user their KYC was rejected so they can resubmit."""
    from core.integrations.sms_service import send_notification_sms

    from .constants import KYC_WRONG_INFO_REJECTION_REASON

    name = (full_name or 'Investor').strip()
    reason_text = (reason or KYC_WRONG_INFO_REJECTION_REASON).strip()
    subject = '[BullWave] KYC could not be verified'
    text_body = (
        f'Hi {name},\n\n'
        f'We could not verify your PAN/KYC submission.\n\n'
        f'{reason_text}\n\n'
        f'Open the BullWave app and resubmit your KYC with updated details.'
    )
    html_body = f"""<html><body style="font-family:sans-serif;line-height:1.6;">
      <h2 style="color:#dc2626;">KYC not verified</h2>
      <p>Hi {html.escape(name)},</p>
      <p>{html.escape(reason_text)}</p>
      <p>Open the <strong>BullWave</strong> app and resubmit your KYC with correct information.</p>
    </body></html>"""
    sms = f'BullWave: {reason_text[:120]} Open the app to resubmit.'

    email = (user_email or '').strip()
    if email:
        try:
            _send_email(to_email=email, subject=subject, text_body=text_body, html_body=html_body)
        except Exception as exc:
            logger.exception('Failed to send KYC rejection email to %s: %s', email, exc)

def _admin_fno_email() -> str:
    fno = (getattr(settings, 'ADMIN_FNO_EMAIL', '') or '').split('#', 1)[0].strip()
    if fno:
        return fno
    kyc = (getattr(settings, 'ADMIN_KYC_EMAIL', '') or '').split('#', 1)[0].strip()
    return kyc or 'bullwaveteam5@gmail.com'


def _build_admin_fno_html(
    *,
    request_id: str,
    user_phone: str,
    user_email: str,
    user_name: str,
    proof_label: str,
    portfolio_value: str,
    submitted_at: str,
    document_url: str,
    approve_url: str,
    reject_url: str,
) -> str:
    rows = [
        ('User name', user_name or '—'),
        ('Phone', user_phone),
        ('Email', user_email or '—'),
        ('Proof type', proof_label),
        ('Portfolio value', portfolio_value),
        ('Submitted', submitted_at.replace('T', ' ')[:19]),
        ('Request ID', request_id),
    ]
    table_rows = ''.join(
        f'<tr><td style="padding:8px 12px;color:#64748b;border-bottom:1px solid #e2e8f0;">{html.escape(k)}</td>'
        f'<td style="padding:8px 12px;font-weight:600;border-bottom:1px solid #e2e8f0;">{html.escape(v)}</td></tr>'
        for k, v in rows
    )
    doc_link = (
        f'<li style="margin:6px 0;"><a href="{html.escape(_public_url(document_url))}" '
        f'style="color:#9333ea;">View uploaded document</a></li>'
        if document_url
        else '<li style="color:#64748b;">See email attachment</li>'
    )

    return f"""<!DOCTYPE html>
<html><body style="margin:0;padding:0;background:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <div style="max-width:600px;margin:24px auto;background:#fff;border-radius:12px;overflow:hidden;border:1px solid #e2e8f0;">
    <div style="background:linear-gradient(135deg,#581c87,#9333ea);padding:20px 24px;">
      <h1 style="margin:0;color:#fff;font-size:20px;">New F&O eligibility request</h1>
      <p style="margin:6px 0 0;color:#e9d5ff;font-size:14px;">Review document and approve F&O access</p>
    </div>
    <div style="padding:24px;">
      <table style="width:100%;border-collapse:collapse;font-size:14px;margin-bottom:20px;">{table_rows}</table>
      <p style="margin:0 0 8px;font-weight:700;font-size:14px;">Uploaded proof</p>
      <ul style="margin:0 0 24px;padding-left:20px;">{doc_link}</ul>
      <table role="presentation" cellspacing="0" cellpadding="0" style="margin:0 auto;">
        <tr>
          <td style="padding-right:10px;">
            <a href="{html.escape(approve_url)}"
               style="display:inline-block;background:#16a34a;color:#fff;text-decoration:none;padding:14px 28px;border-radius:8px;font-weight:700;">
              ✓ Approve F&O Access
            </a>
          </td>
          <td>
            <a href="{html.escape(reject_url)}"
               style="display:inline-block;background:#dc2626;color:#fff;text-decoration:none;padding:14px 28px;border-radius:8px;font-weight:700;">
              ✕ Reject
            </a>
          </td>
        </tr>
      </table>
      <p style="margin:24px 0 0;font-size:12px;color:#94a3b8;line-height:1.5;">
        Links expire in 7 days. Approving unlocks Futures &amp; Options trading for this user.
        Rejecting notifies the user to choose another proof option.
      </p>
    </div>
  </div>
</body></html>"""


def notify_admin_new_fno_request(
    *,
    user_phone: str,
    user_email: str,
    user_name: str,
    proof_label: str,
    portfolio_value: float,
    request_id: str,
    document_path: str = '',
    document_url: str = '',
    submitted_at: str = '',
) -> None:
    """Notify admin with F&O proof details + one-click approve/reject links."""
    admin_email = _admin_fno_email()
    if not admin_email:
        logger.warning('ADMIN_FNO_EMAIL / ADMIN_KYC_EMAIL not set — skipping F&O admin notification')
        return

    logger.info(
        'Sending F&O admin notification for request %s (%s) → %s',
        request_id,
        proof_label,
        admin_email,
    )

    base = _kyc_review_base_url()
    _warn_if_local_review_url(base)

    approve_token = make_fno_action_token(request_id, 'approve')
    reject_token = make_fno_action_token(request_id, 'reject')
    approve_url = f'{base}/api/v1/fno/review/approve/?token={quote(approve_token)}'
    reject_url = f'{base}/api/v1/fno/review/reject/?token={quote(reject_token)}'

    paths = [document_path] if document_path else []
    portfolio_str = f'₹{portfolio_value:,.0f}'
    subject = f'[BullWave] F&O review — {proof_label} ({user_phone})'

    text_body = (
        f'New F&O eligibility submission — action required\n\n'
        f'Name: {user_name or "—"}\n'
        f'Phone: {user_phone}\n'
        f'Email: {user_email or "—"}\n'
        f'Proof: {proof_label}\n'
        f'Portfolio value: {portfolio_str}\n'
        f'Submitted: {submitted_at}\n'
        f'Request ID: {request_id}\n\n'
        f'Approve: {approve_url}\n'
        f'Reject:  {reject_url}\n'
    )
    html_body = _build_admin_fno_html(
        request_id=request_id,
        user_phone=user_phone,
        user_email=user_email,
        user_name=user_name,
        proof_label=proof_label,
        portfolio_value=portfolio_str,
        submitted_at=submitted_at,
        document_url=document_url,
        approve_url=approve_url,
        reject_url=reject_url,
    )

    try:
        provider = _send_email(
            to_email=admin_email,
            subject=subject,
            text_body=text_body,
            html_body=html_body,
            attachments=paths,
        )
        logger.info('F&O admin notification sent via %s to %s', provider, admin_email)
    except Exception as exc:
        logger.exception(
            'Failed to send F&O admin email to %s. Providers tried: %s. Error: %s',
            admin_email,
            ' -> '.join(email_delivery_chain()) or '(none)',
            exc,
        )


def notify_user_fno_approved(
    *,
    user_phone: str,
    user_name: str,
    user_email: str = '',
) -> None:
    """Tell the user their F&O access is approved."""
    from core.integrations.sms_service import send_notification_sms

    name = (user_name or 'Investor').strip()
    subject = '[BullWave] F&O access approved — trade futures & options'
    text_body = (
        f'Hi {name},\n\n'
        f'Your F&O eligibility verification is complete.\n\n'
        f'Open the BullWave app — you can now access Futures & Options, '
        f'option chains, and paper trading.\n\n'
        f'Thank you for choosing BullWave Capital.'
    )
    html_body = f"""<html><body style="font-family:sans-serif;line-height:1.6;">
      <h2 style="color:#9333ea;">F&O access approved ✓</h2>
      <p>Hi {html.escape(name)},</p>
      <p>Your F&O eligibility is <strong>verified</strong>.</p>
      <p>Open the <strong>BullWave</strong> app to trade Futures &amp; Options.</p>
      <p style="color:#64748b;">Thank you for choosing BullWave Capital.</p>
    </body></html>"""
    sms = (
        f'BullWave: F&O access approved. Open the app to trade futures and options. '
        f'Welcome, {name.split()[0] if name else "Investor"}!'
    )

    email = (user_email or '').strip()
    if email:
        try:
            _send_email(to_email=email, subject=subject, text_body=text_body, html_body=html_body)
        except Exception as exc:
            logger.exception('Failed to send F&O approval email to %s: %s', email, exc)

    if user_phone:
        try:
            send_notification_sms(user_phone, sms)
        except Exception as exc:
            logger.warning('F&O approval SMS failed for %s: %s', user_phone, exc)


def notify_user_fno_rejected(
    *,
    user_phone: str,
    user_name: str,
    user_email: str = '',
    reason: str = '',
) -> None:
    """Tell the user their F&O proof was rejected so they can resubmit."""
    from core.integrations.sms_service import send_notification_sms

    from .constants import FNO_WRONG_INFO_REJECTION_REASON

    name = (user_name or 'Investor').strip()
    reason_text = (reason or FNO_WRONG_INFO_REJECTION_REASON).strip()
    subject = '[BullWave] F&O verification could not be completed'
    text_body = (
        f'Hi {name},\n\n'
        f'We could not verify your F&O eligibility document.\n\n'
        f'{reason_text}\n\n'
        f'Open the BullWave app and choose another proof option (Form 16, ITR, '
        f'bank statement, or ₹50k portfolio).'
    )
    html_body = f"""<html><body style="font-family:sans-serif;line-height:1.6;">
      <h2 style="color:#dc2626;">F&O not verified</h2>
      <p>Hi {html.escape(name)},</p>
      <p>{html.escape(reason_text)}</p>
      <p>Open the <strong>BullWave</strong> app and submit another eligibility proof.</p>
    </body></html>"""
    sms = f'BullWave: {reason_text[:120]} Open the app to resubmit F&O proof.'

    email = (user_email or '').strip()
    if email:
        try:
            _send_email(to_email=email, subject=subject, text_body=text_body, html_body=html_body)
        except Exception as exc:
            logger.exception('Failed to send F&O rejection email to %s: %s', email, exc)

    if user_phone:
        try:
            send_notification_sms(user_phone, sms)
        except Exception as exc:
            logger.warning('F&O rejection SMS failed for %s: %s', user_phone, exc)
