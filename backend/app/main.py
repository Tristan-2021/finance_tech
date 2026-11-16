"""FastAPI 앱 팩토리. 실행은 app.asgi 모듈을 쓰세요 (uvicorn app.asgi:app)."""

from __future__ import annotations

import asyncio
import logging
from collections.abc import Iterator
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import APIRouter, Depends, FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import inspect, select

from . import clock
from .config import Settings
from .db import Base, make_engine, make_session_factory
from .domain.fds import FdsEngine
from .events import EventHub
from .integrations import Gateways, make_gateways
from .models import Guardian
from .schemas import (
    ApprovalRequestBody,
    CallActionBody,
    CallAudioBody,
    CallbackDecision,
    CallSignalBody,
    CallStartBody,
    CallTranscriptBody,
    CautionQuestionBody,
    CautionReleaseBody,
    FeedbackBody,
    HoldCancelBody,
    HoldExtendBody,
    HoldReconfirmBody,
    LimitBody,
    LoanApplyBody,
    LoanLimitBody,
    LoanQuoteBody,
    MemberRequest,
    ModeBody,
    PairingCodeIssueBody,
    PairingConnectBody,
    PaymentBody,
    SavingsCancelBody,
    SleepGuardBody,
    SmsReceiveBody,
    SosFreezeRequest,
    TransferDraft,
    UnfreezeBody,
)
from .seed import reset_schema, schema_outdated, seed
from .service import DomainError, FamilyService

log = logging.getLogger("fingerbell")


