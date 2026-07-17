from core.serializers import CamelCaseModelSerializer

from .models import AiChatMessage


class AiChatMessageSerializer(CamelCaseModelSerializer):
    class Meta:
        model = AiChatMessage
        fields = ('id', 'role', 'content', 'symbol', 'created_at')
        read_only_fields = fields
