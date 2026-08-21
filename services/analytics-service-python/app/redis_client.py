import json
import os

import redis

_client = None


def get_client():
    global _client

    if _client is None:
        redis_url = os.environ.get("REDIS_URL")

        if redis_url:
            _client = redis.from_url(redis_url)
        else:
            host = os.environ.get("REDIS_HOST", "localhost")
            port = int(os.environ.get("REDIS_PORT", "6379"))
            _client = redis.Redis(
                host=host,
                port=port,
                db=0,
                decode_responses=False,
            )

    return _client


def read_snapshot() -> dict | None:
    raw = get_client().get(
        os.environ.get("SNAPSHOT_KEY", "analytics:snapshot")
    )

    if raw is None:
        return None

    return json.loads(raw)


def write_snapshot(snapshot: dict) -> None:
    get_client().set(
        os.environ.get("SNAPSHOT_KEY", "analytics:snapshot"),
        json.dumps(snapshot),
    )