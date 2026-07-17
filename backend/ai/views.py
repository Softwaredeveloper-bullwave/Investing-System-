import logging

from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from django.conf import settings

from core.utils import camelize
from stocks.models import Stock, WatchlistItem

from .llm_service import LlmError, generate_stock_assistant_reply
from .mood_service import compute_market_mood
from .openai_voice_client import OpenAiVoiceError, openai_voice_configured, transcribe_audio_bytes
from .voice_service import VoiceError, get_voice_status, text_to_speech_bytes
from .models import AiChatMessage
from .serializers import AiChatMessageSerializer

DEFAULT_SUGGESTIONS = [
    'Show my portfolio summary',
    'What is in my watchlist?',
    'How do Goal Plans work?',
    'Explain my wallet balance',
    'How to buy a stock in this app?',
    'What are Featured Plans?',
    'Nifty outlook today',
    'What is P/E ratio?',
]

HISTORY_LIMIT = 6


class StockAssistantView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        message = request.data.get('message', '').strip()
        symbol = (request.data.get('symbol') or '').strip().upper()
        if not message:
            return Response({'detail': 'Message is required.'}, status=status.HTTP_400_BAD_REQUEST)

        user = request.user
        user_msg = AiChatMessage.objects.create(
            user=user,
            role=AiChatMessage.Role.USER,
            content=message,
            symbol=symbol,
        )

        recent = AiChatMessage.objects.filter(user=user).order_by('-created_at')[:HISTORY_LIMIT]
        history = [
            {'role': msg.role, 'content': msg.content}
            for msg in reversed(list(recent))
        ]

        try:
            reply_text = generate_stock_assistant_reply(
                user=user,
                message=message,
                symbol=symbol,
                history=history[:-1],
            )
        except LlmError as exc:
            user_msg.delete()
            return Response({'detail': str(exc)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        assistant_msg = AiChatMessage.objects.create(
            user=user,
            role=AiChatMessage.Role.ASSISTANT,
            content=reply_text,
            symbol=symbol,
        )

        return Response(
            {
                'role': assistant_msg.role,
                'content': assistant_msg.content,
                'symbol': assistant_msg.symbol,
                'time': assistant_msg.created_at,
                'id': assistant_msg.id,
            }
        )


class AiHistoryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        messages = AiChatMessage.objects.filter(user=request.user).order_by('created_at')
        return Response(AiChatMessageSerializer(messages, many=True).data)

    def delete(self, request):
        AiChatMessage.objects.filter(user=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class AiSuggestionsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        suggestions = list(DEFAULT_SUGGESTIONS)
        user = request.user

        from finance.views import _build_portfolio

        pf = _build_portfolio(user, refresh_stocks=False)
        if pf['holdings_count']:
            prompt = 'Summarize my stock portfolio'
            if prompt not in suggestions:
                suggestions.insert(0, prompt)

        watchlist = (
            WatchlistItem.objects.filter(user=user)
            .select_related('stock')
            .order_by('-added_at')[:2]
        )
        for item in watchlist:
            prompt = f'Latest view on {item.stock.symbol}?'
            if prompt not in suggestions:
                suggestions.insert(0, prompt)

        trending = Stock.objects.order_by('-volume')[:2]
        for stock in trending:
            prompt = f'Why is {stock.symbol} moving today?'
            if prompt not in suggestions:
                suggestions.append(prompt)

        return Response({'suggestions': suggestions[:8], 'generatedAt': timezone.now()})


class AiTextToSpeechView(APIView):
    """Convert AI reply text to speech (OpenAI TTS, ElevenLabs fallback)."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        text = (request.data.get('text') or '').strip()
        if not text:
            return Response({'detail': 'Text is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            audio = text_to_speech_bytes(text)
        except VoiceError as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        from django.http import HttpResponse

        response = HttpResponse(audio, content_type='audio/mpeg')
        response['Content-Disposition'] = 'inline; filename="bullwave-ai.mp3"'
        return response


class AiSpeechToTextView(APIView):
    """Transcribe recorded audio via OpenAI Whisper."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        if not openai_voice_configured():
            return Response(
                {'detail': 'OpenAI STT not configured. Add OPENAI_API_KEY to backend/.env.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        upload = request.FILES.get('audio') or request.FILES.get('file')
        if upload is None:
            return Response({'detail': 'Audio file is required (field: audio).'}, status=status.HTTP_400_BAD_REQUEST)

        max_bytes = getattr(settings, 'OPENAI_STT_MAX_BYTES', 25 * 1024 * 1024)
        if upload.size > max_bytes:
            return Response({'detail': 'Audio file too large (max 25 MB).'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            text = transcribe_audio_bytes(
                upload.read(),
                filename=upload.name or 'speech.m4a',
                mime=upload.content_type or 'audio/mp4',
            )
        except OpenAiVoiceError as exc:
            return Response({'detail': str(exc)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        return Response({'text': text})


class AiVoiceStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(get_voice_status())


class MarketMoodView(APIView):
    """AI Mood Detector — Fear/Greed-style market mood gauge.

    Always returns a deterministic score (index move + market breadth) so the
    feature works with no AI provider configured; adds an AI one-liner on top
    when a provider is available.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        with_ai = request.query_params.get('ai', '1') != '0'
        try:
            mood = compute_market_mood(with_ai_commentary=with_ai)
        except Exception:
            logging.getLogger('bullwave.ai').exception('Market mood computation failed')
            return Response(
                {'detail': 'Could not compute market mood right now.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        return Response(camelize(mood))
