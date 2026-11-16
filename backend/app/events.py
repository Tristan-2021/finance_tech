"""실시간 이벤트 허브. 연결된 앱(WebSocket)에 상태 변경을 알립니다.

앱은 이벤트를 받으면 /api/v1/state를 다시 불러옵니다. 이벤트의 message는
다른 기기에서 토스트로 보여 줄 문구입니다.
"""

from __future__ import annotations

import asyncio
import json
import logging
import threading
from typing import Any

from fastapi import WebSocket

log = logging.getLogger("fingerbell.events")

ALLOWED_RTC_SIGNAL_TYPES: frozenset[str] = frozenset({"ready", "offer", "answer", "ice"})


class EventHub:
    def __init__(self) -> None:
        self._clients: set[WebSocket] = set()
        self._loop: asyncio.AbstractEventLoop | None = None
        self._lock = threading.Lock()
        self._seq = 0

    def bind_loop(self, loop: asyncio.AbstractEventLoop) -> None:
        self._loop = loop

    @property
    def client_count(self) -> int:
        return len(self._clients)

    async def connect(self, ws: WebSocket) -> None:
        await ws.accept()
        self._clients.add(ws)

    def disconnect(self, ws: WebSocket) -> None:
        self._clients.discard(ws)

    def publish(self, events: list[dict[str, Any]]) -> None:
        """어느 스레드에서 불러도 안전합니다 (동기 엔드포인트는 스레드 풀에서 실행됨)."""
        if not events or self._loop is None or self._loop.is_closed():
            return
        with self._lock:
            batch = []
            for e in events:
                self._seq += 1
                batch.append({**e, "seq": self._seq})
        try:
            running = asyncio.get_running_loop()
        except RuntimeError:
            running = None
        if running is self._loop:
            self._loop.create_task(self._broadcast(batch))
        else:
            asyncio.run_coroutine_threadsafe(self._broadcast(batch), self._loop)

    async def _broadcast(self, batch: list[dict[str, Any]]) -> None:
        dead = []
        for ws in list(self._clients):
            try:
                for e in batch:
                    await ws.send_text(json.dumps(e, ensure_ascii=False))
            except Exception:  # 끊긴 연결은 정리만 하고 넘어갑니다
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws)

    async def relay(self, sender: WebSocket, raw: str) -> None:
        """클라이언트가 보낸 통화 연결 신호(type='rtc_signal', signal_type='ready'|'offer'|'answer'|'ice')만 상대 기기에 전달합니다 (기획서 5.3)."""
        text = (raw or "").strip()
        if not text or text == "ping":
            return
        try:
            parsed = json.loads(text)
        except Exception:
            return
        if not isinstance(parsed, dict):
            return
        if parsed.get("type") != "rtc_signal" or parsed.get("signal_type") not in ALLOWED_RTC_SIGNAL_TYPES:
            return
        dead = []
        for ws in list(self._clients):
            if ws is sender:
                continue
            try:
                await ws.send_text(text)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws)
