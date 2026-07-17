"""Simple cache-based rate limiting for verification endpoints."""

from django.core.cache import cache


class RateLimitExceeded(Exception):
    pass


def check_rate_limit(key: str, limit: int = 10, window_seconds: int = 60) -> None:
    cache_key = f'ratelimit:{key}'
    count = cache.get(cache_key, 0)
    if count >= limit:
        raise RateLimitExceeded(f'Too many requests. Try again in {window_seconds} seconds.')
    cache.set(cache_key, count + 1, window_seconds)
