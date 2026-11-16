# FingerBell 백엔드 (FastAPI)

핑거벨의 핵심 시스템이 모두 서버에서 동작합니다. 앱은 결과를 그리기만 하고, 위험도·차단 여부·타이머는 서버가 정합니다.

| 파일 | 역할 |
| :--- | :--- |
| `app/main.py` | FastAPI 앱 팩토리, 라우트, WebSocket(실시간 이벤트 + WebRTC 연결 신호 전달), 1초마다 도는 타이머(동결·주의 모드 만료, 30분 보류 → 본인 재확인 전환, 24시간 재확인 만료, 결제·모드 요청 3분 타임아웃) |
| `app/service.py` | 업무 로직: 사건·주의 모드, 문자 수신·판정(위험 문자 보호자 알림·모의 푸시 포함), 통화 세션·신호·실시간 분석(4초 음성 조각·대본 문장), 송금·적금 해지·대출 판정(낮음/주의/위험)·보류(해제·연장·취소·재확인 및 보호자 알림), 보호자 연결 코드 발급·동의 기록, 불편한 점 의견 저장(`/feedback`), SOS 동결/해제, 결제 제어, 모드·한도, 상태 스냅샷 |
| `app/domain/banking.py` | 가상 은행 확장(적금 만기 전 해지 이자 계산, 대출 상품·월 납입액/총 이자 계산)과 주의 모드 확인 질문·종합 판정 1차 규칙 |
| `app/domain/sms.py` | 문자 1차 규칙 판정(기관 사칭·위험 키워드·링크·발신 번호 형태), 시연 문자 프리셋, 9절 정확도·오탐 검증용 가상 모음 |
| `app/domain/call.py` | 통화 1차 규칙 판정(기관 사칭·안전 계좌·해지/대출 요구·비밀 강요·재촉), 시연 통화 대본(사기·정상), 9절 정확도·오탐 검증용 가상 문장 모음 |
| `app/domain/fds.py` | AI FDS: 규칙 점수 + 사용자별 Isolation Forest (scikit-learn) |
| `app/domain/catalog.py` | 안심 모드, 업종 MCC, 시연 가맹점 |
| `app/integrations.py` | 오픈뱅킹 · FCM · SMS 어댑터(모의)와 OpenRouter LLM · 음성인식(STT) 게이트웨이(키가 없으면 모의, `OPENROUTER_API_KEY`가 있으면 OpenRouter 호출, 모델 기본값 `FINGERBELL_LLM_MODEL=anthropic/claude-haiku-5.5`, `FINGERBELL_STT_MODEL=openai/whisper-large-v3`) |
| `app/seed.py` | 시연 가족(김사랑 보호자, 김순자 어르신, 이민준 아이), 초기 정상 문자, FDS 학습용 과거 거래 |
| `scripts/eval_llm.py` | `OPENROUTER_API_KEY`가 있을 때 사람이 직접 실행하는 LLM 정확도·오탐·3회 일관성 평가 스크립트 |
| `tests/` | pytest 테스트 (규칙 단계 검증, LLM/STT 실패 대체, 대표 시나리오 종단 통합 테스트 `test_stage8_scenario.py` 포함) |

## 실행

저장소 루트에서 `.\run-backend.ps1`을 쓰는 것이 가장 쉽습니다. 직접 실행하려면:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m uvicorn app.asgi:app --host 127.0.0.1 --port 8765
```

## 테스트

```powershell
.\.venv\Scripts\python.exe -m pytest
```

`OPENROUTER_API_KEY`가 있을 때 실제 LLM 정확도·오탐·일관성을 보려면 아래 수동 스크립트를 실행합니다 (`pytest`/CI에서는 호출하지 않습니다).

```powershell
.\.venv\Scripts\python.exe scripts/eval_llm.py
```

테스트는 임시 SQLite와 고정된 시각(`app.clock.freeze_at`)을 써서, 30분 보류·24시간 만료·심야 판정을 실제로 기다리지 않고 확인합니다.

## 실제 연동으로 바꾸기

`app/integrations.py`의 `OpenBankingGateway`, `PushGateway`, `SmsGateway`와 같은 메서드를 가진 클래스를 만들고 `create_app(gateways=Gateways(...))`로 넘기면 됩니다.
