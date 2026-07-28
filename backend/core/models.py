import uuid

from django.conf import settings
from django.db import models


class SystemLog(models.Model):
    """Every WARNING+ log record anywhere in the backend lands here (see
    `core.log_handler.DatabaseLogHandler`, wired up as the root logger's
    handler in `backend/settings.py`) so it can be reviewed from the admin
    panel's Logs page instead of only being visible via `journalctl` on the
    server.
    """

    class Level(models.TextChoices):
        DEBUG = 'DEBUG', 'Debug'
        INFO = 'INFO', 'Info'
        WARNING = 'WARNING', 'Warning'
        ERROR = 'ERROR', 'Error'
        CRITICAL = 'CRITICAL', 'Critical'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    level = models.CharField(max_length=10, choices=Level.choices, default=Level.ERROR)
    logger_name = models.CharField(max_length=150, blank=True)
    message = models.TextField()
    traceback = models.TextField(blank=True)
    path = models.CharField(max_length=500, blank=True)
    method = models.CharField(max_length=10, blank=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='+',
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['-created_at']),
            models.Index(fields=['level']),
        ]

    def __str__(self):
        return f'[{self.level}] {self.logger_name}: {self.message[:80]}'
