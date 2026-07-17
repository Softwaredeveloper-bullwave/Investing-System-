import os
import signal
import subprocess
import time

from django.core.management.base import BaseCommand, CommandError


def _pids_on_port(port: int) -> list[int]:
    try:
        result = subprocess.run(
            ['lsof', '-ti', f'tcp:{port}'],
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError as exc:
        raise CommandError('lsof is required on macOS/Linux to free a port.') from exc

    pids: list[int] = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            pids.append(int(line))
        except ValueError:
            continue
    return pids


def free_port(port: int, *, force: bool = False) -> list[int]:
    """Stop processes listening on the given TCP port."""
    stopped: list[int] = []
    sig = signal.SIGKILL if force else signal.SIGTERM

    for pid in _pids_on_port(port):
        try:
            os.kill(pid, sig)
            stopped.append(pid)
        except ProcessLookupError:
            continue
        except PermissionError as exc:
            raise CommandError(f'Cannot stop PID {pid} on port {port}: {exc}') from exc

    if stopped and not force:
        time.sleep(0.8)
        remaining = _pids_on_port(port)
        if remaining:
            for pid in remaining:
                try:
                    os.kill(pid, signal.SIGKILL)
                    stopped.append(pid)
                except ProcessLookupError:
                    continue

    return stopped


class Command(BaseCommand):
    help = 'Stop Django/dev processes bound to a TCP port (default: 8000).'

    def add_arguments(self, parser):
        parser.add_argument(
            '--port',
            type=int,
            default=8000,
            help='TCP port to free (default: 8000).',
        )
        parser.add_argument(
            '--force',
            action='store_true',
            help='Send SIGKILL immediately instead of SIGTERM.',
        )

    def handle(self, *args, **options):
        port = options['port']
        stopped = free_port(port, force=options['force'])
        if stopped:
            unique = sorted(set(stopped))
            self.stdout.write(
                self.style.SUCCESS(f'Freed port {port} (stopped PID(s): {", ".join(map(str, unique))}).')
            )
        else:
            self.stdout.write(self.style.SUCCESS(f'Port {port} is already free.'))
