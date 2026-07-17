import logging

from django.apps import AppConfig

logger = logging.getLogger('bullwave.accounts')


class AccountsConfig(AppConfig):
    name = 'accounts'

    def ready(self):
        from django.conf import settings

        from core.integrations.sms_service import (
            is_live_sms,
            local_lan_ip,
            sms_config_status,
            validate_twilio_config,
        )

        status = sms_config_status()
        provider = status['provider']
        explicit = status['explicit_provider']

        if explicit == 'twilio':
            problems = validate_twilio_config()
            if problems:
                for problem in problems:
                    logger.error('Twilio SMS misconfigured: %s', problem)
                logger.error(
                    'Fix Twilio keys in %s/.env then restart Django.',
                    settings.BASE_DIR,
                )
            elif is_live_sms():
                logger.info('SMS OTP → %s (live SMS to phone)', provider)
        elif is_live_sms():
            logger.info('SMS OTP → %s (live SMS to phone)', provider)
        else:
            logger.warning(
                'SMS OTP → dev/console mode — OTP is NOT sent to the phone. '
                'Add Twilio keys to %s/.env and set SMS_PROVIDER=twilio.',
                settings.BASE_DIR,
            )

        if settings.DEBUG:
            lan = local_lan_ip()
            if lan:
                logger.warning(
                    'Physical phone on Wi‑Fi: run `python manage.py runserver 0.0.0.0:8000` '
                    'and set Flutter ApiConfig.hostOverride = %r (or --dart-define=API_HOST=%s)',
                    lan,
                    lan,
                )
