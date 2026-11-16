from __future__ import annotations

import json
from datetime import timedelta

from app import clock

from .conftest import member, request, state


def test_seed_members_start_paired_and_consented(client):
    snap = state(client)
    for mid in ("senior", "child"):
        m = member(snap, mid)
        assert m["paired_at"] is not None
        assert m["consent_at"] is not None


def test_pairing_code_issue_and_connect_records_timestamps_and_emits_event(client):
    issue = client.post(
        "/api/v1/guardian/pairing-code",
        json={"guardian_id": "guardian", "member_id": "senior"},
    )
    assert issue.status_code == 200, issue.text
    issued = issue.json()
    code = issued["code"]
    assert len(code) == 6
    assert issued["qr_value"] == code
    assert issued["expires_in_seconds"] == 300

    clock.advance(timedelta(seconds=30))
    connected_at = clock.now()

    with client.websocket_connect("/api/v1/ws") as ws:
        assert ws.receive_json()["type"] == "hello"
        res = client.post(
            "/api/v1/pairing/connect",
            json={"member_id": "senior", "code": code, "consented": True},
        )
        assert res.status_code == 200, res.text
        body = res.json()
        assert body["status"] == "connected"
        assert body["paired_at"].startswith(connected_at.isoformat()[:19])
        assert body["consent_at"].startswith(connected_at.isoformat()[:19])
        ev = ws.receive_json()
        assert ev["type"] == "pairing"
        assert ev["member_id"] == "senior"

    senior = member(state(client), "senior")
    assert senior["paired_at"].startswith(connected_at.isoformat()[:19])
    assert senior["consent_at"].startswith(connected_at.isoformat()[:19])
    assert senior["ledger"][0]["title"] == "보호자 연결"

    # 같은 코드는 한 번만 쓸 수 있습니다
    reused = client.post(
        "/api/v1/pairing/connect",
        json={"member_id": "senior", "code": code, "consented": True},
    )
    assert reused.status_code == 409
    assert reused.json()["error"]["code"] == "code-used"


def test_pairing_connect_requires_consent_without_consuming_code(client):
    code = client.post(
        "/api/v1/guardian/pairing-code",
        json={"guardian_id": "guardian", "member_id": "senior"},
    ).json()["code"]
    before = member(state(client), "senior")["paired_at"]

    denied = client.post(
        "/api/v1/pairing/connect",
        json={"member_id": "senior", "code": code, "consented": False},
    )
    assert denied.status_code == 400
    assert denied.json()["error"]["code"] == "consent-required"
    assert member(state(client), "senior")["paired_at"] == before

    # 동의 없이 시도한 뒤에도 같은 코드로 동의하면 정상 연결됩니다
    ok = client.post(
        "/api/v1/pairing/connect",
        json={"member_id": "senior", "code": code, "consented": True},
    )
    assert ok.status_code == 200


def test_pairing_connect_rejects_invalid_wrong_member_and_expired_codes(client):
    code = client.post(
        "/api/v1/guardian/pairing-code",
        json={"guardian_id": "guardian", "member_id": "senior"},
    ).json()["code"]

    wrong_code = client.post(
        "/api/v1/pairing/connect",
        json={"member_id": "senior", "code": "000000", "consented": True},
    )
    assert wrong_code.status_code == 400
    assert wrong_code.json()["error"]["code"] == "invalid-code"

    wrong_member = client.post(
        "/api/v1/pairing/connect",
        json={"member_id": "child", "code": code, "consented": True},
    )
    assert wrong_member.status_code == 400
    assert wrong_member.json()["error"]["code"] == "invalid-code"

    non_guardian = client.post(
        "/api/v1/guardian/pairing-code",
        json={"guardian_id": "senior", "member_id": "senior"},
    )
    assert non_guardian.status_code == 403

    clock.advance(timedelta(seconds=301))
    expired = client.post(
        "/api/v1/pairing/connect",
        json={"member_id": "senior", "code": code, "consented": True},
    )
    assert expired.status_code == 400
    assert expired.json()["error"]["code"] == "code-expired"


