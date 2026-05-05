"""Load generator: fire N requests across the endpoints to produce telemetry.

Usage
-----
    uv run python scripts/load.py [--n N] [--base URL] [--concurrency C]

Defaults to ``--n 200`` against ``http://localhost:8000``. It spreads requests
across ``/``, ``/health``, ``/work`` (random sleep) and ``/flaky`` (~20%% 5xx),
which is exactly what the Grafana golden-signals dashboard needs to light up.
"""

from __future__ import annotations

import argparse
import asyncio
import random
from collections import Counter

import httpx

ENDPOINTS = ["/", "/health", "/work", "/flaky"]


def _build_request(base: str) -> str:
    """Pick a weighted-random endpoint URL for one request."""
    path = random.choices(ENDPOINTS, weights=[1, 1, 3, 3], k=1)[0]
    if path == "/work":
        return f"{base}/work?ms={random.randint(5, 400)}"
    return f"{base}{path}"


async def _worker(
    client: httpx.AsyncClient,
    queue: asyncio.Queue[str],
    tally: Counter[int],
) -> None:
    while True:
        try:
            url = queue.get_nowait()
        except asyncio.QueueEmpty:
            return
        try:
            resp = await client.get(url)
            tally[resp.status_code] += 1
        except httpx.HTTPError:
            tally[0] += 1
        finally:
            queue.task_done()


async def run(base: str, n: int, concurrency: int) -> Counter[int]:
    """Fire ``n`` requests with ``concurrency`` workers; return status-code tally."""
    queue: asyncio.Queue[str] = asyncio.Queue()
    for _ in range(n):
        queue.put_nowait(_build_request(base))

    tally: Counter[int] = Counter()
    async with httpx.AsyncClient(timeout=15.0) as client:
        workers = [asyncio.create_task(_worker(client, queue, tally)) for _ in range(concurrency)]
        await asyncio.gather(*workers)
    return tally


def main() -> None:
    parser = argparse.ArgumentParser(description="observatory sample-service load generator")
    parser.add_argument("--base", default="http://localhost:8000", help="service base URL")
    parser.add_argument("--n", type=int, default=200, help="total number of requests")
    parser.add_argument("--concurrency", type=int, default=10, help="concurrent workers")
    args = parser.parse_args()

    tally = asyncio.run(run(args.base, args.n, args.concurrency))

    total = sum(tally.values())
    print(f"sent {total} requests to {args.base}")
    for code in sorted(tally):
        label = "connection-error" if code == 0 else str(code)
        print(f"  {label}: {tally[code]}")


if __name__ == "__main__":
    main()
