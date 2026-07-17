from django.apps import AppConfig

import logging

logger = logging.getLogger('bullwave.kyc')


class KycConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'kyc'
    verbose_name = 'KYC Verification'

    def ready(self):
        from django.conf import settings

        from .notifications import email_config_status

        status = email_config_status()
        admin = status['admin_email']
        chain = status['delivery_chain']

        if not status['ready']:
            logger.warning(
                'KYC admin email NOT configured — set Brevo, SendGrid, or Gmail SMTP in .env'
            )
        else:
            logger.info(
                'Admin email → KYC: %s | F&O: %s | chain: %s | Run: manage.py check_email',
                admin,
                status.get('admin_fno_email', admin),
                ' -> '.join(chain),
            )

        review = status['backend_public_url']
        if not review or review.startswith('http://127.0.0.1') or review.startswith('http://localhost'):
            logger.warning(
                'BACKEND_PUBLIC_URL=%s — email Approve/Reject links need a public URL (deployed API or ngrok).',
                review or '(empty)',
            )

