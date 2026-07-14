from collections import defaultdict, deque
from time import monotonic

from fastapi import HTTPException, Request, status

from app.core.config import settings


class InMemoryRateLimiter:
    def __init__(self, max_requests: int, window_seconds: int) -> None:
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._requests: dict[str, deque[float]] = defaultdict(deque)

    def check(self, key: str) -> None:
        now = monotonic()
        requests = self._requests[key]
        while requests and now - requests[0] >= self.window_seconds:
            requests.popleft()

        if len(requests) >= self.max_requests:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many join attempts. Please try again later.",
            )

        requests.append(now)


join_rate_limiter = InMemoryRateLimiter(
    max_requests=settings.join_rate_limit_requests,
    window_seconds=settings.join_rate_limit_window_seconds,
)


def limit_join_by_ip(request: Request) -> None:
    client_host = request.client.host if request.client else "unknown"
    join_rate_limiter.check(client_host)
