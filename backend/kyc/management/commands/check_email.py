from django.core.management.base import BaseCommand

from django.conf import settings

from kyc.notifications import EmailDeliveryError, _send_email, email_config_status


class Command(BaseCommand):
    help = 'Verify KYC email delivery (Brevo/SendGrid/SMTP) and print config status.'

    def handle(self, *args, **options):
        status = email_config_status()
        admin = status['admin_email']

        self.stdout.write(f"EMAIL_PROVIDER={status['primary']}")
        self.stdout.write(f'ADMIN_KYC_EMAIL={admin}')
        self.stdout.write(f"ADMIN_FNO_EMAIL={status.get('admin_fno_email', admin)}")
        self.stdout.write(f"BACKEND_PUBLIC_URL={status['backend_public_url'] or '(not set)'}")
        self.stdout.write(f"Brevo configured={status['brevo']}")
        self.stdout.write(f"SendGrid configured={status['sendgrid']}")
        self.stdout.write(f"SMTP configured={status['smtp']}")
        self.stdout.write(f"Delivery chain={' -> '.join(status['delivery_chain']) or '(none)'}")

        if not status['ready']:
            self.stderr.write(
                self.style.ERROR(
                    'No email provider is configured. Add Brevo, SendGrid, or Gmail SMTP to .env.'
                )
            )
            return

        try:
            provider = _send_email(
                to_email=admin,
                subject='[BullWave] Email configuration test',
                text_body='If you received this, KYC admin notifications are working.',
                html_body='<p>If you received this, <strong>KYC admin notifications</strong> are working.</p>',
            )
        except EmailDeliveryError as exc:
            self.stderr.write(self.style.ERROR(f'Email test failed: {exc}'))
            return

        self.stdout.write(self.style.SUCCESS(f'Test email sent via {provider} to {admin}. Check inbox (and spam).'))

        review = status['backend_public_url']
        if not review or review.startswith('http://127.0.0.1') or review.startswith('http://localhost'):
            self.stdout.write(
                self.style.WARNING(
                    'BACKEND_PUBLIC_URL is localhost — Approve/Reject buttons in admin email '
                    'will not work from Gmail on your phone. Use ngrok or your deployed API URL.'
                )
            )
