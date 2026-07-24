"""Global DRF exception handler.

Without this, any bug that raises an exception DRF doesn't recognize (a raw
Django `OperationalError`, `TypeError`, `AttributeError`, etc. — e.g. from a
missing migration column, a None value reaching arithmetic, ...) bypasses
DRF's JSON error formatting entirely. Django then renders its HTML debug
page (DEBUG=True) or the plain HTML 500.html (DEBUG=False) instead of JSON.

The Flutter client expects a JSON body and falls back to a generic
"Server error. Is Django running on port 8000?" message when it can't parse
the response — which is confusing because it looks like a connectivity
problem when it's actually an unhandled server-side bug. This handler
guarantees every DRF view always returns valid JSON, so the real `detail`
message (or at least a clear "something went wrong" message) reaches the
user instead of a raw parse failure.
"""

import logging

from rest_framework.response import Response
from rest_framework.views import exception_handler as drf_exception_handler

logger = logging.getLogger('bullwave.errors')


def custom_exception_handler(exc, context):
    response = drf_exception_handler(exc, context)
    if response is not None:
        return response

    # DRF didn't recognize this exception (not an APIException/Http404/etc.) —
    # it's an unexpected bug. Log the full traceback server-side and still
    # return a valid JSON response so the client can show a sane message.
    view = context.get('view')
    logger.exception(
        'Unhandled exception in %s: %s',
        getattr(view, '__class__', type(view)).__name__ if view else 'unknown view',
        exc,
    )
    return Response(
        {'detail': 'Something went wrong on our end. Please try again.'},
        status=500,
    )
