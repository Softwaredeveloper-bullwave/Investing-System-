from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path

from core.views import HealthView


def api_root(request):
    return JsonResponse(
        {
            'name': 'BullWave Capital API',
            'version': 'v1',
            'status': 'running',
            'endpoints': {
                'admin': request.build_absolute_uri('/admin/'),
                'api': request.build_absolute_uri('/api/v1/'),
                'auth_send_otp': request.build_absolute_uri('/api/v1/auth/send-otp/'),
                'auth_verify_otp': request.build_absolute_uri('/api/v1/auth/verify-otp/'),
            },
            'note': (
                'This page only shows API info. OTP is NOT shown here. '
                'Use the Flutter app (Login → Continue) or POST to auth_send_otp with '
                '{"phone":"9876543210"}. In DEBUG mode, OTP appears in the Django '
                'terminal and in the JSON field "devOtp".'
            ),
        }
    )


urlpatterns = [
    path('', api_root, name='api-root'),
    path('health/', HealthView.as_view(), name='health'),
    path('admin/', admin.site.urls),
    path('api/v1/', include('accounts.urls')),
    path('api/v1/', include('kyc.urls')),
    path('api/v1/', include('payments.urls')),
    path('api/v1/', include('finance.urls')),
    path('api/v1/', include('stocks.urls')),
    path('api/v1/', include('engagement.urls')),
    path('api/v1/', include('education.urls')),
    path('api/v1/', include('ai.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
