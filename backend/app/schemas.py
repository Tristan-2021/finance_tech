"""요청 본문 스키마 (snake_case)."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

TriggerType = Literal["SHAKE_MOTION", "LONG_PRESS", "GUARDIAN_REMOTE"]


class SosFreezeRequest(BaseModel):
    user_id: str
    trigger_type: TriggerType
    sensor_intensity: float | None = Field(default=None, ge=0, le=50)


class MemberRequest(BaseModel):
    member_id: str


class NewAccount(BaseModel):
    bank: str
    number: str
    name: str


class TransferDraft(BaseModel):
    member_id: str
    contact_id: str | None = None
    new_account: NewAccount | None = None
    amount: int
    confirmed: bool = False
    # 클라이언트가 보낸 점수·단계는 참고만 하고 항상 서버가 다시 계산합니다 (기획서 1절, 5.5).
    risk_score: int | None = None
    risk_level: str | None = None
    risk_reasons: list[str] | None = None

    def to_draft(self) -> dict:
        return {
            "contact_id": self.contact_id,
            "new_account": self.new_account.model_dump() if self.new_account else None,
            "amount": self.amount,
            "confirmed": self.confirmed,
        }


class ApprovalRequestBody(BaseModel):
    """이상 거래 보류 요청. 위험도는 서버가 다시 계산합니다 (클라이언트 값은 참고용)."""

    sender_id: str
    recipient_bank: str
    recipient_account: str
    recipient_name: str
    amount: int
    risk_score: int | None = None
    risk_level: str | None = None
    risk_reasons: list[str] | None = None


class CallbackDecision(BaseModel):
    transaction_id: str
    guardian_id: str
    decision: Literal["APPROVE", "REJECT", "RELEASE", "EXTEND"]
    reason: str | None = Field(default=None, max_length=120)


class HoldCancelBody(BaseModel):
    request_id: str
    member_id: str | None = None


class HoldReconfirmBody(BaseModel):
    request_id: str
    member_id: str | None = None
    confirm: bool


class HoldExtendBody(BaseModel):
    request_id: str
    guardian_id: str
    reason: str | None = Field(default=None, max_length=120)


class CautionReleaseBody(BaseModel):
    member_id: str
    guardian_id: str


class PaymentBody(BaseModel):
    member_id: str
    merchant_id: str


class ModeBody(BaseModel):
    member_id: str
    mode: str
    actor: Literal["SELF", "GUARDIAN"] = "SELF"


class LimitBody(BaseModel):
    member_id: str
    daily_limit: int


class SleepGuardBody(BaseModel):
    member_id: str
    enabled: bool


class UnfreezeBody(BaseModel):
    member_id: str
    guardian_id: str
