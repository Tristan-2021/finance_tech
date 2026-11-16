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
    question_answer: str | None = Field(default=None, max_length=200)
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
            "question_answer": self.question_answer,
        }


class CautionQuestionBody(BaseModel):
    member_id: str = "senior"
    action_kind: Literal["savings_cancel", "transfer", "loan_apply", "loan_limit"]
    amount: int | None = None


class SavingsCancelBody(BaseModel):
    member_id: str = "senior"
    account_id: str
    question_answer: str | None = Field(default=None, max_length=200)
    confirmed: bool = False
    # 클라이언트가 보낸 점수·단계는 무시하고 서버가 계산합니다.
    risk_level: str | None = None
    risk_score: int | None = None


class LoanQuoteBody(BaseModel):
    amount: int


class LoanLimitBody(BaseModel):
    member_id: str = "senior"
    question_answer: str | None = Field(default=None, max_length=200)
    confirmed: bool = False
    risk_level: str | None = None
    risk_score: int | None = None


class LoanApplyBody(BaseModel):
    member_id: str = "senior"
    amount: int
    question_answer: str | None = Field(default=None, max_length=200)
    confirmed: bool = False
    risk_level: str | None = None
    risk_score: int | None = None


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


class PairingCodeIssueBody(BaseModel):
    guardian_id: str = "guardian"
    member_id: str = "senior"


class PairingConnectBody(BaseModel):
    member_id: str = "senior"
    code: str = Field(min_length=1, max_length=32)
    consented: bool = False


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


class SmsReceiveBody(BaseModel):
    """시연 문자 수신 요청. 위험 판정은 항상 서버가 계산합니다 (클라이언트 값은 무시)."""

    member_id: str = "senior"
    kind: str | None = None
    sender_phone: str | None = Field(default=None, max_length=30)
    sender_name: str | None = Field(default=None, max_length=60)
    body: str | None = Field(default=None, max_length=1000)
    level: str | None = None
    reasons: list[str] | None = None
    explanation: str | None = None


class CallStartBody(BaseModel):
    """통화 발신 요청. 분석 대상 여부(analyzed)는 항상 서버가 참가자를 보고 계산합니다."""

    caller_id: str = "senior"
    callee_id: str | None = None
    peer_phone: str | None = Field(default=None, max_length=30)
    peer_name: str | None = Field(default=None, max_length=60)
    analyzed: bool | None = None


class CallActionBody(BaseModel):
    call_id: str | None = None
    participant_id: str | None = None


class CallAudioBody(BaseModel):
    """통화 음성 4초 조각 업로드 요청. 음성인식 후 분석하며 원문은 저장하지 않습니다."""

    call_id: str | None = None
    audio_base64: str = ""
    audio_format: str = "wav"
    speaker_id: str | None = None
    level: str | None = None


class CallTranscriptBody(BaseModel):
    """시연 상대 대본 문장 보내기 요청 (음성인식 없이 통화 분석으로 바로 입력)."""

    call_id: str | None = None
    text: str | None = Field(default=None, max_length=1000)
    transcript: str | None = Field(default=None, max_length=1000)
    sentence: str | None = Field(default=None, max_length=1000)
    speaker_id: str | None = None
    level: str | None = None
    reasons: list[str] | None = None
    explanation: str | None = None


class CallSignalBody(BaseModel):
    """WebRTC 연결 신호(offer / answer / ice). 서버는 내용을 해석하지 않고 전달만 합니다."""

    call_id: str | None = None
    signal_type: str = "offer"
    from_id: str | None = None
    to_id: str | None = None
    data: dict | str | None = None
    sdp: str | None = None
    candidate: dict | str | None = None
