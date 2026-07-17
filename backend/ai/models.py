from django.conf import settings
from django.db import models


class AiChatMessage(models.Model):
    class Role(models.TextChoices):
        USER = 'user', 'User'
        ASSISTANT = 'assistant', 'Assistant'

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='ai_messages',
    )
    role = models.CharField(max_length=12, choices=Role.choices)
    content = models.TextField()
    symbol = models.CharField(max_length=20, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']
        indexes = [models.Index(fields=['user', 'created_at'])]

    def __str__(self):
        return f'{self.user_id} {self.role}: {self.content[:40]}'
