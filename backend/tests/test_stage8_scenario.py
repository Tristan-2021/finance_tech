"""9절 대표 시나리오 전체 종단(E2E) 서버 통합 테스트."""

from __future__ import annotations

from datetime import timedelta

from app import clock
from app.domain.call import CALL_SCRIPTS

from .conftest import member, request, state


def test_full_representative_scenario_end_to_end(client, tick):
    # 1. 사칭 문자 수신 → 주의 모드(24시간) 시작 + 사건 요약 기록
    r_sms = client.post("/api/v1/sms/receive", json={"member_id": "senior", "kind": "phishing"})
    assert r_sms.status_code == 200, r_sms.text
    sms_body = r_sms.json()
    assert sms_body["verdict"]["level"] == "danger"
    assert sms_body["caution_mode"] is True
    phone_in_sms = sms_body["message"]["phones"][0]

    # 2. 문자에 적힌 번호로 통화 연결 → 사기 대본 수신 → 위험 경고 · 주의 모드 연장 · 보호자 알림
    clock.advance(timedelta(minutes=5))
    r_start = client.post(
        "/api/v1/calls/start",
        json={"caller_id": "senior", "callee_id": "counterpart", "peer_phone": phone_in_sms},
    )
    assert r_start.status_code == 200, r_start.text
    call_id = r_start.json()["call"]["id"]

    r_ans = client.post(f"/api/v1/calls/{call_id}/answer")
    assert r_ans.status_code == 200
    assert r_ans.json()["call"]["status"] == "active"

    for line in CALL_SCRIPTS["phishing"].lines[:2]:
        r_tx = client.post(f"/api/v1/calls/{call_id}/transcript", json={"text": line})
        assert r_tx.status_code == 200, r_tx.text
        assert r_tx.json()["verdict"]["level"] == "danger"
        assert r_tx.json()["caution_mode"] is True

    r_end = client.post(f"/api/v1/calls/{call_id}/end")
    assert r_end.status_code == 200
    assert r_end.json()["call"]["status"] == "ended"

    # 3. 통화 뒤 적금 만기 전 해지 시도 → AI 확인 질문 화면 반환
    clock.advance(timedelta(minutes=5))
    r_q = client.post(
        "/api/v1/banking/savings/cancel",
        json={"member_id": "senior", "account_id": "acc-senior-2"},
    )
    assert r_q.status_code == 200, r_q.text
    q_body = r_q.json()
    assert q_body["status"] == "question"
    assert q_body["question"]["options"]
    assert any("잘 모르겠어요" in opt for opt in q_body["question"]["options"])

    # 4. 확인 질문 응답(사기 유도 정황 답 선택) → 종합 판정 위험 → 30분 보류 + 보호자 알림
    coerced_opt = next(
        (opt for opt in q_body["question"]["options"] if "금융감독원" in opt or "검찰" in opt or "직원" in opt),
        q_body["question"]["options"][0],
    )
    r_hold = client.post(
        "/api/v1/banking/savings/cancel",
        json={"member_id": "senior", "account_id": "acc-senior-2", "question_answer": coerced_opt},
    )
    assert r_hold.status_code == 200, r_hold.text
    hold_body = r_hold.json()
    assert hold_body["status"] == "pending"
    assert hold_body["verdict"]["level"] == "danger"
    savings_req_id = hold_body["request"]["id"]
    first_expiry = hold_body["request"]["expires_at"]

    # 5-a. 보호자 확인: 30분 연장 → 기본 30분 경과 후에도 여전히 보류 중 유지
    r_ext = client.post(
        "/api/v1/guardian/callback-decision",
        json={"transaction_id": savings_req_id, "guardian_id": "guardian", "decision": "EXTEND", "reason": "통화 확인 필요"},
    )
    assert r_ext.status_code == 200, r_ext.text
    assert r_ext.json()["status"] == "EXTENDED"
    assert request(state(client), savings_req_id)["expires_at"] > first_expiry

    clock.advance(timedelta(minutes=35))
    tick()
    assert request(state(client), savings_req_id)["status"] == "pending"

    # 5-b. 추가 보류 시간까지 무응답 만료 → 본인 재확인(reconfirm) 전환 → '그만두기'로 취소
    clock.advance(timedelta(minutes=30))
    tick()
    assert request(state(client), savings_req_id)["status"] == "reconfirm"

    before_balance = member(state(client), "senior")["balance"]
    r_stop = client.post(
        "/api/v1/transaction/reconfirm",
        json={"request_id": savings_req_id, "member_id": "senior", "confirm": False},
    )
    assert r_stop.status_code == 200, r_stop.text
    assert r_stop.json()["status"] == "CANCELLED"
    assert member(state(client), "senior")["balance"] == before_balance
    assert member(state(client), "senior")["caution_mode"] is True

    # 6. 다른 감시 행동(낯선 계좌 50만원 송금) 보류 → 무응답 → 재확인 '그래도 진행'
    r_tx2 = client.post(
        "/api/v1/transaction/transfer",
        json={
            "member_id": "senior",
            "new_account": {"bank": "국민", "number": "12345678907788", "name": "이정민"},
            "amount": 500000,
            "question_answer": "금융감독원·검찰·수사관이 안전계좌로 보내라고 했어요",
        },
    )
    assert r_tx2.status_code == 200, r_tx2.text
    assert r_tx2.json()["status"] == "pending"
    reconfirm_req_id = r_tx2.json()["request"]["id"]

    clock.advance(timedelta(minutes=31))
    tick()
    assert request(state(client), reconfirm_req_id)["status"] == "reconfirm"

    r_go = client.post(
        "/api/v1/transaction/reconfirm",
        json={"request_id": reconfirm_req_id, "member_id": "senior", "confirm": True},
    )
    assert r_go.status_code == 200, r_go.text
    assert r_go.json()["status"] == "APPROVED"
    assert member(state(client), "senior")["balance"] == before_balance - 500000
    assert member(state(client), "senior")["caution_mode"] is True

    # 7. 두 번째 적금 해지 시도 → 보류 → 보호자 직접 해제로 적금 해지 완료 (주의 모드는 보호자 해제 전까지 유지)
    r_hold2 = client.post(
        "/api/v1/banking/savings/cancel",
        json={"member_id": "senior", "account_id": "acc-senior-2", "question_answer": coerced_opt},
    )
    assert r_hold2.status_code == 200, r_hold2.text
    release_req_id = r_hold2.json()["request"]["id"]

    before_release_balance = member(state(client), "senior")["balance"]
    r_rel = client.post(
        "/api/v1/guardian/callback-decision",
        json={"transaction_id": release_req_id, "guardian_id": "guardian", "decision": "RELEASE", "reason": "본인 의사 확인"},
    )
    assert r_rel.status_code == 200, r_rel.text
    assert r_rel.json()["status"] == "APPROVED"

    snap_after_release = state(client)
    senior_after = member(snap_after_release, "senior")
    assert senior_after["balance"] > before_release_balance
    assert senior_after["caution_mode"] is True

    # 8. 보호자가 주의 모드 해제 → 사건 종료 및 시간순 요약 확인
    r_caution_rel = client.post(
        "/api/v1/security/caution-mode/release",
        json={"member_id": "senior", "guardian_id": "guardian"},
    )
    assert r_caution_rel.status_code == 200, r_caution_rel.text

    final_snap = state(client)
    final_senior = member(final_snap, "senior")
    assert final_senior["caution_mode"] is False
    assert final_senior["active_incident"] is None
    assert len(final_snap["incidents"]) == 1
    closed_inc = final_snap["incidents"][0]
    assert closed_inc["status"] == "closed"
    kinds = {item["kind"] for item in closed_inc["items"]}
    assert {"sms", "call", "action", "answer", "judgment", "hold", "guardian"} <= kinds
    times = [item["at"] for item in closed_inc["items"]]
    assert times == sorted(times)
