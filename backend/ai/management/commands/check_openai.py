from django.conf import settings
from django.core.management.base import BaseCommand

from ai.openai_client import MIN_PROJECT_KEY_LENGTH, mask_api_key, openai_api_key, validate_openai_key


class Command(BaseCommand):
    help = 'Validate OPENAI_API_KEY in backend/.env and test OpenAI API access'

    def handle(self, *args, **options):
        provider = (settings.AI_PROVIDER or '').strip().lower()
        self.stdout.write(f'AI_PROVIDER={provider}')

        try:
            key = openai_api_key()
        except Exception as exc:
            self.stderr.write(self.style.ERROR(str(exc)))
            self._print_help()
            return

        self.stdout.write(f'Key prefix: {mask_api_key(key)}')
        self.stdout.write(f'Key length: {len(key)} chars')
        if key.startswith('sk-proj-') and len(key) < MIN_PROJECT_KEY_LENGTH:
            self.stderr.write(
                self.style.WARNING(
                    f'Project keys are usually {MIN_PROJECT_KEY_LENGTH}+ chars — '
                    'yours may be truncated.'
                )
            )

        ok, message = validate_openai_key()
        if ok:
            self.stdout.write(self.style.SUCCESS(message))
            self.stdout.write(self.style.SUCCESS(f'Chat model: {settings.OPENAI_MODEL}'))
            return

        self.stderr.write(self.style.ERROR(message))
        self._print_help()

    def _print_help(self) -> None:
        self.stderr.write(
            '\nFix steps:\n'
            '  1. Open https://platform.openai.com/api-keys\n'
            '  2. Create a new Secret key (copy the full sk- or sk-proj- value)\n'
            '  3. In backend/.env set: OPENAI_API_KEY=sk-...  (no quotes)\n'
            '  4. Restart Django: python manage.py runserver\n'
            '  5. Re-run: python manage.py check_openai\n'
        )
