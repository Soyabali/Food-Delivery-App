import threading
import time
from collections import defaultdict, deque


class RateLimiter:
    """Sliding-window limit of `limit` hits per `window_seconds` per key.

    Kept in memory, so each server process counts on its own and counts reset
    on restart. That is enough to stop scripted guessing against one server;
    use a shared store (e.g. Redis) when running several processes.
    """

    def __init__(self, limit: int, window_seconds: int):
        self.limit = limit
        self.window = window_seconds
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def allow(self, key: str) -> bool:
        now = time.monotonic()
        with self._lock:
            hits = self._hits[key]
            while hits and now - hits[0] > self.window:
                hits.popleft()
            if len(hits) >= self.limit:
                return False
            hits.append(now)
            return True

    def reset(self) -> None:
        with self._lock:
            self._hits.clear()