def create_app(settings: Settings | None = None, gateways: Gateways | None = None) -> FastAPI:
    settings = settings or Settings.from_env()
    engine = make_engine(settings.database_url)
    sessions = make_session_factory(engine)
    fds = FdsEngine()
    hub = EventHub()
    gateways = gateways or make_gateways(settings)

    def ensure_seeded() -> None:
        if schema_outdated(engine):
            log.warning("DB 구조가 바뀌어 시연 데이터를 새로 만듭니다")
            reset_schema(engine)
        Base.metadata.create_all(engine)
        with sessions() as s:
            if s.scalars(select(Guardian).limit(1)).first() is None:
                seed(s)

    def run_tick() -> None:
        with sessions() as s:
            svc = FamilyService(s, settings, fds, gateways, hub)
            if svc.tick():
                svc.commit()
            else:
                s.rollback()

    async def ticker() -> None:
        while True:
            await asyncio.sleep(settings.tick_seconds)
            try:
                await asyncio.to_thread(run_tick)
            except Exception:  # 점검 하나가 실패해도 다음 점검은 계속합니다
                log.exception("tick failed")

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        hub.bind_loop(asyncio.get_running_loop())
        ensure_seeded()
        task = asyncio.create_task(ticker())
        try:
            yield
        finally:
            task.cancel()

    app = FastAPI(
        title="FingerBell API",
        description="핑거벨 안심 뱅킹 백엔드: 사건·주의 모드 · AI FDS · 거래 30분 보류 · SOS 계좌 동결 · 상황별 안심 모드",
        version="1.0.0",
        lifespan=lifespan,
    )
    app.state.settings = settings
    app.state.engine = engine
    app.state.sessions = sessions
    app.state.fds = fds
    app.state.gateways = gateways
    app.state.hub = hub
    app.state.run_tick = run_tick

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.exception_handler(DomainError)
    async def domain_error(_: Request, exc: DomainError):
        return JSONResponse({"error": {"code": exc.code, "message": exc.message, **exc.extra}}, status_code=exc.status)

    @app.exception_handler(RequestValidationError)
    async def invalid(_: Request, exc: RequestValidationError):
        return JSONResponse(
            {"error": {"code": "invalid", "message": "요청 형식이 올바르지 않아요.", "details": jsonable_encoder(exc.errors())}},
            status_code=422,
        )

    def service(request: Request) -> Iterator[FamilyService]:
        origin = request.headers.get("x-fingerbell-client")
        with sessions() as s:
            yield FamilyService(s, settings, fds, gateways, hub, origin=origin[:40] if origin else None)

    def done(svc: FamilyService, result):
        svc.commit()
        return result

    def check_guardian(svc: FamilyService, guardian_id: str) -> None:
        if svc.guardian().id != guardian_id:
            raise DomainError("forbidden", "보호자만 할 수 있어요.", 403)

    api = APIRouter(prefix="/api/v1")

    @api.get("/health")
    def health():
        return {"status": "ok", "time": clock.now().isoformat(), "realtime_clients": hub.client_count}

    @api.get("/state")
    def state(svc: FamilyService = Depends(service)):
        return svc.snapshot()

    # ---------------- 핵심 기능 1: 원터치 SOS 계좌 동결
    @api.post("/security/sos-freeze")
    @api.post("/emergency/freeze", include_in_schema=False)
    def sos_freeze(body: SosFreezeRequest, svc: FamilyService = Depends(service)):
        return done(svc, svc.freeze(body.user_id, body.trigger_type, body.sensor_intensity))

    @api.post("/security/unfreeze-request")
    def unfreeze_request(body: MemberRequest, svc: FamilyService = Depends(service)):
        return done(svc, svc.request_unfreeze(body.member_id))

    @api.post("/security/unfreeze")
    def unfreeze(body: UnfreezeBody, svc: FamilyService = Depends(service)):
        check_guardian(svc, body.guardian_id)
        return done(svc, svc.unfreeze(body.member_id))

    # ---------------- 사건과 주의 모드 (기획서 5.1)
    @api.post("/security/caution-mode/release")
    @api.post("/guardian/caution-mode/release", include_in_schema=False)
    def caution_release(body: CautionReleaseBody, svc: FamilyService = Depends(service)):
        check_guardian(svc, body.guardian_id)
        return done(svc, svc.release_caution_mode(body.member_id))

    # ---------------- 문자 수신 · 판정 (기획서 5.2, 5.5)
    @api.get("/sms")
    def list_sms(member_id: str = "senior", svc: FamilyService = Depends(service)):
        return svc.sms_list(member_id)

    @api.post("/sms/receive")
    @api.post("/sms/send", include_in_schema=False)
    @api.post("/demo/sms", include_in_schema=False)
    def receive_sms(body: SmsReceiveBody, svc: FamilyService = Depends(service)):
        return done(
            svc,
            svc.receive_sms(
                body.member_id,
                kind=body.kind,
                sender_phone=body.sender_phone,
                sender_name=body.sender_name,
                body=body.body,
            ),
        )

    # ---------------- 통화 세션 · 연결 신호 · 실시간 통화 분석 (기획서 5.3, 5.5)
    @api.get("/calls/scripts")
    def list_call_scripts(svc: FamilyService = Depends(service)):
        return svc.call_scripts()

    @api.get("/calls")
    @api.get("/calls/active", include_in_schema=False)
    def get_calls(svc: FamilyService = Depends(service)):
        return svc.call_state()

    @api.post("/calls/start")
    @api.post("/calls/dial", include_in_schema=False)
    @api.post("/calls", include_in_schema=False)
    def start_call(body: CallStartBody, svc: FamilyService = Depends(service)):
        return done(
            svc,
            svc.start_call(
                body.caller_id,
                body.callee_id,
                peer_phone=body.peer_phone,
                peer_name=body.peer_name,
            ),
        )

    @api.post("/calls/{call_id}/answer")
    def answer_call_by_id(call_id: str, svc: FamilyService = Depends(service)):
        return done(svc, svc.answer_call(call_id))

    @api.post("/calls/answer", include_in_schema=False)
    def answer_call(body: CallActionBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.answer_call(body.call_id))

    @api.post("/calls/{call_id}/end")
    @api.post("/calls/{call_id}/hangup", include_in_schema=False)
    def end_call_by_id(call_id: str, svc: FamilyService = Depends(service)):
        return done(svc, svc.end_call(call_id))

    @api.post("/calls/end", include_in_schema=False)
    @api.post("/calls/hangup", include_in_schema=False)
    def end_call(body: CallActionBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.end_call(body.call_id))

    @api.post("/calls/{call_id}/signal")
    def signal_call_by_id(call_id: str, body: CallSignalBody, svc: FamilyService = Depends(service)):
        return done(
            svc,
            svc.relay_call_signal(
                call_id,
                signal_type=body.signal_type,
                from_id=body.from_id,
                to_id=body.to_id,
                data=body.data,
                sdp=body.sdp,
                candidate=body.candidate,
            ),
        )

    @api.post("/calls/signal", include_in_schema=False)
    def signal_call(body: CallSignalBody, svc: FamilyService = Depends(service)):
        return done(
            svc,
            svc.relay_call_signal(
                body.call_id,
                signal_type=body.signal_type,
                from_id=body.from_id,
                to_id=body.to_id,
                data=body.data,
                sdp=body.sdp,
                candidate=body.candidate,
            ),
        )

    @api.post("/calls/{call_id}/audio")
    def analyze_call_audio_by_id(call_id: str, body: CallAudioBody, svc: FamilyService = Depends(service)):
        return done(
            svc,
            svc.analyze_call_audio(
                call_id,
                audio_base64=body.audio_base64,
                audio_format=body.audio_format,
            ),
        )

    @api.post("/calls/audio", include_in_schema=False)
    def analyze_call_audio(body: CallAudioBody, svc: FamilyService = Depends(service)):
        return done(
            svc,
            svc.analyze_call_audio(
                body.call_id,
                audio_base64=body.audio_base64,
                audio_format=body.audio_format,
            ),
        )

    @api.post("/calls/{call_id}/transcript")
    @api.post("/calls/{call_id}/text", include_in_schema=False)
    @api.post("/calls/{call_id}/analyze", include_in_schema=False)
    def analyze_call_transcript_by_id(call_id: str, body: CallTranscriptBody, svc: FamilyService = Depends(service)):
        sentence = body.text or body.transcript or body.sentence or ""
        return done(svc, svc.analyze_call_transcript(call_id, text=sentence))

    @api.post("/calls/transcript", include_in_schema=False)
    @api.post("/calls/text", include_in_schema=False)
    @api.post("/calls/analyze", include_in_schema=False)
    def analyze_call_transcript(body: CallTranscriptBody, svc: FamilyService = Depends(service)):
        sentence = body.text or body.transcript or body.sentence or ""
        return done(svc, svc.analyze_call_transcript(body.call_id, text=sentence))

    # ---------------- 핵심 기능 2: AI FDS + 거래 30분 보류 (기획서 5.5, 5.7)
    @api.post("/transaction/assess")
    def assess(body: TransferDraft, svc: FamilyService = Depends(service)):
        return svc.assess_transfer(body.member_id, body.to_draft())

    @api.post("/transaction/transfer")
    def transfer(body: TransferDraft, svc: FamilyService = Depends(service)):
        return done(svc, svc.submit_transfer(body.member_id, body.to_draft()))

    @api.post("/transaction/request-approval")
    def request_approval(body: ApprovalRequestBody, svc: FamilyService = Depends(service)):
        draft = {
            "new_account": {"bank": body.recipient_bank, "number": body.recipient_account, "name": body.recipient_name},
            "amount": body.amount,
        }
        result = svc.submit_transfer(body.sender_id, draft, force_approval=True)
        risk = result["risk"]
        return done(
            svc,
            {
                "transaction_id": result["request"]["id"],
                "status": "PENDING_APPROVAL",
                "hold_seconds": settings.hold_seconds,
                "timeout_seconds": settings.hold_seconds,
                "risk_score": risk["score"],
                "risk_level": risk["level"],
                "risk_reasons": [s["label"] for s in risk["signals"]],
                "explanation": risk["explanation"],
            },
        )

    @api.post("/transaction/cancel")
    def cancel_hold(body: HoldCancelBody, svc: FamilyService = Depends(service)):
        result = svc.cancel_request(body.request_id, body.member_id)
        return done(svc, {**result, "status": result["status"].upper()})

    @api.post("/transaction/reconfirm")
    def reconfirm_hold(body: HoldReconfirmBody, svc: FamilyService = Depends(service)):
        result = svc.reconfirm_hold(body.request_id, body.confirm, body.member_id)
        return done(svc, {**result, "status": result["status"].upper()})

    @api.post("/transaction/extend")
    def extend_hold(body: HoldExtendBody, svc: FamilyService = Depends(service)):
        check_guardian(svc, body.guardian_id)
        result = svc.extend_hold(body.request_id, body.reason)
        return done(svc, {**result, "status": result["status"].upper()})

    @api.post("/guardian/callback-decision")
    def callback_decision(body: CallbackDecision, svc: FamilyService = Depends(service)):
        check_guardian(svc, body.guardian_id)
        if body.decision == "EXTEND":
            result = svc.extend_hold(body.transaction_id, body.reason)
        else:
            result = svc.decide(body.transaction_id, body.decision in ("APPROVE", "RELEASE"), "guardian", body.reason)
        return done(svc, {"transaction_id": body.transaction_id, **result, "status": result["status"].upper()})

    # ---------------- 가상 은행 확장: 확인 질문 · 적금 해지 · 대출 (기획서 5.4, 5.5, 5.6)
    @api.post("/banking/question")
    @api.post("/caution/question", include_in_schema=False)
    def caution_question(body: CautionQuestionBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.get_confirmation_question(body.member_id, body.action_kind, body.amount))

    @api.post("/banking/savings/cancel")
    @api.post("/savings/cancel", include_in_schema=False)
    def cancel_savings(body: SavingsCancelBody, svc: FamilyService = Depends(service)):
        return done(
            svc,
            svc.cancel_savings(
                body.member_id,
                body.account_id,
                question_answer=body.question_answer,
                confirmed=body.confirmed,
            ),
        )

    @api.get("/banking/loan/product")
    def loan_product():
        from .domain.banking import LOAN_PRODUCT

        return {"product": LOAN_PRODUCT.to_dict()}

    @api.post("/banking/loan/quote")
    def loan_quote(body: LoanQuoteBody, svc: FamilyService = Depends(service)):
        return svc.loan_quote(body.amount)

    @api.post("/banking/loan/limit")
    @api.post("/loan/limit", include_in_schema=False)
    def loan_limit(body: LoanLimitBody, svc: FamilyService = Depends(service)):
        return done(
            svc,
            svc.check_loan_limit(
                body.member_id,
                question_answer=body.question_answer,
                confirmed=body.confirmed,
            ),
        )

    @api.post("/banking/loan/apply")
    @api.post("/loan/apply", include_in_schema=False)
    def loan_apply(body: LoanApplyBody, svc: FamilyService = Depends(service)):
        return done(
            svc,
            svc.apply_loan(
                body.member_id,
                body.amount,
                question_answer=body.question_answer,
                confirmed=body.confirmed,
            ),
        )

    # ---------------- 핵심 기능 3: 상황별 안심 모드 · 한도
    @api.post("/payments/pay")
    def pay(body: PaymentBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.pay(body.member_id, body.merchant_id))

    @api.post("/payments/request-approval")
    def pay_request(body: PaymentBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.request_payment(body.member_id, body.merchant_id))

    @api.post("/modes")
    def set_mode(body: ModeBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.set_mode(body.member_id, body.mode, body.actor.lower()))

    @api.post("/guardian/limits")
    def set_limit(body: LimitBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.set_daily_limit(body.member_id, body.daily_limit))

    @api.post("/guardian/sleep-guard")
    def sleep_guard(body: SleepGuardBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.set_sleep_guard(body.member_id, body.enabled))

    # ---------------- 보호자 연결 · 동의 (기획서 5.8)
    @api.post("/guardian/pairing-code")
    def issue_pairing_code(body: PairingCodeIssueBody, svc: FamilyService = Depends(service)):
        check_guardian(svc, body.guardian_id)
        return done(svc, svc.issue_pairing_code(body.member_id))

    @api.post("/pairing/connect")
    @api.post("/guardian/pairing/connect", include_in_schema=False)
    def connect_pairing(body: PairingConnectBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.connect_pairing(body.member_id, body.code, body.consented))

    # ---------------- 기타
    @api.post("/members/{member_id}/notices/{notice_id}/dismiss")
    def dismiss(member_id: str, notice_id: str, svc: FamilyService = Depends(service)):
        return done(svc, svc.dismiss_notice(member_id, notice_id))

    @api.get("/integrations/logs")
    def logs(limit: int = 30, svc: FamilyService = Depends(service)):
        return {"logs": svc.integration_logs(limit)}

    @api.post("/feedback")
    def submit_feedback(body: FeedbackBody, svc: FamilyService = Depends(service)):
        return done(svc, svc.submit_feedback(body.member_id, body.category, body.message))

    @api.post("/demo/reset")
    def demo_reset():
        reset_schema(engine)
        fds.reset()
        gateways.llm.reset()
        gateways.stt.reset()
        with sessions() as s:
            seed(s)
        hub.publish([{"type": "reset", "message": "시연 데이터를 처음 상태로 되돌렸어요"}])
        return {"status": "done"}

    @api.websocket("/ws")
    async def realtime(ws: WebSocket):
        await hub.connect(ws)
        try:
            await ws.send_json({"type": "hello", "message": ""})
            while True:
                # 앱이 보내는 ping 또는 WebRTC 연결 신호(offer / answer / ICE)를 받아 상대 기기에 전달합니다.
                raw = await ws.receive_text()
                if raw and raw != "ping":
                    await hub.relay(ws, raw)
        except WebSocketDisconnect:
            pass
        finally:
            hub.disconnect(ws)

    app.include_router(api)

    if settings.web_dir:
        web = Path(settings.web_dir)
        if (web / "index.html").is_file():
            app.mount("/", StaticFiles(directory=web, html=True), name="web")
        else:
            log.warning("FINGERBELL_WEB_DIR에 index.html이 없어 웹 앱을 제공하지 않습니다: %s", web)

    # 테스트와 첫 실행에서 테이블이 바로 필요할 수 있으므로 미리 만들어 둡니다
    if not inspect(engine).get_table_names():
        ensure_seeded()

    return app

