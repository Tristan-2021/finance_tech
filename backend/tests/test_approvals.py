from datetime import timedelta

from app import clock

from .conftest import member, request, start_caution, state

PHISHING = {"member_id": "senior", "new_account": {"bank": "국민", "number": "12345678907788", "name": "이정민"}, "amount": 500000}
CHILD_PHISHING = {"member_id": "child", "new_account": {"bank": "국민", "number": "12345678907788", "name": "이정민"}, "amount": 20000}


def hold(client, payload=None):
    r = client.post("/api/v1/transaction/transfer", json=payload or PHISHING)
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["status"] == "pending"
    return body["request"]["id"]


def decide(client, req_id, decision, guardian_id="guardian"):
    return client.post(
        "/api/v1/guardian/callback-decision",
        json={"transaction_id": req_id, "guardian_id": guardian_id, "decision": decision, "reason": "테스트"},
    )


def test_spec_request_approval_endpoint(client):
    r = client.post(
        "/api/v1/transaction/request-approval",
        json={
            "sender_id": "senior",
            "recipient_bank": "국민",
            "recipient_account": "12345678907788",
            "recipient_name": "이정민",
            "amount": 500000,
            "risk_score": 1,
            "risk_level": "safe",
            "risk_reasons": [],
        },
    )
    body = r.json()
    assert body["status"] == "PENDING_APPROVAL"
    assert body["hold_seconds"] == 1800
    assert body["risk_score"] >= 60  # 클라이언트가 보낸 점수가 아니라 서버가 다시 계산한 점수
    assert body["risk_level"] == "high"
    assert "처음 보내는 계좌예요" in body["explanation"]


def test_hold_transfer_executes_when_guardian_releases(client):
    before = member(state(client), "senior")["balance"]
    req_id = hold(client)
    snap = state(client)
    assert member(snap, "senior")["balance"] == before
    req = request(snap, req_id)
    assert req["risk"]["level"] == "high"
    assert req["expires_at"] is not None

    r = decide(client, req_id, "RELEASE")
    assert r.json()["status"] == "APPROVED"
    snap = state(client)
    assert member(snap, "senior")["balance"] == before - 500000
    assert member(snap, "senior")["notices"][0]["status"] == "approved"

    again = decide(client, req_id, "RELEASE")
    assert again.status_code == 409


def test_guardian_extends_hold_by_thirty_minutes(client, tick):
    req_id = hold(client)
    first_expires = request(state(client), req_id)["expires_at"]

    r = decide(client, req_id, "EXTEND")
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "EXTENDED"
    extended = request(state(client), req_id)
    assert extended["status"] == "pending"
    assert extended["expires_at"] > first_expires

    # 기본 30분이 지나도 연장된 30분이 남아 있으므로 아직 보류(pending) 상태입니다
    clock.advance(timedelta(minutes=35))
    tick()
    assert request(state(client), req_id)["status"] == "pending"


def test_member_can_cancel_hold_anytime(client):
    before = member(state(client), "senior")["balance"]
    req_id = hold(client)

    wrong_user = client.post("/api/v1/transaction/cancel", json={"request_id": req_id, "member_id": "child"})
    assert wrong_user.status_code == 403

    r = client.post("/api/v1/transaction/cancel", json={"request_id": req_id, "member_id": "senior"})
    assert r.status_code == 200
    assert r.json()["status"] == "CANCELLED"
    snap = state(client)
    assert request(snap, req_id)["status"] == "cancelled"
    assert member(snap, "senior")["balance"] == before

    # 이미 취소된 요청을 재확인하거나 보호자가 해제하려 하면 409이고 잔액은 그대로입니다
    reconfirm = client.post("/api/v1/transaction/reconfirm", json={"request_id": req_id, "member_id": "senior", "confirm": True})
    assert reconfirm.status_code == 409
    release = decide(client, req_id, "RELEASE")
    assert release.status_code == 409
    assert member(state(client), "senior")["balance"] == before


def test_reconfirmed_request_cannot_be_cancelled_afterwards(client, tick):
    before = member(state(client), "senior")["balance"]
    req_id = hold(client)
    clock.advance(timedelta(minutes=30, seconds=1))
    tick()

    proceed = client.post("/api/v1/transaction/reconfirm", json={"request_id": req_id, "member_id": "senior", "confirm": True})
    assert proceed.status_code == 200
    assert member(state(client), "senior")["balance"] == before - 500000

    cancel = client.post("/api/v1/transaction/cancel", json={"request_id": req_id, "member_id": "senior"})
    assert cancel.status_code == 409
    assert member(state(client), "senior")["balance"] == before - 500000


