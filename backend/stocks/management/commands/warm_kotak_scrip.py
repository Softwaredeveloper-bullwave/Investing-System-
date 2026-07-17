from django.core.management.base import BaseCommand

from stocks.kotak_neo_client import KotakNeoError, warm_scrip_master


class Command(BaseCommand):
    help = 'Download Kotak Neo NSE scrip master (symbol → instrument token map).'

    def add_arguments(self, parser):
        parser.add_argument('--force', action='store_true', help='Re-download even if cached')

    def handle(self, *args, **options):
        try:
            count = warm_scrip_master(force=options['force'])
        except KotakNeoError as exc:
            self.stderr.write(self.style.ERROR(str(exc)))
            return
        self.stdout.write(self.style.SUCCESS(f'Kotak scrip master ready: {count} NSE symbols mapped'))
