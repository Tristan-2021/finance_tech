"""통화 전사문 판정 규칙(1차)과 시연·검증용 가상 통화 대본 데이터 (기획서 5.3, 5.5, 8절, 9절).

판정 구조:
1. 규칙 1차: 전사문의 표현(기관 사칭, 안전 계좌, 해지·대출 요구, 비밀로 하라는 말, 재촉)을 검사해
   단계(low / caution / danger), 근거 목록(reasons), 쉬운 설명 한 줄(explanation)을 만듭니다.
2. LLM 최종: `integrations.py`의 `LlmGateway`가 1차 결과와 전사문 자료를 받아 최종 판정합니다.
   키가 없거나 실패·시간 초과·형식 오류이면 이 모듈이 만든 1차 결과를 그대로 씁니다.

통화 음성과 전사문 원문은 판정이 끝나면 저장하지 않으며, 근거와 설명에는 어떤 표현 유형이 왜 위험했는지만 남깁니다(기획서 5.1).
모든 기관 이름은 사칭 예시로만 쓰며, 전화번호(`0000` 국번)는 존재하지 않는 가짜입니다.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from .sms import VALID_LEVELS, SmsVerdict

# CallVerdict는 SmsVerdict와 동일한 필드 구조(level, reasons, explanation, rule_level, source, cached)를 씁니다.
CallVerdict = SmsVerdict

# 1. 기관 사칭 표현 (공공기관·수사기관·금융당국 사칭)
CALL_IMPERSONATION_TERMS: tuple[str, ...] = (
    "금융감독원",
    "금감원",
    "검찰청",
    "서울중앙지검",
    "지방검찰청",
    "경찰청",
    "사이버수사대",
    "금융범죄수사",
    "수사관",
    "조사관",
    "검사입니다",
    "법원",
    "국세청",
    "건강보험공단",
    "국민건강보험",
    "관세청",
    "서민금융진흥원",
)

# 2. 안전 계좌·보호 계좌 유도 표현
SAFE_ACCOUNT_TERMS: tuple[str, ...] = (
    "안전계좌",
    "안전 계좌",
    "보호계좌",
    "보호 계좌",
    "국가안전계좌",
    "금감원 계좌",
    "검찰 계좌",
    "지정 계좌",
    "보호조치 계좌",
    "자금 보호",
    "안전하게 보관",
)

# 3. 적금·예금 해지, 인출, 대출 요구 표현
FINANCIAL_DEMAND_TERMS: tuple[str, ...] = (
    "적금 해지",
    "예금 해지",
    "만기 전 해지",
    "중도해지",
    "중도 해지",
    "적금을 해지",
    "예금을 해지",
    "통장을 해지",
    "전액 인출",
    "현금 인출",
    "현금으로 인출",
    "전액 이체",
    "대환대출",
    "저금리 대환",
    "대출 신청",
    "대출을 받아",
    "카드론",
    "원격제어 앱",
    "보안 앱을 설치",
)

# 4. 비밀로 하라는 말·주변 차단 유도 표현
SECRECY_TERMS: tuple[str, ...] = (
    "비밀",
    "비밀로",
    "아무에게도 말하지",
    "말하지 마",
    "말하지 말",
    "알리지 마",
    "알리지 말",
    "가족에게 알리지",
    "자녀에게 말하지",
    "은행 직원에게 말하지",
    "은행 직원에게 알리지",
    "창구 직원에게 말하지",
    "창구 직원에게 알리지",
    "둘러대고",
    "수사 기밀",
    "보안 유지",
    "절대 발설",
    "조용한 곳으로 이동",
    "전화를 끊지 마시고",
    "전화 끊지 마시고",
)

# 5. 재촉·수사 압박 표현
URGENCY_TERMS: tuple[str, ...] = (
    "지금 당장",
    "지금 바로 처리",
    "즉시 해지",
    "즉시 이체",
    "오늘 안에 처리",
    "30분 안에",
    "1시간 내로",
    "시간 지체",
    "구속영장",
    "체포영장",
    "계좌 동결",
    "계좌동결",
    "지급정지",
    "압류",
    "대포통장",
    "명의도용",
    "명의 도용",
    "범죄 연루",
    "사건이 접수",
    "사건번호",
    "피의자",
)


@dataclass(frozen=True)
class CallScript:
    id: str
    kind: str  # "phishing" | "normal"
    title: str
    caller_name: str
    caller_phone: str
    lines: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "kind": self.kind,
            "title": self.title,
            "caller_name": self.caller_name,
            "caller_phone": self.caller_phone,
            "lines": list(self.lines),
        }


def assess_call_rules(transcript: str) -> CallVerdict:
    """1차 규칙 판정: 기관 사칭, 안전 계좌, 해지·대출 요구, 비밀 강요, 재촉 표현을 검사합니다.

    원문(transcript)은 결과 객체에 남기지 않고, 감지된 위험 유형과 쉬운 설명 한 줄만 돌려줍니다.
    """
    text = (transcript or "").strip()
    if not text:
        return CallVerdict(
            level="low",
            reasons=[],
            explanation="사기 의심 징후가 없는 일반 통화예요.",
            rule_level="low",
            source="rule",
        )

    matched_imp = [t for t in CALL_IMPERSONATION_TERMS if t in text]
    matched_safe = [t for t in SAFE_ACCOUNT_TERMS if t in text]
    matched_fin = [t for t in FINANCIAL_DEMAND_TERMS if t in text]
    matched_sec = [t for t in SECRECY_TERMS if t in text]
    matched_urg = [t for t in URGENCY_TERMS if t in text]

    reasons: list[str] = []
    if matched_imp:
        reasons.append(f"공공·금융기관 사칭 의심 표현({matched_imp[0]})이 나왔어요")
    if matched_safe:
        reasons.append(f"안전 계좌·보호 계좌로 돈을 옮기라는 표현({matched_safe[0]})이 나왔어요")
    if matched_fin:
        reasons.append(f"적금·예금 해지나 대출·이체를 요구하는 표현({matched_fin[0]})이 나왔어요")
    if matched_sec:
        reasons.append(f"가족이나 은행 직원에게 비밀로 하라는 표현({matched_sec[0]})이 나왔어요")
    if matched_urg:
        reasons.append(f"수사·처벌로 겁을 주거나 지금 당장 처리하라고 재촉하는 표현({matched_urg[0]})이 나왔어요")

    if reasons:
        level = "danger"
        explanation = "기관을 사칭하거나 적금 해지·안전계좌 이체를 요구하는 보이스피싱 의심 통화예요. 지금 바로 통화를 끊으세요."
    else:
        level = "low"
        explanation = "사기 의심 징후가 없는 일반 통화예요."

    return CallVerdict(
        level=level,
        reasons=reasons,
        explanation=explanation,
        rule_level=level,
        source="rule",
    )


# ------------------------------------------------------------------ 시연용 통화 대본 (기획서 8절)
CALL_SCRIPTS: dict[str, CallScript] = {
    "phishing": CallScript(
        id="phishing",
        kind="phishing",
        title="사기 대본 (금융감독원 사칭 → 적금 해지 요구)",
        caller_name="금융감독원 민원실(사칭)",
        caller_phone="02-0000-1332",
        lines=[
            "여기는 금융감독원 민원실 김철수 조사관입니다. 어르신 명의 대포통장이 개설되어 사건이 접수되었습니다.",
            "지금 당장 노후 적금을 만기 전 해지하시고 금융감독원 안전계좌로 전액 이체하셔야 자금을 보호할 수 있습니다.",
            "수사 기밀이니 가족이나 은행 직원에게는 절대 비밀로 하시고 지금 바로 처리해 주세요.",
        ],
    ),
    "normal": CallScript(
        id="normal",
        kind="normal",
        title="정상 대본 (가족 안부)",
        caller_name="김사랑 (딸)",
        caller_phone="010-0000-1024",
        lines=[
            "엄마, 오늘 점심 식사는 맛있게 챙겨 드셨어요?",
            "이번 주말에 민준이랑 좋아하는 반찬 가지고 집에 들를게요.",
            "날씨가 쌀쌀하니까 외출하실 때 따뜻한 옷 챙겨 입으세요.",
        ],
    ),
}


def resolve_call_script(kind: str | None = None) -> CallScript:
    key = (kind or "phishing").strip().lower()
    if key in CALL_SCRIPTS:
        return CALL_SCRIPTS[key]
    if key in ("scam", "danger", "phishing_fss"):
        return CALL_SCRIPTS["phishing"]
    if key in ("normal", "safe", "family"):
        return CALL_SCRIPTS["normal"]
    return CALL_SCRIPTS["phishing"]


# ------------------------------------------------------------------ 9절 검증용 가상 통화 문장 모음 (각 20건 이상)
SCAM_CALL_SAMPLES: tuple[str, ...] = (
    "여기는 금융감독원 민원실 조사관입니다. 어르신 명의 대포통장이 개설되어 사건이 접수되었습니다.",
    "서울중앙지검 첨단범죄수사부 수사관입니다. 명의도용 금융사기 사건번호 2026-8821호로 연락드렸습니다.",
    "지금 당장 노후 적금을 만기 전 해지하시고 금융감독원 안전계좌로 전액 이체하셔야 합니다.",
    "수사 기밀 사항이니 가족이나 은행 창구 직원에게는 절대 비밀로 하시고 혼자 처리하세요.",
    "경찰청 사이버수사대입니다. 귀하의 계좌가 범죄 연루 정황이 있어 오늘 안에 지급정지됩니다.",
    "보유하신 정기예금을 중도해지해서 국가안전계좌로 옮기셔야 자금 보호 조치가 가능합니다.",
    "어르신 통장이 대포통장으로 도용되어 구속영장이 청구되었습니다. 즉시 해지 후 조사에 협조하세요.",
    "은행 직원에게 말하면 공범으로 몰릴 수 있으니 아무에게도 말하지 말고 현금으로 인출하세요.",
    "서민금융진흥원입니다. 정부지원 저금리 대환대출 승인을 위해 기존 적금을 해지하고 지정 계좌로 송금하세요.",
    "검찰청 검사입니다. 피의자 신분으로 전환되기 전에 지금 당장 보호계좌로 전액 이체하셔야 합니다.",
    "30분 안에 안전 계좌로 이체하지 않으시면 전 계좌 동결 및 압류 절차가 바로 진행됩니다.",
    "국민건강보험 환급금 지급을 위해 지금 당장 알려드리는 보안 앱을 설치하셔야 합니다.",
    "전화를 끊지 마시고 조용한 곳으로 이동해서 스마트폰 원격제어 앱을 설치해 주세요.",
    "지방검찰청 수사관입니다. 어르신 명의 도용 사건 확인을 위해 예금 해지 후 검찰 계좌로 입금하세요.",
    "자녀에게 말하지 마시고 지금 바로 처리하셔야 구속영장 집행을 멈출 수 있습니다.",
    "법원 등기 반송 건으로 연락드렸습니다. 사건이 접수되었으니 즉시 이체하여 공탁금을 예치하세요.",
    "금융감독원 자산보호팀입니다. 해킹 피해 예방을 위해 적금을 해지하고 안전하게 보관해 드리겠습니다.",
    "국세청 조사관입니다. 체납 압류를 피하려면 1시간 내로 지정 계좌로 전액 이체하셔야 합니다.",
    "카드론 대출 신청이 접수되었습니다. 본인이 아니면 지금 당장 취소용 보호 계좌로 송금하세요.",
    "시간 지체하시면 계좌동결됩니다. 은행 직원에게는 인테리어 비용이라고 둘러대고 전액 인출하세요.",
    "관세청 통관 조사관입니다. 명의도용 범죄 연루 확인을 위해 통장을 해지하고 대기해 주세요.",
    "수사 보안 유지를 위해 가족에게 알리지 마시고 오늘 안에 처리해 주셔야 피해를 막습니다.",
)

NORMAL_CALL_SAMPLES: tuple[str, ...] = (
    "엄마, 오늘 점심 식사는 맛있게 챙겨 드셨어요?",
    "이번 주말에 민준이랑 좋아하는 반찬 가지고 집에 들를게요.",
    "날씨가 쌀쌀하니까 외출하실 때 따뜻한 옷 챙겨 입으세요.",
    "할머니, 저 민준이에요! 오늘 학교에서 축구 시합했는데 정말 재미있었어요.",
    "순자 언니, 내일 오전 열 시에 경로당에서 노래교실 있는 거 잊지 않았지?",
    "김순자 어르신, 행복내과의원입니다. 내일 오전 열 시 반 정기 진료 예약 안내 전화드렸습니다.",
    "온누리약국입니다. 처방받으신 혈압약은 아침 식사 후 삼십 분 뒤에 꼭 챙겨 드세요.",
    "안심택배 기사입니다. 주문하신 건강즙 상자를 현관문 앞에 안전하게 두었습니다.",
    "엄마, 지난번에 보내주신 참기름이랑 김치 정말 맛있게 잘 먹고 있어요.",
    "이번 주 일요일에 가족끼리 근처 식당에서 점심 먹기로 했어요. 편하게 준비만 해 주세요.",
    "행복마트 배달 안내입니다. 주문하신 쌀 열 킬로그램과 사과가 오후 네 시에 도착할 예정입니다.",
    "어머니, 오늘 저녁에 비가 온다고 하니까 우산 꼭 챙기시고 저녁 식사도 거르지 마세요.",
    "노인복지관 담당자입니다. 다음 주 화요일 건강 체조 교실은 이층 강당에서 열립니다.",
    "언니, 아까 화단에 심을 꽃모종 조금 나눠놨는데 이따가 마실 나오면서 가져가.",
    "동네미용실입니다. 오늘 오후 두 시 파마 예약 시간 맞춰서 천천히 오시면 됩니다.",
    "할머니, 주말에 갈 때 할머니가 좋아하시는 단팥빵 사 갈게요. 보고 싶어요!",
    "아파트 관리사무소입니다. 내일 오후 두 시부터 네 시까지 단지 물탱크 청소가 있습니다.",
    "엄마, 어제 무릎은 좀 어떠세요? 파스 붙여 드린 거 괜찮으신지 궁금해서 전화했어요.",
    "밝은안과의원입니다. 다음 주 수요일 오전 열한 시 백내장 정기 검진 예약 확인드립니다.",
    "주민센터 복지팀입니다. 어르신 독감 무료 예방접종 기간이니 신분증 지참하고 가까운 병원에 방문하세요.",
    "순자야, 오랜만에 목소리 듣고 싶어서 전화했다. 요즘 건강은 어떠니?",
    "엄마, 퇴근하고 집에 가는 길이에요. 내일 아침에 또 안부 전화 드릴게요.",
    "은행 직원에게 문의해 보세요.",
)

__all__ = [
    "CALL_IMPERSONATION_TERMS",
    "CALL_SCRIPTS",
    "CallScript",
    "CallVerdict",
    "FINANCIAL_DEMAND_TERMS",
    "NORMAL_CALL_SAMPLES",
    "SAFE_ACCOUNT_TERMS",
    "SCAM_CALL_SAMPLES",
    "SECRECY_TERMS",
    "URGENCY_TERMS",
    "VALID_LEVELS",
    "assess_call_rules",
    "resolve_call_script",
]
