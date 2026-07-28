"""Root-logger handler that mirrors WARNING+ log records into the DB so
they're visible from the admin panel's Logs page (see `core.models.SystemLog`
and `adminpanel.views.AdminLogsView`), not just via `journalctl` on the
server.

Wired up in `backend/settings.py`'s LOGGING['root'] handlers, so this
receives every WARNING+ record from any logger in the project that doesn't
explicitly disable propagation — including `bullwave.errors` (unhandled DRF
exceptions, see `core/exception_handler.py`), `bullwave.kyc`,
`bullwave.payments`, `bullwave.market`, plain Django `django.request`
errors, etc.
"""

from __future__ import annotations

import logging


class DatabaseLogHandler(logging.Handler):
    def emit(self, record: logging.LogRecord) -> None:
        # Guard against recursion (a DB error while logging a DB error would
        # otherwise loop forever) and against firing before migrations have
        # run / the app registry is ready (e.g. during `manage.py migrate`
        # itself, or very early startup).
        if getattr(record, '_from_db_log_handler', False):
            return

        try:
            from django.apps import apps

            if not apps.ready:
                return

            from .models import SystemLog

            path = getattr(record, 'request_path', '') or ''
            method = getattr(record, 'request_method', '') or ''
            request = getattr(record, 'request', None)
            if request is not None:
                path = path or getattr(request, 'path', '')
                method = method or getattr(request, 'method', '')

            SystemLog.objects.create(
                level=record.levelname if record.levelname in dict(SystemLog.Level.choices) else 'ERROR',
                logger_name=record.name,
                message=self.format(record),
                traceback=self._format_exception(record),
                path=path[:500],
                method=method[:10],
            )
        except Exception:
            # Never let logging itself crash the request/process.
            logging.getLogger(__name__).error(
                'DatabaseLogHandler failed to persist a log record',
                exc_info=True,
                extra={'_from_db_log_handler': True},
            )

    @staticmethod
    def _format_exception(record: logging.LogRecord) -> str:
        if record.exc_info:
            return logging.Formatter().formatException(record.exc_info)
        return ''