def test_reconfirm_deadline_is_anchored_to_original_hold_expiry_and_checked_before_execution(client, tick):
    before = member(state(client), "senior")["balance"]
    t0 = clock.now()
    req_id = hold(client)

    # 타이머 점검이 10분 늦게(40분 뒤) 돌아도 재확인 기한은 원래 보류 종료 시각(t0 + 30분) + 24시간입니다
    clock.advance(timedelta(minutes=40))
    tick()
    req = request(state(client), req_id)
    assert req["status"] == "reconfirm"
    expected_deadline = t0 + timedelta(minutes=30, hours=24)
    assert req["reconfirm_until"].startswith(expected_deadline.isoformat()[:16])

    # 타이머(tick)가 아직 돌지 않았어도 기한이 지났으면 reconfirm_hold가 직접 만료시키고 실행하지 않습니다
    clock.advance(timedelta(hours=23, minutes=50, seconds=1))
    late = client.post("/api/v1/transaction/reconfirm", json={"request_id": req_id, "member_id": "senior", "confirm": True})
    assert late.status_code == 409
    assert member(state(client), "senior")["balance"] == before
    tick()
    snap = state(client)
    assert request(snap, req_id)["status"] == "expired"
    assert member(snap, "senior")["balance"] == before


def test_payment_request_expires_after_three_minutes(client, tick):
    r = client.post("/api/v1/payments/request-approval", json={"member_id": "child", "merchant_id": "c-game"}).json()
    req_id = r["request"]["id"]
    clock.advance(timedelta(seconds=179))
    tick()
    assert request(state(client), req_id)["status"] == "pending"

    clock.advance(timedelta(seconds=2))
    tick()
    snap = state(client)
    assert request(snap, req_id)["status"] == "expired"
    assert member(snap, "child")["notices"][0]["status"] == "expired"


def test_unanswered_hold_enters_reconfirm_after_thirty_minutes_and_proceeds_on_confirm(client, tick):
    before = member(state(client), "senior")["balance"]
    req_id = hold(client)

    # 아직 30분이 지나지 않았으면 재확인으로 진행할 수 없습니다
    early = client.post("/api/v1/transaction/reconfirm", json={"request_id": req_id, "member_id": "senior", "confirm": True})
    assert early.status_code == 409

    clock.advance(timedelta(minutes=29, seconds=59))
    tick()
    assert request(state(client), req_id)["status"] == "pending"

    clock.advance(timedelta(seconds=2))
    tick()
    snap = state(client)
    req = request(snap, req_id)
    assert req["status"] == "reconfirm"
    assert req["reconfirm_until"] is not None
    assert member(snap, "senior")["balance"] == before  # 저절로 실행되지 않음

    proceed = client.post("/api/v1/transaction/reconfirm", json={"request_id": req_id, "member_id": "senior", "confirm": True})
    assert proceed.status_code == 200
    assert proceed.json()["status"] == "APPROVED"
    assert member(state(client), "senior")["balance"] == before - 500000


def test_reconfirm_stop_cancels_the_transfer(client, tick):
    before = member(state(client), "senior")["balance"]
    req_id = hold(client)
    clock.advance(timedelta(minutes=30, seconds=1))
    tick()
    assert request(state(client), req_id)["status"] == "reconfirm"

    stop = client.post("/api/v1/transaction/reconfirm", json={"request_id": req_id, "member_id": "senior", "confirm": False})
    assert stop.status_code == 200
    assert stop.json()["status"] == "CANCELLED"
    snap = state(client)
    assert request(snap, req_id)["status"] == "cancelled"
    assert member(snap, "senior")["balance"] == before


def test_reconfirm_expires_after_twenty_four_hours(client, tick):
    before = member(state(client), "senior")["balance"]
    req_id = hold(client)
    clock.advance(timedelta(minutes=30, seconds=1))
    tick()
    assert request(state(client), req_id)["status"] == "reconfirm"

    clock.advance(timedelta(hours=23, minutes=59))
    tick()
    assert request(state(client), req_id)["status"] == "reconfirm"

    clock.advance(timedelta(minutes=2))
    tick()
    snap = state(client)
    assert request(snap, req_id)["status"] == "expired"
    assert member(snap, "senior")["balance"] == before
    assert member(snap, "senior")["notices"][0]["status"] == "expired"


