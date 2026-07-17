from django.core.management.base import BaseCommand

from ai.ollama_client import check_ollama, chat
from django.conf import settings


class Command(BaseCommand):
    help = 'Check Ollama is running and test the AI assistant model'

    def handle(self, *args, **options):
        self.stdout.write(f'Ollama URL: {settings.OLLAMA_BASE_URL}')
        self.stdout.write(f'Model: {settings.OLLAMA_MODEL}')

        ok, message = check_ollama()
        if not ok:
            self.stderr.write(self.style.ERROR(message))
            self.stderr.write(
                '\nSetup steps:\n'
                '  1. Download Ollama: https://ollama.com/download\n'
                f'  2. ollama pull {settings.OLLAMA_MODEL}\n'
                '  3. Restart Django runserver\n'
            )
            return

        self.stdout.write(self.style.SUCCESS(message))

        self.stdout.write('Sending test prompt...')
        try:
            reply = chat(
                system_prompt='You are a helpful assistant. Reply in one short sentence.',
                history=[],
                user_message='Say hello in 5 words.',
            )
            self.stdout.write(self.style.SUCCESS(f'Test reply: {reply[:200]}'))
        except Exception as exc:
            self.stderr.write(self.style.ERROR(f'Test failed: {exc}'))
