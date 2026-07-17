from django.urls import path

from .views import (
    AiHistoryView,
    AiSpeechToTextView,
    AiSuggestionsView,
    AiTextToSpeechView,
    AiVoiceStatusView,
    MarketMoodView,
    StockAssistantView,
)

urlpatterns = [
    path('ai/stock-assistant/', StockAssistantView.as_view(), name='ai-stock-assistant'),
    path('ai/history/', AiHistoryView.as_view(), name='ai-history'),
    path('ai/suggestions/', AiSuggestionsView.as_view(), name='ai-suggestions'),
    path('ai/tts/', AiTextToSpeechView.as_view(), name='ai-tts'),
    path('ai/stt/', AiSpeechToTextView.as_view(), name='ai-stt'),
    path('ai/voice/status/', AiVoiceStatusView.as_view(), name='ai-voice-status'),
    path('ai/market-mood/', MarketMoodView.as_view(), name='ai-market-mood'),
]
