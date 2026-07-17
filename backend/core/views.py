from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from .integrations.status import integration_status


class HealthView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        integrations = integration_status()
        all_critical = integrations['market_data']['configured']
        return Response(
            {
                'status': 'ok' if all_critical else 'degraded',
                'service': 'BullWave Capital API',
                'version': 'v1',
                'integrations': integrations,
            }
        )
