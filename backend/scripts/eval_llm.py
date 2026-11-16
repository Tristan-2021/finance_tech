"""9절 수동 LLM 검증 스크립트.

OPENROUTER_API_KEY가 설정되어 있을 때 사람이 직접 실행해
사기·정상 문자/통화 모음의 탐지 건수, 오탐 비율, 3회 반복 일관성을 출력합니다.
목표 수치는 코드에 고정하지 않고 사람이 판단합니다(기획서 9절·11절).

실행 예:
    cd backend
    $env:OPENROUTER_API_KEY="sk-or-..."
    .\\.venv\\Scripts\\python.exe scripts/eval_llm.py
"""

from __future__ import annotations

import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.config import Settings  # noqa: E402
from app.domain.call import NORMAL_CALL_SAMPLES, SCAM_CALL_SAMPLES, assess_call_rules  # noqa: E402
from app.domain.sms import NORMAL_SMS_SAMPLES, SCAM_SMS_SAMPLES, assess_sms_rules  # noqa: E402
from app.integrations import OpenRouterLlmGateway  # noqa: E402


def _pct(part: int, total: int) -> str:
    return f"{(part / total * 100):.1f}%" if total else "0.0%"


def _eval_sms(gw: OpenRouterLlmGateway) -> None:
    scam_danger = 0
    scam_flagged = 0
    scam_fallback = 0
    for phone, body in SCAM_SMS_SAMPLES:
        first_pass = assess_sms_rules(phone, body)
        verdict, _ = gw.judge_sms(phone, body, first_pass)
        if verdict.level == "danger":
            scam_danger += 1
        if verdict.level in ("caution", "danger"):
            scam_flagged += 1
        if verdict.source == "rule_fallback":
            scam_fallback += 1

    normal_fp = 0
    normal_danger = 0
    normal_fallback = 0
    for phone, body in NORMAL_SMS_SAMPLES:
        first_pass = assess_sms_rules(phone, body)
        verdict, _ = gw.judge_sms(phone, body, first_pass)
        if verdict.level != "low":
            normal_fp += 1
        if verdict.level == "danger":
            normal_danger += 1
        if verdict.source == "rule_fallback":
            normal_fallback += 1

    print("[문자 판정 결과]")
    print(
        f"- 사기 문자 탐지 (danger): {scam_danger}/{len(SCAM_SMS_SAMPLES)} "
        f"({_pct(scam_danger, len(SCAM_SMS_SAMPLES))}) | 주의+위험: {scam_flagged}/{len(SCAM_SMS_SAMPLES)} "
        f"({_pct(scam_flagged, len(SCAM_SMS_SAMPLES))}) | fallback={scam_fallback}"
    )
    print(
        f"- 정상 문자 오탐 (caution+danger): {normal_fp}/{len(NORMAL_SMS_SAMPLES)} "
        f"({_pct(normal_fp, len(NORMAL_SMS_SAMPLES))}) | danger 오탐={normal_danger} | fallback={normal_fallback}"
    )


def _eval_calls(gw: OpenRouterLlmGateway) -> None:
    scam_danger = 0
    scam_flagged = 0
    scam_fallback = 0
    for text in SCAM_CALL_SAMPLES:
        first_pass = assess_call_rules(text)
        verdict, _ = gw.judge_call(text, first_pass)
        if verdict.level == "danger":
            scam_danger += 1
        if verdict.level in ("caution", "danger"):
            scam_flagged += 1
        if verdict.source == "rule_fallback":
            scam_fallback += 1

    normal_fp = 0
    normal_danger = 0
    normal_fallback = 0
    for text in NORMAL_CALL_SAMPLES:
        first_pass = assess_call_rules(text)
        verdict, _ = gw.judge_call(text, first_pass)
        if verdict.level != "low":
            normal_fp += 1
        if verdict.level == "danger":
            normal_danger += 1
        if verdict.source == "rule_fallback":
            normal_fallback += 1

    print("[통화 전사문 판정 결과]")
    print(
        f"- 사기 통화 탐지 (danger): {scam_danger}/{len(SCAM_CALL_SAMPLES)} "
        f"({_pct(scam_danger, len(SCAM_CALL_SAMPLES))}) | 주의+위험: {scam_flagged}/{len(SCAM_CALL_SAMPLES)} "
        f"({_pct(scam_flagged, len(SCAM_CALL_SAMPLES))}) | fallback={scam_fallback}"
    )
    print(
        f"- 정상 통화 오탐 (caution+danger): {normal_fp}/{len(NORMAL_CALL_SAMPLES)} "
        f"({_pct(normal_fp, len(NORMAL_CALL_SAMPLES))}) | danger 오탐={normal_danger} | fallback={normal_fallback}"
    )


def _eval_consistency(gw: OpenRouterLlmGateway, sample_limit: int = 5) -> None:
    sms_inputs = list(SCAM_SMS_SAMPLES[:sample_limit]) + list(NORMAL_SMS_SAMPLES[:sample_limit])
    call_inputs = list(SCAM_CALL_SAMPLES[:sample_limit]) + list(NORMAL_CALL_SAMPLES[:sample_limit])

    sms_levels: list[list[str]] = [[] for _ in sms_inputs]
    call_levels: list[list[str]] = [[] for _ in call_inputs]

    for _ in range(3):
        gw.reset()
        for idx, (phone, body) in enumerate(sms_inputs):
            verdict, _ = gw.judge_sms(phone, body, assess_sms_rules(phone, body))
            sms_levels[idx].append(verdict.level)
        for idx, text in enumerate(call_inputs):
            verdict, _ = gw.judge_call(text, assess_call_rules(text))
            call_levels[idx].append(verdict.level)

    sms_consistent = sum(1 for run in sms_levels if len(set(run)) == 1)
    call_consistent = sum(1 for run in call_levels if len(set(run)) == 1)
    total = len(sms_inputs) + len(call_inputs)
    consistent = sms_consistent + call_consistent

    print("[3회 동일 입력 일관성 (캐시 비우고 3회 호출)]")
    print(f"- 문자: {sms_consistent}/{len(sms_inputs)} ({_pct(sms_consistent, len(sms_inputs))})")
    print(f"- 통화: {call_consistent}/{len(call_inputs)} ({_pct(call_consistent, len(call_inputs))})")
    print(f"- 합계: {consistent}/{total} ({_pct(consistent, total)})")


def main() -> int:
    settings = Settings.from_env()
    if not settings.openrouter_api_key:
        print(
            "OPENROUTER_API_KEY 환경변수가 설정되어 있지 않아 LLM 평가를 건너뜁니다.\n"
            "실행하려면 OPENROUTER_API_KEY(선택: FINGERBELL_LLM_MODEL)를 설정한 뒤 다시 실행하세요."
        )
        return 0

    print(f"OpenRouter LLM 평가 시작 (model={settings.llm_model})")
    gw = OpenRouterLlmGateway(
        api_key=settings.openrouter_api_key,
        model=settings.llm_model,
        timeout_seconds=settings.llm_timeout_seconds,
    )
    _eval_sms(gw)
    _eval_calls(gw)
    _eval_consistency(gw)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
