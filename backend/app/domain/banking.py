"""가상 은행 확장(적금·예금 만기 전 해지, 대출 한도 조회·신청)과 주의 모드 확인 질문·종합 판정 1차 규칙 (기획서 5.4, 5.5, 5.6)."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from .fds import RiskResult
from .sms import SmsVerdict

VALID_ACTION_KINDS: tuple[str, ...] = ("savings_cancel", "transfer", "loan_apply", "loan_limit")

# 확인 질문에서 외부 지시·사기 유도 의심으로 판정하는 표현
COERCED_ANSWER_TERMS: tuple[str, ...] = (
    "금융감독원",
    "금감원",
    "검찰",
    "경찰",
    "수사관",
    "조사관",
    "은행 직원",
    "직원이",
    "안전계좌",
    "안전 계좌",
    "보호계좌",
    "대포통장",
    "지급정지",
    "대환대출",
    "사건",
    "시켰",
    "하라고 했",
    "보내라고 했",
    "받으라고 했",
    "알아보라고 했",
)

UNCERTAIN_ANSWER_TERMS: tuple[str, ...] = (
    "잘 모르겠어요",
    "모르겠",
    "기억이",
)

SELF_ONLY_CAUTION_TERMS: tuple[str, ...] = (
    "괜찮아요",
    "아는 사람",
    "혼자 결정",
    "급하게",
)

FAMILY_DISCUSSED_TERMS: tuple[str, ...] = (
    "가족",
    "보호자",
    "상의",
)


@dataclass(frozen=True)
class SavingsCancelCalculation:
    """적금·예금 만기 전 해지 이자 및 실수령액 계산 결과 (원 단위 정수)."""

    principal: int
    interest_rate: float
    early_cancel_rate: float
    accrued_interest: int
    early_cancel_interest: int
    reduced_interest: int
    payout_amount: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "principal": self.principal,
            "interest_rate": self.interest_rate,
            "early_cancel_rate": self.early_cancel_rate,
            "accrued_interest": self.accrued_interest,
            "early_cancel_interest": self.early_cancel_interest,
            "reduced_interest": self.reduced_interest,
            "payout_amount": self.payout_amount,
        }


def calculate_savings_cancellation(
    principal: int,
    interest_rate: float,
    early_cancel_rate: float = 1.0,
    accrued_interest: int | None = None,
    elapsed_months: int = 18,
) -> SavingsCancelCalculation:
    """원금, 약정 금리, 만기 전 해지 이율로 지금까지 쌓인 이자와 해지 시 줄어드는 이자를 계산합니다.

    모든 금액은 원 단위 정수(int)로 반올림해 돌려줍니다.
    """
    clean_principal = max(0, int(principal))
    rate = max(0.0, float(interest_rate))
    early_rate = max(0.0, min(rate, float(early_cancel_rate)))
    if clean_principal == 0 or rate == 0.0:
        return SavingsCancelCalculation(
            principal=clean_principal,
            interest_rate=rate,
            early_cancel_rate=early_rate,
            accrued_interest=0,
            early_cancel_interest=0,
            reduced_interest=0,
            payout_amount=clean_principal,
        )

    if accrued_interest is None or accrued_interest < 0:
        months = max(1, int(elapsed_months))
        accrued = int(round(clean_principal * (rate / 100.0) * (months / 12.0)))
    else:
        accrued = int(accrued_interest)

    early_interest = int(round(accrued * (early_rate / rate)))
    reduced = max(0, accrued - early_interest)
    payout = clean_principal + early_interest
    return SavingsCancelCalculation(
        principal=clean_principal,
        interest_rate=rate,
        early_cancel_rate=early_rate,
        accrued_interest=accrued,
        early_cancel_interest=early_interest,
        reduced_interest=reduced,
        payout_amount=payout,
    )


@dataclass(frozen=True)
class LoanProduct:
    """가상 은행 대출 상품 하나 (기획서 5.4, 7.2)."""

    id: str
    name: str
    bank: str
    interest_rate: float
    is_variable_rate: bool
    prepayment_fee_rate: float
    repayment_method: str
    term_months: int
    repayment_cycle: str
    min_amount: int
    max_limit: int
    delinquency_rate: float
    withdrawal_right_days: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "name": self.name,
            "bank": self.bank,
            "interest_rate": self.interest_rate,
            "is_variable_rate": self.is_variable_rate,
            "prepayment_fee_rate": self.prepayment_fee_rate,
            "repayment_method": self.repayment_method,
            "term_months": self.term_months,
            "repayment_cycle": self.repayment_cycle,
            "min_amount": self.min_amount,
            "max_limit": self.max_limit,
            "delinquency_rate": self.delinquency_rate,
            "withdrawal_right_days": self.withdrawal_right_days,
        }


LOAN_PRODUCT = LoanProduct(
    id="loan-senior-1",
    name="핑거벨 안심 생활자금 대출",
    bank="핑거벨",
    interest_rate=5.4,
    is_variable_rate=True,
    prepayment_fee_rate=0.6,
    repayment_method="원리금균등분할상환",
    term_months=24,
    repayment_cycle="매월 같은 날",
    min_amount=1_000_000,
    max_limit=20_000_000,
    delinquency_rate=8.4,
    withdrawal_right_days=14,
)


@dataclass(frozen=True)
class LoanQuote:
    """대출 금액별 월 납입액·총 이자·총 상환액 계산 결과 (원 단위 정수)."""

    amount: int
    annual_rate: float
    term_months: int
    monthly_payment: int
    total_interest: int
    total_repayment: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "amount": self.amount,
            "annual_rate": self.annual_rate,
            "term_months": self.term_months,
            "monthly_payment": self.monthly_payment,
            "total_interest": self.total_interest,
            "total_repayment": self.total_repayment,
        }


def calculate_loan_repayment(
    amount: int,
    annual_rate: float = LOAN_PRODUCT.interest_rate,
    term_months: int = LOAN_PRODUCT.term_months,
) -> LoanQuote:
    """원리금균등분할상환 공식으로 월 납입액과 총 이자를 원 단위 정수로 계산합니다."""
    clean_amount = max(0, int(amount))
    months = max(1, int(term_months))
    rate = max(0.0, float(annual_rate))
    if clean_amount == 0:
        return LoanQuote(
            amount=0,
            annual_rate=rate,
            term_months=months,
            monthly_payment=0,
            total_interest=0,
            total_repayment=0,
        )

    monthly_rate = rate / 100.0 / 12.0
    if monthly_rate == 0.0:
        monthly_payment = int(round(clean_amount / months))
    else:
        factor = (1.0 + monthly_rate) ** months
        monthly_payment = int(round(clean_amount * (monthly_rate * factor) / (factor - 1.0)))

    total_repayment = monthly_payment * months
    total_interest = max(0, total_repayment - clean_amount)
    return LoanQuote(
        amount=clean_amount,
        annual_rate=rate,
        term_months=months,
        monthly_payment=monthly_payment,
        total_interest=total_interest,
        total_repayment=total_repayment,
    )


@dataclass(frozen=True)
class ConfirmationQuestion:
    """주의 모드 중 감시 대상 금융 행동을 시도할 때 묻는 객관식 확인 질문 (기획서 5.6)."""

    action_kind: str
    question: str
    options: list[str] = field(default_factory=list)
    source: str = "rule"  # "rule" | "llm" | "rule_fallback"
    cached: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {
            "action_kind": self.action_kind,
            "question": self.question,
            "options": list(self.options),
            "source": self.source,
            "cached": self.cached,
        }


QUESTION_PRESETS: dict[str, ConfirmationQuestion] = {
    "savings_cancel": ConfirmationQuestion(
        action_kind="savings_cancel",
        question="적금을 만기 전에 해지하려고 하시네요. 혹시 누가 해지하라고 했나요?",
        options=[
            "금융감독원·검찰·은행 직원이 해지하라고 했어요",
            "괜찮아요, 아는 사람이에요",
            "가족(보호자)과 이미 상의했어요",
            "잘 모르겠어요",
        ],
        source="rule",
    ),
    "transfer": ConfirmationQuestion(
        action_kind="transfer",
        question="평소보다 큰 금액을 보내려고 하시네요. 혹시 누가 이 돈을 보내라고 했나요?",
        options=[
            "금융감독원·검찰·수사관이 안전계좌로 보내라고 했어요",
            "괜찮아요, 아는 사람이에요",
            "가족(보호자)과 이미 상의했어요",
            "잘 모르겠어요",
        ],
        source="rule",
    ),
    "loan_apply": ConfirmationQuestion(
        action_kind="loan_apply",
        question="대출을 신청하려고 하시네요. 혹시 누가 대출을 받으라고 했나요?",
        options=[
            "금융감독원·검찰·은행 직원이 대출을 받으라고 했어요",
            "괜찮아요, 아는 사람이에요",
            "가족(보호자)과 이미 상의했어요",
            "잘 모르겠어요",
        ],
        source="rule",
    ),
    "loan_limit": ConfirmationQuestion(
        action_kind="loan_limit",
        question="대출 한도를 조회하려고 하시네요. 혹시 누가 대출을 알아보라고 했나요?",
        options=[
            "금융감독원·검찰·은행 직원이 알아보라고 했어요",
            "괜찮아요, 아는 사람이에요",
            "가족(보호자)과 이미 상의했어요",
            "잘 모르겠어요",
        ],
        source="rule",
    ),
}


def preset_question(action_kind: str, incident_items: list[dict[str, Any]] | None = None) -> ConfirmationQuestion:
    """행동 종류와 사건 문맥에 맞는 기본 확인 질문을 돌려줍니다."""
    key = (action_kind or "savings_cancel").strip().lower()
    base = QUESTION_PRESETS.get(key, QUESTION_PRESETS["savings_cancel"])
    items = incident_items or []
    has_call = any(i.get("kind") == "call" for i in items)
    has_sms = any(i.get("kind") == "sms" for i in items)
    if has_call and has_sms:
        prefix = "방금 의심스러운 문자와 통화가 있었어요. "
    elif has_call:
        prefix = "방금 의심스러운 통화가 있었어요. "
    elif has_sms:
        prefix = "방금 의심스러운 문자가 도착했어요. "
    else:
        prefix = ""
    if not prefix:
        return base
    return ConfirmationQuestion(
        action_kind=base.action_kind,
        question=f"{prefix}{base.question}",
        options=list(base.options),
        source="rule",
        cached=False,
    )


def classify_answer(answer: str) -> str:
    """확인 질문 답을 'danger' | 'caution' | 'low' 중 하나로 분류합니다."""
    text = (answer or "").strip()
    if any(term in text for term in COERCED_ANSWER_TERMS):
        return "danger"
    if any(term in text for term in UNCERTAIN_ANSWER_TERMS):
        return "danger"
    if any(term in text for term in FAMILY_DISCUSSED_TERMS):
        return "low"
    if any(term in text for term in SELF_ONLY_CAUTION_TERMS):
        return "caution"
    return "caution"


ACTION_LABELS: dict[str, str] = {
    "savings_cancel": "적금 만기 전 해지",
    "transfer": "평소보다 큰 금액 송금",
    "loan_apply": "대출 신청",
    "loan_limit": "대출 한도 조회",
}


def assess_caution_action_rules(
    action_kind: str,
    action_summary: str,
    answer: str,
    incident_items: list[dict[str, Any]] | None = None,
    fds_risk: RiskResult | None = None,
) -> tuple[SmsVerdict, int]:
    """주의 모드 안 감시 대상 금융 행동의 1차 규칙·점수 판정 (기획서 5.5).

    사건의 문자·통화 징후, 금융 행동(송금은 기존 FDS 포함), 확인 질문 답을 묶어
    1차 단계(low / caution / danger), 점수(0~99), 근거 목록, 쉬운 설명을 계산합니다.
    """
    items = incident_items or []
    has_sms = any(i.get("kind") == "sms" for i in items)
    has_call = any(i.get("kind") == "call" for i in items)
    action_label = ACTION_LABELS.get(action_kind, action_summary or "금융 거래")
    answer_level = classify_answer(answer)

    reasons: list[str] = []
    if has_sms:
        reasons.append("사건 기록에 사기 의심 문자 수신 징후가 있어요")
    if has_call:
        reasons.append("사건 기록에 보이스피싱 의심 통화 징후가 있어요")
    reasons.append(f"주의 모드 중 {action_label}을 시도했어요")

    if fds_risk is not None:
        for sig in fds_risk.signals:
            if sig.label not in reasons:
                reasons.append(sig.label)

    clean_ans = (answer or "").strip()
    if answer_level == "danger":
        if any(term in clean_ans for term in UNCERTAIN_ANSWER_TERMS):
            reasons.append("확인 질문에 '잘 모르겠어요'라고 답해 거래 경위가 불분명해요")
        else:
            reasons.append(f"확인 질문에서 기관·타인의 지시 의심 응답({clean_ans})을 골랐어요")
        score = 85
        level = "danger"
    elif answer_level == "caution":
        reasons.append(f"확인 질문에서 보호자 상의 없이 진행한다는 응답({clean_ans})을 골랐어요")
        score = 45
        level = "caution"
    else:
        reasons.append("확인 질문에서 가족(보호자)과 이미 상의했다고 답했어요")
        score = 18
        level = "low"

    # 송금의 경우 기존 FDS 점수가 위험(high)이거나 주의(caution)이면 그 이하로 내려가지 않습니다.
    if fds_risk is not None:
        if fds_risk.level == "high":
            level = "danger"
            score = max(score, fds_risk.score, 75)
        elif fds_risk.level == "caution" and level == "low":
            level = "caution"
            score = max(score, fds_risk.score, 35)

    if level == "danger":
        explanation = (
            f"사기 의심 연락 뒤에 이어진 {action_label} 시도로 보이스피싱 위험이 매우 높아요. "
            "피해를 막기 위해 보호자와 확인할 수 있도록 조치를 진행해요."
        )
    elif level == "caution":
        explanation = (
            f"주의 모드 중 {action_label}을 진행하고 있어요. "
            "누군가 전화나 문자로 시킨 거래가 아닌지 다시 한 번 확인해 주세요."
        )
    else:
        explanation = f"보호자와 상의한 {action_label}으로 확인되어 진행해요."

    verdict = SmsVerdict(
        level=level,
        reasons=reasons,
        explanation=explanation,
        rule_level=level,
        source="rule",
        cached=False,
    )
    return verdict, min(99, score)


def build_risk_dict_from_verdict(
    verdict: SmsVerdict,
    score: int,
    *,
    needs_approval: bool,
    fds_risk: RiskResult | None = None,
) -> dict[str, Any]:
    """SmsVerdict(low/caution/danger)를 ApprovalRequest.risk 및 앱 RiskAssessment 형식(safe/caution/high)으로 변환합니다."""
    mapped_level = "high" if verdict.level == "danger" else ("caution" if verdict.level == "caution" else "safe")
    mapped_score = score
    if verdict.level == "danger" and mapped_score < 60:
        mapped_score = 80
    elif verdict.level == "caution" and not (30 <= mapped_score < 60):
        mapped_score = 45
    elif verdict.level == "low" and mapped_score >= 30:
        mapped_score = 15

    signals = [{"id": f"inc-{idx + 1}", "label": reason, "weight": 20} for idx, reason in enumerate(verdict.reasons)]
    base = fds_risk.to_dict() if fds_risk is not None else {"sleep_window": False, "model": None}
    return {
        "score": mapped_score,
        "level": mapped_level,
        "verdict_level": verdict.level,
        "signals": signals,
        "reasons": list(verdict.reasons),
        "explanation": verdict.explanation,
        "needs_approval": needs_approval,
        "sleep_window": bool(base.get("sleep_window", False)),
        "model": base.get("model"),
        "source": verdict.source,
    }