def test_incident_summary_has_chronological_items_without_raw_sms_or_call_text(client):
    raw_sms_secret = "RAW_SMS_TEXT_SECRET_9911"
    raw_call_secret = "RAW_CALL_TEXT_SECRET_8822"

    r_sms = client.post(
        "/api/v1/sms/receive",
        json={
            "member_id": "senior",
            "sender_phone": "02-0000-1332",
            "sender_name": "금융감독원(사칭)",
            "body": f"[금융감독원] {raw_sms_secret} 대포통장 사건 접수 http://fss-verify.invalid/case/1",
        },
    )
    assert r_sms.status_code == 200
    assert r_sms.json()["verdict"]["level"] == "danger"

    clock.advance(timedelta(minutes=2))
    call_id = client.post(
        "/api/v1/calls/start",
        json={"caller_id": "senior", "callee_id": "counterpart", "peer_phone": "02-0000-1332"},
    ).json()["call"]["id"]
    client.post(f"/api/v1/calls/{call_id}/answer")
    r_tx = client.post(
        f"/api/v1/calls/{call_id}/transcript",
        json={"text": f"여기는 금융감독원 조사관입니다. {raw_call_secret} 지금 당장 적금을 만기 전 해지하고 안전계좌로 이체하세요."},
    )
    assert r_tx.status_code == 200
    assert r_tx.json()["verdict"]["level"] == "danger"
    client.post(f"/api/v1/calls/{call_id}/end")

    clock.advance(timedelta(minutes=2))
    r_sav = client.post(
        "/api/v1/banking/savings/cancel",
        json={
            "member_id": "senior",
            "account_id": "acc-senior-2",
            "question_answer": "금융감독원·검찰·은행 직원이 해지하라고 했어요",
        },
    )
    assert r_sav.status_code == 200
    req_id = r_sav.json()["request"]["id"]

    clock.advance(timedelta(minutes=1))
    client.post(
        "/api/v1/guardian/callback-decision",
        json={"transaction_id": req_id, "guardian_id": "guardian", "decision": "EXTEND"},
    )
    clock.advance(timedelta(minutes=1))
    client.post(
        "/api/v1/guardian/callback-decision",
        json={"transaction_id": req_id, "guardian_id": "guardian", "decision": "RELEASE"},
    )
    clock.advance(timedelta(minutes=1))
    client.post(
        "/api/v1/security/caution-mode/release",
        json={"member_id": "senior", "guardian_id": "guardian"},
    )

    snap = state(client)
    assert len(snap["incidents"]) == 1
    inc = snap["incidents"][0]
    assert inc["status"] == "closed"
    kinds = [item["kind"] for item in inc["items"]]
    assert {"sms", "call", "action", "answer", "judgment", "hold", "guardian"} <= set(kinds)
    times = [item["at"] for item in inc["items"]]
    assert times == sorted(times)

    for item in inc["items"]:
        assert raw_sms_secret not in item["summary"]
        assert raw_call_secret not in item["summary"]
        dumped_detail = json.dumps(item["detail"], ensure_ascii=False)
        assert raw_sms_secret not in dumped_detail
        assert raw_call_secret not in dumped_detail


