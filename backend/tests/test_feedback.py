from __future__ import annotations

from sqlalchemy import select

from app.models import UserFeedback


def test_submit_feedback_saves_in_table(client, app):
    res = client.post(
        "/api/v1/feedback",
        json={
            "member_id": "senior",
            "category": "글자가 작아요",
            "message": "쉬운 화면 글자가 조금 더 크면 좋겠어요",
        },
    )
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["status"] == "saved"
    fb = body["feedback"]
    assert fb["member_id"] == "senior"
    assert fb["category"] == "글자가 작아요"
    assert fb["message"] == "쉬운 화면 글자가 조금 더 크면 좋겠어요"
    assert fb["id"].startswith("fb-")

    # 보호자나 아이도 의견을 남길 수 있습니다.
    res2 = client.post(
        "/api/v1/feedback",
        json={"member_id": "guardian", "category": "기타", "message": ""},
    )
    assert res2.status_code == 200

    with app.state.sessions() as s:
        rows = list(s.scalars(select(UserFeedback).order_by(UserFeedback.created_at.asc(), UserFeedback.id.asc())))
        assert len(rows) == 2
        assert any(r.member_id == "senior" and r.category == "글자가 작아요" for r in rows)
        assert any(r.member_id == "guardian" and r.category == "기타" for r in rows)


def test_submit_feedback_validates_category_and_member(client):
    empty_cat = client.post(
        "/api/v1/feedback",
        json={"member_id": "senior", "category": "   ", "message": "내용"},
    )
    assert empty_cat.status_code == 400
    assert empty_cat.json()["error"]["code"] == "category"

    unknown_member = client.post(
        "/api/v1/feedback",
        json={"member_id": "unknown", "category": "기타", "message": "내용"},
    )
    assert unknown_member.status_code == 404
    assert unknown_member.json()["error"]["code"] == "member"
