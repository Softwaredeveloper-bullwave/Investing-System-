from django.core.management.base import BaseCommand

from core.integrations.sms_service import (
    is_live_sms,
    local_lan_ip,
    resolve_sms_provider,
    sms_config_status,
    validate_twilio_config,
)


class Command(BaseCommand):
    help = 'Print SMS OTP configuration and physical-device testing hints.'

    def handle(self, *args, **options):
        status = sms_config_status()
        self.stdout.write(f"Env file: {status['env_file']}")
        self.stdout.write(f"SMS_PROVIDER (explicit)={status['explicit_provider']}")
        self.stdout.write(f"Effective provider={status['provider']}")
        self.stdout.write(f"Mode={status['mode']} ({'live SMS' if status['mode'] == 'sms' else 'dev/console'})")
        self.stdout.write(f"Twilio Verify={status['twilio_verify']}")
        self.stdout.write(f"MSG91 configured={status['msg91_configured']}")
        self.stdout.write(f"Twilio configured={status['twilio_configured']}")

        for problem in status.get('twilio_problems') or []:
            self.stderr.write(self.style.ERROR(f'  ✗ {problem}'))

        for hint in status['hints']:
            self.stdout.write(f'  • {hint}')

        lan = local_lan_ip()
        if lan:
            self.stdout.write('')
            self.stdout.write('Physical phone on same Wi‑Fi:')
            self.stdout.write('  1. python manage.py runserver 0.0.0.0:8000')
            self.stdout.write(f"  2. Flutter: ApiConfig.hostOverride = {lan!r}")
            self.stdout.write(f'     or: flutter run --dart-define=API_HOST={lan}')

        if status['explicit_provider'] == 'twilio' and validate_twilio_config():
            self.stderr.write(
                self.style.ERROR(
                    'Twilio is selected but credentials are missing or invalid in backend/.env.'
                )
            )
        elif not is_live_sms():
            self.stderr.write(
                self.style.WARNING(
                    'OTP is NOT sent to the phone in console mode. '
                    'Set SMS_PROVIDER=twilio and add keys to backend/.env.'
                )
            )
        else:
            self.stdout.write(self.style.SUCCESS('SMS OTP is configured for live delivery to phone.'))
