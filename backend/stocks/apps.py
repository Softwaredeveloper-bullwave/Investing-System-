import logging



from django.apps import AppConfig



logger = logging.getLogger('bullwave.market')





class StocksConfig(AppConfig):

    default_auto_field = 'django.db.models.BigAutoField'

    name = 'stocks'



    def ready(self):
        import hashlib

        from django.conf import settings
        from django.core.cache import cache

        from .quote_provider import active_provider

        token = _normalize_startup_token(
            (getattr(settings, 'KOTAK_NEO_ACCESS_TOKEN', '') or '').strip()
        )
        if token:
            fp = hashlib.sha256(token.encode()).hexdigest()[:16]
            if cache.get('kotak:token_fp') != fp:
                cache.delete('kotak:auth_failed')
                cache.set('kotak:token_fp', fp, 86400 * 7)

        provider = active_provider()
        kotak = bool(token)

        if provider == 'kotak_neo' and kotak:
            logger.info('Market data provider: Kotak Neo (live NSE/BSE quotes)')
            from .kotak_neo_client import _schedule_scrip_warm

            _schedule_scrip_warm()
        elif provider == 'finnhub':
            logger.info('Market data provider: Finnhub')
        elif provider == 'yahoo':
            logger.info('Market data provider: Yahoo Finance (fallback)')
        elif kotak:
            logger.info('Market data provider: Kotak Neo')
        else:
            logger.warning(
                'No live market API configured. Add KOTAK_NEO_ACCESS_TOKEN to backend/.env '
                '(Kotak Neo app → More → TradeAPI → API Dashboard)'
            )


def _normalize_startup_token(token):
    parts = token.split('-')
    if len(parts) == 5 and len(parts[4]) == 13:
        return '-'.join(parts[:4] + [parts[4][:12]])
    return token