def test_guardian_receives_realtime_and_mock_push_for_sms_call_hold_and_reconfirm(client, tick):
    with client.websocket_connect("/api/v1/ws") as ws:
        assert ws.receive_json()["type"] == "hello"

        # 1. 위험 문자
        client.post("/api/v1/sms/receive", json={"member_id": "senior", "kind": "phishing"})
        sms_ws = [ws.receive_json(), ws.receive_json()]
        assert {"caution_mode", "sms"} <= {e["type"] for e in sms_ws}

        # 2. 위험 통화
        call_id = client.post(
            "/api/v1/calls/start",
            json={"caller_id": "senior", "callee_id": "counterpart", "peer_phone": "02-0000-1332"},
        ).json()["call"]["id"]
        ws.receive_json()  # call ringing
        client.post(
            f"/api/v1/calls/{call_id}/transcript",
            json={"text": "금융감독원입니다. 지금 당장 적금을 만기 전 해지하고 안전계좌로 이체하세요."},
        )
        call_ws = [ws.receive_json(), ws.receive_json()]
        assert {"caution_mode", "call_warning"} <= {e["type"] for e in call_ws}

        # 3. 보류
        r_hold = client.post(
            "/api/v1/transaction/transfer",
            json={
                "member_id": "senior",
                "new_account": {"bank": "국민", "number": "12345678907788", "name": "이정민"},
                "amount": 500000,
                "question_answer": "금융감독원·검찰·수사관이 안전계좌로 보내라고 했어요",
            },
        )
        assert r_hold.json()["status"] == "pending"
        hold_ev = ws.receive_json()
        assert hold_ev["type"] == "request"

        # 4. 30분 경과 후 본인 재확인 대기 전환
        clock.advance(timedelta(seconds=1801))
        tick()
        reconfirm_ev = ws.receive_json()
        assert reconfirm_ev["type"] == "reconfirm"

    snap = state(client)
    assert any(a["status"] == "danger" and "문자" in a["title"] for a in snap["alerts"])
    assert any(a["status"] == "danger" and "통화 경고" in a["title"] for a in snap["alerts"])
    assert any(a["status"] == "reconfirm" for a in snap["alerts"])

    logs = client.get("/api/v1/integrations/logs").json()["logs"]
    fcm_messages = [l["message"] for l in logs if l["channel"] == "FCM"]
    assert any("위험 문자 경고" in m for m in fcm_messages)
    assert any("긴급 통화 경고" in m for m in fcm_messages)
    assert any("거래 보류 알림" in m for m in fcm_messages)
    assert any("본인 재확인 대기" in m for m in fcm_messages)


def test_hold_request_records_originating_incident_id_and_none_outside_caution_mode(client):
    # 1. 주의 모드 밖에서 만들어진 보류는 사건 ID가 없습니다.
    outside = client.post(
        "/api/v1/transaction/transfer",
        json={
            "member_id": "senior",
            "new_account": {"bank": "국민", "number": "12345678907788", "name": "이정민"},
            "amount": 500000,
        },
    )
    assert outside.status_code == 200, outside.text
    assert outside.json()["status"] == "pending"
    outside_req = outside.json()["request"]
    assert outside_req["incident_id"] is None

    # 2. 주의 모드 중 만들어진 보류는 그 시점의 사건 ID를 기록합니다.
    client.post("/api/v1/sms/receive", json={"member_id": "senior", "kind": "phishing"})
    inc_first = member(state(client), "senior")["active_incident"]["id"]

    hold_res = client.post(
        "/api/v1/banking/savings/cancel",
        json={
            "member_id": "senior",
            "account_id": "acc-senior-2",
            "question_answer": "금융감독원·검찰·은행 직원이 해지하라고 했어요",
        },
    )
    assert hold_res.status_code == 200, hold_res.text
    hold_req = hold_res.json()["request"]
    assert hold_req["incident_id"] == inc_first

    # 3. 주의 모드가 종료되고 새 사건이 열려도 보류 요청은 원래 사건 ID를 유지합니다.
    clock.advance(timedelta(minutes=1))
    client.post("/api/v1/security/caution-mode/release", json={"member_id": "senior", "guardian_id": "guardian"})
    clock.advance(timedelta(minutes=1))
    client.post("/api/v1/sms/receive", json={"member_id": "senior", "kind": "phishing"})
    inc_second = member(state(client), "senior")["active_incident"]["id"]
    assert inc_second != inc_first

    snap = state(client)
    assert request(snap, outside_req["id"])["incident_id"] is None
    assert request(snap, hold_req["id"])["incident_id"] == inc_first
