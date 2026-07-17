from django.core.management import call_command
from django.core.management.base import BaseCommand

from core.integrations.sms_service import local_lan_ip

from .stopserver import free_port


class Command(BaseCommand):
    help = 'Migrate DB, free port 8000, and start Django for local + phone testing.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--port',
            type=int,
            default=8000,
            help='TCP port for runserver (default: 8000).',
        )
        parser.add_argument(
            '--bind',
            default='0.0.0.0',
            help='Bind address (default: 0.0.0.0 for simulator + physical phone).',
        )
        parser.add_argument(
            '--skip-migrate',
            action='store_true',
            help='Skip database migrations.',
        )
        parser.add_argument(
            '--no-kill',
            action='store_true',
            help='Do not stop an existing server on the same port.',
        )

    def handle(self, *args, **options):
        port = options['port']
        bind = options['bind']

        if not options['no_kill']:
            stopped = free_port(port)
            if stopped:
                unique = sorted(set(stopped))
                self.stdout.write(
                    self.style.WARNING(
                        f'Stopped existing server on port {port} (PID(s): {", ".join(map(str, unique))}).'
                    )
                )

        if not options['skip_migrate']:
            self.stdout.write('Applying migrations...')
            call_command('migrate', interactive=False, verbosity=options['verbosity'])

        lan = local_lan_ip()
        self.stdout.write(self.style.SUCCESS(f'Starting Django at http://{bind}:{port}/'))
        if lan:
            self.stdout.write(
                f'Physical phone: set Flutter ApiConfig.hostOverride = {lan!r} '
                f'or --dart-define=API_HOST={lan}'
            )

        call_command('runserver', f'{bind}:{port}', use_reloader=True)
