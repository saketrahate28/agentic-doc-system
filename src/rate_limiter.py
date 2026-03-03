"""
DEMO-4: Rate Limiting Module
Implements per-user and per-IP rate limiting for the auth service.
"""

import time
import hashlib
from collections import defaultdict
from typing import Optional


class RateLimiter:
    """Token bucket rate limiter for API endpoints."""

    def __init__(self, max_requests: int = 10, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._buckets: dict = defaultdict(list)

    def is_allowed(self, identifier: str) -> bool:
        """Check if a request is allowed for the given identifier."""
        now = time.time()
        window_start = now - self.window_seconds

        # Remove expired timestamps
        self._buckets[identifier] = [
            ts for ts in self._buckets[identifier] if ts > window_start
        ]

        if len(self._buckets[identifier]) < self.max_requests:
            self._buckets[identifier].append(now)
            return True
        return False

    def get_retry_after(self, identifier: str) -> int:
        """Return seconds until the oldest request expires."""
        if not self._buckets[identifier]:
            return 0
        oldest = self._buckets[identifier][0]
        return max(0, int(self.window_seconds - (time.time() - oldest)))

    def reset(self, identifier: str) -> None:
        """Reset the rate limit bucket for an identifier."""
        self._buckets.pop(identifier, None)


def get_user_key(user_id: int, endpoint: str) -> str:
    """Generate a unique rate limit key for user + endpoint combo."""
    return hashlib.md5(f"{user_id}:{endpoint}".encode()).hexdigest()


def get_ip_key(ip_address: str) -> str:
    """Generate a rate limit key for an IP address."""
    return f"ip:{ip_address}"