def test_child_hold_cannot_proceed_by_self_reconfirm(client, tick):
    before = member(state(client), "child")["balance"]
    req_id = hold(client, CHILD_PHISHING)
    clock.advance(timedelta(minutes=30, seconds=1))
    tick()

    attempt = client.post("/api/v1/transaction/reconfirm", json={"request_id": req_id, "member_id": "child", "confirm": True})
    assert attempt.status_code == 400
    assert attempt.json()["error"]["code"] == "role"
    assert member(state(client), "child")["balance"] == before

    # 보호자가 해제하면 실행됩니다
    released = decide(client, req_id, "RELEASE")
    assert released.status_code == 200
    assert released.json()["status"] == "APPROVED"
    assert member(state(client), "child")["balance"] == before - 20000


def test_caution_mode_start_extend_incident_log_and_guardian_release(app, client, tick):
    t0 = clock.now()
    b1 = start_caution(app, "senior", "sms", "기관 사칭 의심 문자 수신")
    assert b1["caution_mode"] is True
    assert b1["extended"] is False
    expected_first = t0 + timedelta(hours=24)
    assert b1["caution_until"].startswith(expected_first.isoformat()[:16])

    snap = state(client)
    senior = member(snap, "senior")
    assert senior["caution_mode"] is True
    assert senior["caution_until"].startswith(expected_first.isoformat()[:16])

    # 10시간 뒤 새 징후(통화)가 잡히면 그때부터 다시 24시간으로 연장되고 같은 사건에 시간순으로 쌓입니다
    clock.advance(timedelta(hours=10))
    t1 = clock.now()
    r2 = start_caution(app, "senior", "call", "통화 중 안전 계좌·적금 해지 요구 감지")
    assert r2["extended"] is True
    expected_extended = t1 + timedelta(hours=24)
    assert r2["caution_until"].startswith(expected_extended.isoformat()[:16])

    # 주의 모드 중 위험 송금을 시도하면 사건 기록에 행동·판정·보류가 시간순으로 남습니다
    clock.advance(timedelta(minutes=5))
    req_id = hold(client)
    inc = member(state(client), "senior")["active_incident"]
    assert [item["kind"] for item in inc["items"]] == ["sms", "call", "action", "judgment", "hold"]

    # 본인이 재확인 진행을 해도 주의 모드는 꺼지지 않습니다
    clock.advance(timedelta(minutes=31))
    tick()
    client.post("/api/v1/transaction/reconfirm", json={"request_id": req_id, "member_id": "senior", "confirm": True})
    assert member(state(client), "senior")["caution_mode"] is True

    # 본인은 주의 모드를 직접 해제할 수 없습니다
    self_release = client.post("/api/v1/security/caution-mode/release", json={"member_id": "senior", "guardian_id": "senior"})
    assert self_release.status_code == 403

    # 보호자는 주의 모드를 직접 끝낼 수 있습니다
    g_release = client.post("/api/v1/security/caution-mode/release", json={"member_id": "senior", "guardian_id": "guardian"})
    assert g_release.status_code == 200
    snap = state(client)
    assert member(snap, "senior")["caution_mode"] is False
    assert member(snap, "senior")["caution_until"] is None
    assert snap["incidents"][0]["status"] == "closed"
    assert snap["incidents"][0]["ended_by"] == "guardian"


def test_caution_mode_expires_automatically_after_twenty_four_hours(app, client, tick):
    start_caution(app, "senior", "sms", "위험 문자 감지")
    clock.advance(timedelta(hours=24, seconds=1))
    tick()
    snap = state(client)
    assert member(snap, "senior")["caution_mode"] is False
    assert snap["incidents"][0]["status"] == "closed"
    assert snap["incidents"][0]["ended_by"] == "system"


def test_approved_transfer_fails_if_frozen_meanwhile(client):
    # 동결은 대기 중 요청을 취소하므로, 결정 시점에는 이미 처리된 요청
    req_id = hold(client)
    client.post("/api/v1/security/sos-freeze", json={"user_id": "senior", "trigger_type": "LONG_PRESS"})
    assert decide(client, req_id, "APPROVE").status_code == 409


def test_dismiss_notice(client):
    req_id = hold(client)
    decide(client, req_id, "REJECT")
    notice = member(state(client), "senior")["notices"][0]
    client.post(f"/api/v1/members/senior/notices/{notice['id']}/dismiss")
    assert member(state(client), "senior")["notices"] == []
