from __future__ import annotations

from datetime import datetime

import pytest
from fastapi.testclient import TestClient

from app import clock
from app.config import Settings
from app.main import create_app
from app.service import FamilyService

# 2026-10-26(월) 14:00 KST — 평일 낮
WEEKDAY_AFTERNOON = datetime(2026, 10, 26, 14, 0, tzinfo=clock.KST)


@pytest.fixture
def at():
    """테스트마다 시각을 고정합니다. at(datetime)으로 바꿀 수 있습니다."""
    clock.freeze_at(WEEKDAY_AFTERNOON)
    yield clock.freeze_at
    clock.freeze_at(None)


@pytest.fixture
def settings(tmp_path) -> Settings:
    return Settings(
        database_url=f"sqlite:///{tmp_path / 'test.db'}",
        hold_seconds=1800,
        reconfirm_seconds=86400,
        approval_timeout_seconds=180,
        caution_mode_hours=24,
        tick_seconds=3600,  # 테스트에서는 tick()을 직접 부릅니다
    )


@pytest.fixture
def app(settings, at):
    return create_app(settings)


@pytest.fixture
def client(app):
    with TestClient(app) as c:
        yield c


@pytest.fixture
def tick(app):
    return app.state.run_tick


def state(client) -> dict:
    r = client.get("/api/v1/state")
    assert r.status_code == 200, r.text
    return r.json()


def member(snapshot: dict, member_id: str) -> dict:
    return next(m for m in snapshot["members"] if m["id"] == member_id)


def request(snapshot: dict, request_id: str) -> dict:
    return next(r for r in snapshot["requests"] if r["id"] == request_id)


def start_caution(app, member_id: str = "senior", kind: str = "sms", summary: str = "위험 문자 감지") -> dict:
    with app.state.sessions() as s:
        svc = FamilyService(s, app.state.settings, app.state.fds, app.state.gateways, app.state.hub)
        res = svc.start_caution_mode(member_id, kind, summary)
        svc.commit()
        return res
