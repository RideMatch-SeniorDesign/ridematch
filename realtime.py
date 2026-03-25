from __future__ import annotations

import os
from decimal import Decimal
from datetime import date, datetime
from typing import Any

import socketio


def realtime_server_url() -> str:
    return os.environ.get("REALTIME_SERVER_URL", "http://127.0.0.1:8002").rstrip("/")


def realtime_public_url() -> str:
    return os.environ.get("REALTIME_SERVER_PUBLIC_URL", realtime_server_url()).rstrip("/")


def realtime_client_script_url() -> str:
    return f"{realtime_public_url()}/socket.io/socket.io.js"


def publish_trip_event(event_name: str, trip: dict[str, Any] | None) -> None:
    if not trip:
        return

    def _json_safe(value: Any):
        if isinstance(value, Decimal):
            return float(value)
        if isinstance(value, (datetime, date)):
            return value.isoformat()
        if isinstance(value, dict):
            return {key: _json_safe(item) for key, item in value.items()}
        if isinstance(value, list):
            return [_json_safe(item) for item in value]
        return value

    client = socketio.Client(reconnection=False, logger=False, engineio_logger=False)
    try:
        client.connect(realtime_server_url(), wait_timeout=2)
        client.emit(
            "publish_trip_event",
            {
                "event": event_name,
                "trip": _json_safe(trip),
            },
        )
    finally:
        try:
            client.disconnect()
        except Exception:
            pass
