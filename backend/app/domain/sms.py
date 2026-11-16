"""문자 판정 규칙(1차)과 시연·검증용 가상 문자 데이터 (기획서 5.2, 5.5, 8절, 9절).

판정 구조:
1. 규칙 1차: 기관 사칭 표현, 위험 키워드, 링크(URL), 발신 번호 형태를 검사해
   단계(low / caution / danger), 근거 목록(reasons), 쉬운 설명(explanation)을 만듭니다.
2. LLM 최종: `integrations.py`의 `LlmGateway`가 1차 결과와 문자 자료를 받아 최종 판정합니다.
   키가 없거나 실패·시간 초과·형식 오류이면 이 모듈이 만든 1차 결과를 그대로 씁니다.

모든 기관 이름은 사칭 예시로만 쓰며, 링크(`.invalid`)와 전화번호(`0000` 국번)는 존재하지 않는 가짜입니다.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any

VALID_LEVELS = ("low", "caution", "danger")

# URL 추출: http(s)://... 형태와 도메인/경로 형태(.invalid, .example 등)
_URL_RE = re.compile(
    r"(?:https?://[^\s<>\"\'\)\]]+|(?:[a-zA-Z0-9-]+\.)+(?:invalid|example|test|kr|com|net)/[^\s<>\"\'\)\]]*)"
)

# 전화번호 추출: 02-0000-1332, 010-0000-1024, 070-0000-1234 등 (시연 데이터는 모두 가짜 번호)
_PHONE_RE = re.compile(r"(?<!\d)(?:0\d{1,2}-\d{3,4}-\d{4}|1[568]\d{2}-\d{4})(?!\d)")

# 1. 기관 사칭 표현 (공공기관·수사기관·법원·금융당국·사칭 단골 문구)
IMPERSONATION_TERMS: tuple[str, ...] = (
    "금융감독원",
    "검찰청",
    "서울중앙지검",
    "지방검찰청",
    "경찰청",
    "사이버수사대",
    "수사관",
    "조사관",
    "법원",
    "등기소",
    "국세청",
    "국민건강보험",
    "건강보험공단",
    "관세청",
    "우체국 등기",
    "정부지원",
    "서민금융진흥원",
)

# 2. 사기·압박·금융 행동 유도 키워드
DANGER_KEYWORDS: tuple[str, ...] = (
    "대포통장",
    "명의도용",
    "명의 도용",
    "지급정지",
    "계좌 동결",
    "계좌동결",
    "압류",
    "구속영장",
    "출석요구서",
    "사건번호",
    "사건 접수",
    "사건접수",
    "범죄 연루",
    "안전계좌",
    "안전 계좌",
    "보호조치",
    "만기 전 해지",
    "적금 해지",
    "예금 해지",
    "원격제어",
    "앱 설치",
    "악성코드",
    "해외결제",
    "해외직구",
    "본인 확인 바랍니다",
    "즉시 확인",
    "본인이 아닐 경우",
    "본인 아닐 시",
    "신청하지 않으셨다면",
    "미수령 환급금",
    "환급금 조회",
    "저금리 대환",
    "대환대출 승인",
    "주소지 불명",
    "통관 보류",
    "액정 파손",
    "폰이 고장",
)

# 3. 발신 번호 형태 이상 징후
INTERNATIONAL_PREFIXES: tuple[str, ...] = ("[국외발신]", "[국제발신]", "006", "00700", "+82", "+1", "+86")


@dataclass(frozen=True)
class SmsVerdict:
    level: str  # "low" | "caution" | "danger"
    reasons: list[str] = field(default_factory=list)
    explanation: str = ""
    rule_level: str = "low"
    source: str = "rule"  # "rule" | "llm" | "rule_fallback"
    cached: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {
            "level": self.level,
            "reasons": list(self.reasons),
            "explanation": self.explanation,
            "rule_level": self.rule_level,
            "source": self.source,
            "cached": self.cached,
        }


@dataclass(frozen=True)
class SmsPreset:
    id: str
    kind: str  # "phishing" | "normal"
    category: str
    sender_name: str
    sender_phone: str
    body: str


def extract_links(text: str) -> list[str]:
    seen: list[str] = []
    for m in _URL_RE.finditer(text or ""):
        url = m.group(0).rstrip(".,;:!)")
        if url and url not in seen:
            seen.append(url)
    return seen


def extract_phones(text: str, sender: str = "") -> list[str]:
    seen: list[str] = []
    for src in (text or "", sender or ""):
        for m in _PHONE_RE.finditer(src):
            phone = m.group(0)
            if phone and phone not in seen:
                seen.append(phone)
    return seen


def _has_suspicious_sender(sender_phone: str, body: str, has_impersonation: bool, has_keyword: bool) -> bool:
    s = (sender_phone or "").strip()
    b = (body or "").strip()
    if any(tag in b or s.startswith(tag) for tag in INTERNATIONAL_PREFIXES):
        return True
    if s.startswith("070-"):
        return True
    # 공공·수사기관 사칭이나 해외결제·환급·대환 경고를 일반 휴대전화(010)나 가짜 국번(0000)에서 보낸 경우
    if (has_impersonation or has_keyword) and (s.startswith("010-") or "-0000-" in s):
        return True
    return False


def assess_sms_rules(sender_phone: str, body: str, sender_name: str = "") -> SmsVerdict:
    """1차 규칙 판정: 기관 사칭 표현, 위험 키워드, 링크, 발신 번호 형태를 검사합니다."""
    text = f"{sender_name} {body}".strip()
    links = extract_links(body)

    matched_imp = [term for term in IMPERSONATION_TERMS if term in text]
    matched_kw = [kw for kw in DANGER_KEYWORDS if kw in text]
    suspicious_sender = _has_suspicious_sender(sender_phone, body, bool(matched_imp), bool(matched_kw))

    reasons: list[str] = []
    if matched_imp:
        reasons.append(f"공공·금융기관 사칭 의심 표현({matched_imp[0]})이 들어 있어요")
    if matched_kw:
        reasons.append(f"불안을 주거나 확인을 재촉하는 표현({matched_kw[0]})이 있어요")
    if links:
        reasons.append("문자 안에 출처가 불분명한 인터넷 주소(링크)가 들어 있어요")
    if suspicious_sender:
        reasons.append("발신 번호가 공식 기관 번호가 아니거나 의심스러운 번호 형태예요")

    signal_count = len(reasons)
    if (
        signal_count >= 2
        or (bool(matched_imp) and bool(links))
        or (bool(matched_imp) and bool(matched_kw))
        or (bool(matched_kw) and bool(links))
    ):
        level = "danger"
        explanation = (
            "기관이나 회사를 사칭해 링크를 누르게 하거나 전화를 유도하는 사기 의심 문자예요. "
            "문자 속 링크를 누르거나 적힌 번호로 전화하지 마세요."
        )
    elif signal_count == 1:
        level = "caution"
        explanation = "문자 안에 확인이 필요한 링크나 표현이 있어요. 아는 번호인지 먼저 확인해 주세요."
    else:
        level = "low"
        explanation = "사기 의심 징후가 없는 일반 문자예요."

    return SmsVerdict(
        level=level,
        reasons=reasons,
        explanation=explanation,
        rule_level=level,
        source="rule",
    )


# ------------------------------------------------------------------ 시연용 문자 프리셋 (기획서 8절)
SMS_PRESETS: dict[str, SmsPreset] = {
    "phishing": SmsPreset(
        id="phishing",
        kind="phishing",
        category="impersonation",
        sender_name="금융감독원 민원실(사칭)",
        sender_phone="02-0000-1332",
        body=(
            "[금융감독원] 김순자님 명의 대포통장 개설 사건이 접수되었습니다. "
            "즉시 본인 확인 바랍니다. 미확인 시 전 계좌 지급정지 및 만기 전 해지 보호조치가 진행됩니다. "
            "사건 확인 http://fss-verify.invalid/case/8821 담당 조사관 02-0000-1332"
        ),
    ),
    "phishing_prosecutor": SmsPreset(
        id="phishing_prosecutor",
        kind="phishing",
        category="impersonation",
        sender_name="서울중앙지검(사칭)",
        sender_phone="02-0000-1301",
        body=(
            "[서울중앙지검] 사건번호 2026-형제8821호 명의도용 금융사기 피의자 출석요구서 발송. "
            "본인 확인 http://spo-check.invalid/doc/8821 문의 02-0000-1301"
        ),
    ),
    "normal_delivery": SmsPreset(
        id="normal_delivery",
        kind="normal",
        category="delivery",
        sender_name="안심택배",
        sender_phone="02-0000-5880",
        body="[안심택배] 김순자님 주문하신 건강즙 상품이 오늘 오후 배송 완료되었습니다. 문 앞을 확인해 주세요.",
    ),
    "normal_family": SmsPreset(
        id="normal_family",
        kind="normal",
        category="family",
        sender_name="김사랑 (딸)",
        sender_phone="010-0000-1024",
        body="엄마, 이번 주말에 민준이랑 반찬 가지고 갈게요. 식사 꼭 챙겨 드세요!",
    ),
    "normal_bank": SmsPreset(
        id="normal_bank",
        kind="normal",
        category="bank",
        sender_name="핑거벨은행",
        sender_phone="02-0000-5990",
        body="[핑거벨] 김순자님 연금 650,000원이 입출금 통장(5678)으로 입금되었습니다.",
    ),
}

NORMAL_PRESET_ORDER: tuple[str, ...] = ("normal_delivery", "normal_family", "normal_bank")


def resolve_preset(kind: str | None, existing_count: int = 0) -> SmsPreset:
    key = (kind or "phishing").strip().lower()
    if key in SMS_PRESETS:
        return SMS_PRESETS[key]
    if key in ("scam", "danger", "phishing_fss"):
        return SMS_PRESETS["phishing"]
    if key in ("normal", "safe"):
        preset_id = NORMAL_PRESET_ORDER[existing_count % len(NORMAL_PRESET_ORDER)]
        return SMS_PRESETS[preset_id]
    return SMS_PRESETS["phishing"]


# ------------------------------------------------------------------ 9절 검증용 가상 문자 모음 (각 20건 이상)
SCAM_SMS_SAMPLES: tuple[tuple[str, str], ...] = (
    (
        "02-0000-1332",
        "[금융감독원] 귀하 명의 대포통장 개설 사건 접수. 즉시 본인 확인 바랍니다 http://fss-verify.invalid/1 문의 02-0000-1332",
    ),
    (
        "02-0000-1301",
        "[서울중앙지검] 사건번호 2026-8812 명의도용 사건 출석요구서 확인 http://spo-case.invalid/2 담당 수사관 02-0000-1301",
    ),
    (
        "02-0000-0112",
        "[경찰청 사이버수사대] 귀하의 계좌가 범죄 연루 정황으로 지급정지 예정입니다 http://police-check.invalid/3 02-0000-0112",
    ),
    (
        "02-0000-2100",
        "[법원 등기] 구속영장 및 압류 통지서가 발송되었습니다. 즉시 확인 http://court-post.invalid/4 문의 02-0000-2100",
    ),
    (
        "02-0000-1260",
        "[국세청] 미수령 환급금 480,000원 지급 안내. 기한 내 환급금 조회 http://nts-refund.invalid/5 상담 02-0000-1260",
    ),
    (
        "033-0000-1577",
        "[국민건강보험] 본인부담금 미수령 환급금 신청 안내 http://nhis-pay.invalid/6 고객센터 033-0000-1577",
    ),
    (
        "070-0000-9911",
        "[국외발신] 해외결제 890,000원 승인완료. 본인이 아닐 경우 즉시 확인 http://card-stop.invalid/7 070-0000-9911",
    ),
    (
        "010-0000-4411",
        "[국제발신] 해외직구 1,240,000원 결제완료. 신청하지 않으셨다면 즉시 신고 바랍니다 02-0000-8899",
    ),
    (
        "010-0000-3322",
        "[서민금융진흥원] 정부지원 저금리 대환대출 승인 완료. 기존 적금 해지 후 신청 http://loan-gov.invalid/9 02-0000-3322",
    ),
    (
        "070-0000-5511",
        "[금융감독원] 보이스피싱 피해 예방 안전계좌 이전 및 보호조치 안내 http://safe-acct.invalid/10 070-0000-5511",
    ),
    (
        "010-0000-6612",
        "[우체국 등기] 주소지 불명으로 법원 등기 반송 예정. 즉시 확인 바랍니다 http://epost-check.invalid/11",
    ),
    (
        "070-0000-7713",
        "[관세청] 해외 배송 물품 통관 보류. 개인통관번호 즉시 확인 http://customs-kr.invalid/12 문의 070-0000-7713",
    ),
    (
        "010-0000-8814",
        "엄마 나 폰이 고장나서 액정 파손 수리 맡겼어. 급하게 본인 확인 앱 설치 부탁해 http://repair-app.invalid/13",
    ),
    (
        "02-0000-9915",
        "[검찰청] 금융사기 사건 접수 통지. 만기 전 해지 후 안전계좌 보호조치 필요 http://prosecutor.invalid/14",
    ),
    (
        "070-0000-1116",
        "[국외발신] 계정 명의도용 감지. 원격제어 점검 앱 설치 후 즉시 확인 http://remote-help.invalid/15",
    ),
    (
        "010-0000-2217",
        "[건강보험공단] 장기요양 환급금 조회 및 계좌 등록 안내 http://nhis-claim.invalid/16 문의 02-0000-2217",
    ),
    (
        "02-0000-3318",
        "[지방검찰청] 대포통장 명의도용 사건번호 2026-1190 출석요구서 확인 http://daspo.invalid/17 02-0000-3318",
    ),
    (
        "070-0000-4419",
        "택배 주소지 불명 배송 보류입니다. 본인이 아닐 경우 즉시 확인 http://delivery-fix.invalid/18",
    ),
    (
        "010-0000-5520",
        "[경찰청] 악성코드 감염으로 계좌동결 위험. 보안 앱 설치 바로가기 http://cyber-cop.invalid/19",
    ),
    (
        "02-0000-6621",
        "[금융감독원] 이상거래 탐지로 지급정지 예정. 본인 아닐 시 조사관 연결 02-0000-6621 http://fss-alert.invalid/20",
    ),
    (
        "070-0000-7722",
        "[법원] 전자소송 압류 결정문 송달 안내. 즉시 확인 바랍니다 http://ecourt-doc.invalid/21",
    ),
    (
        "010-0000-8823",
        "[정부지원] 저금리 대환대출 승인 대상자 안내. 즉시 확인 http://gov-fund.invalid/22 상담 02-0000-8823",
    ),
)

NORMAL_SMS_SAMPLES: tuple[tuple[str, str], ...] = (
    ("02-0000-5880", "[안심택배] 김순자님 주문하신 건강즙 상품이 오늘 오후 배송 완료되었습니다. 문 앞을 확인해 주세요."),
    ("010-0000-1024", "엄마, 이번 주말에 민준이랑 반찬 가지고 갈게요. 식사 꼭 챙겨 드세요!"),
    ("02-0000-5990", "[핑거벨] 김순자님 연금 650,000원이 입출금 통장(5678)으로 입금되었습니다."),
    ("02-0000-5881", "[한마음택배] 고객님 상품이 경비실에 보관되었습니다. 좋은 하루 보내세요."),
    ("010-0000-2048", "할머니, 저 민준이에요! 오늘 학교 잘 다녀왔어요. 주말에 봬요."),
    ("010-0000-4471", "순자 언니, 내일 오전 10시에 경로당 모임 있는 거 잊지 않았지? 같이 가자."),
    ("02-0000-5990", "[핑거벨] 김순자님 아파트 관리비 96,000원이 자동이체 출금되었습니다."),
    ("02-0000-5990", "[핑거벨] 온누리 약국 12,400원 체크카드 결제가 완료되었습니다. 잔액 2,350,000원"),
    ("02-0000-5001", "[행복내과의원] 김순자님 내일 오전 10시 30분 정기 진료 예약일입니다. 신분증을 지참해 주세요."),
    ("02-0000-5002", "[온누리약국] 처방받으신 혈압약은 아침 식후 30분에 복용해 주세요."),
    ("02-0000-5003", "[행복마트] 오늘 주문하신 쌀 10kg과 과일 배달이 오후 4시에 출발합니다."),
    ("02-0000-5004", "[노인복지관] 이번 주 목요일 노래교실 수업은 2층 강당에서 진행됩니다."),
    ("010-0000-1024", "엄마, 오늘 날씨가 쌀쌀한데 외출하실 때 따뜻한 옷 입으세요."),
    ("02-0000-5990", "[핑거벨] 김사랑님으로부터 200,000원이 입금되었습니다."),
    ("02-0000-5005", "[아파트관리사무소] 내일 오후 2시부터 4시까지 단지 내 물탱크 청소가 진행됩니다."),
    ("02-0000-5006", "[주민센터] 어르신 독감 무료 예방접종 기간입니다. 가까운 지정 병원을 방문해 주세요."),
    ("010-0000-4471", "언니, 아까 준 김치 정말 맛있더라. 고마워 잘 먹을게!"),
    ("02-0000-5007", "[밝은안과의원] 김순자님 다음 주 화요일 오전 11시 검진 예약이 완료되었습니다."),
    ("02-0000-5882", "[푸른택배] 보내신 사과 상자가 김사랑님께 정상 배달 완료되었습니다."),
    ("02-0000-5990", "[핑거벨] 행복마트 38,600원 결제가 완료되었습니다."),
    ("02-0000-5008", "[동네미용실] 김순자 고객님 오늘 오후 2시 파마 예약 안내드립니다."),
    ("010-0000-1024", "엄마, 보내주신 참기름 잘 받았어요! 저녁에 전화드릴게요."),
)
