"""환경변수 기반 설정. 값은 FINGERBELL_ 접두어와 OPENROUTER_API_KEY를 씁니다."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

# 기본 DB는 실행 위치와 상관없이 backend/fingerbell.db
DEFAULT_DATABASE_URL = f"sqlite:///{(Path(__file__).resolve().parents[1] / 'fingerbell.db').as_posix()}"
DEFAULT_LLM_MODEL = "anthropic/claude-haiku-5.5"
DEFAULT_STT_MODEL = "openai/whisper-large-v3"


def _int(name: str, default: int) -> int:
    raw = os.getenv(name)
    if raw is None or raw.strip() == "":
        return default
    try:
        return int(raw)
    except ValueError as exc:
        raise ValueError(f"{name} 값은 정수여야 합니다: {raw!r}") from exc


@dataclass(frozen=True)
class Settings:
    database_url: str = DEFAULT_DATABASE_URL
    # 거래 보류 유지 시간 (기획서 5.7: 기본 30분 = 1800초)
    hold_seconds: int = 1800
    # 보류 후 본인 재확인 대기 시간 (기획서 5.7: 기본 24시간 = 86400초)
    reconfirm_seconds: int = 86400
    # 결제·모드 완화 요청의 보호자 승인 대기 시간 (기획서 5.7: 기본 3분 = 180초)
    approval_timeout_seconds: int = 180
    # 주의 모드 유지 시간 (기획서 5.1: 기본 24시간)
    caution_mode_hours: int = 24
    # SOS 동결 유지 시간 (기획서 5.9: 기본 24시간)
    freeze_hours: int = 24
    # 보호자 연결 QR/코드 유효 시간 (기획서 5.8: 기본 5분 = 300초)
    pairing_code_seconds: int = 300
    # 백그라운드 점검(타이머 만료) 주기
    tick_seconds: float = 1.0
    # OpenRouter LLM · 음성인식(STT) 설정 (기획서 5.5, 6절). 키가 없으면 모의 게이트웨이로 동작합니다.
    openrouter_api_key: str = ""
    llm_model: str = DEFAULT_LLM_MODEL
    llm_timeout_seconds: float = 5.0
    stt_model: str = DEFAULT_STT_MODEL
    stt_timeout_seconds: float = 5.0
    cors_origins: list[str] = field(default_factory=lambda: ["*"])

    @classmethod
    def from_env(cls) -> "Settings":
        origins = os.getenv("FINGERBELL_CORS_ORIGINS", "*")
        model = (os.getenv("FINGERBELL_LLM_MODEL") or "").strip() or cls.llm_model
        stt_model = (os.getenv("FINGERBELL_STT_MODEL") or "").strip() or cls.stt_model
        return cls(
            database_url=os.getenv("FINGERBELL_DATABASE_URL", cls.database_url),
            hold_seconds=_int("FINGERBELL_HOLD_SECONDS", cls.hold_seconds),
            reconfirm_seconds=_int("FINGERBELL_RECONFIRM_SECONDS", cls.reconfirm_seconds),
            approval_timeout_seconds=_int("FINGERBELL_APPROVAL_TIMEOUT", cls.approval_timeout_seconds),
            caution_mode_hours=_int("FINGERBELL_CAUTION_MODE_HOURS", cls.caution_mode_hours),
            freeze_hours=_int("FINGERBELL_FREEZE_HOURS", cls.freeze_hours),
            pairing_code_seconds=_int("FINGERBELL_PAIRING_CODE_SECONDS", cls.pairing_code_seconds),
            openrouter_api_key=(os.getenv("OPENROUTER_API_KEY") or "").strip(),
            llm_model=model,
            stt_model=stt_model,
            cors_origins=[o.strip() for o in origins.split(",") if o.strip()],
        )
