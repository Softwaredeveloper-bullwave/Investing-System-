"""Price alert checking against live market quotes."""

import logging

from engagement.models import Notification

from .quote_provider import FinnhubError, get_quote
from .models import PriceAlert

logger = logging.getLogger('bullwave.market')


def process_price_alerts() -> int:
    """Check active alerts; create notifications when triggered. Returns count triggered."""
    triggered = 0
    alerts = PriceAlert.objects.filter(is_active=True).select_related('stock', 'user')

    for alert in alerts:
        symbol = alert.stock.symbol
        try:
            quote = get_quote(symbol)
        except FinnhubError as exc:
            logger.warning('Alert check skip %s: %s', symbol, exc)
            continue

        if not quote:
            continue

        ltp = quote['ltp']
        hit = (
            alert.condition == PriceAlert.Condition.ABOVE and ltp >= float(alert.target_price)
        ) or (
            alert.condition == PriceAlert.Condition.BELOW and ltp <= float(alert.target_price)
        )

        if not hit:
            continue

        alert.is_active = False
        alert.save(update_fields=['is_active'])

        Notification.objects.create(
            user=alert.user,
            title=f'Price Alert: {symbol}',
            message=(
                f'{symbol} hit ₹{ltp:,.2f} '
                f'({"above" if alert.condition == PriceAlert.Condition.ABOVE else "below"} '
                f'₹{alert.target_price}).'
            ),
            type='alert',
        )
        triggered += 1

    return triggered
