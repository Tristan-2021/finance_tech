import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'chunk_recorder.dart';
import 'counterpart_sheet.dart';
import 'rtc_session.dart';

/// 통화 중 위험 경고 진동 패턴 (총 0.5초, 3초 미만으로 한 번만 울립니다: 기획서 5.3, 7.3).
const List<int> callWarningVibration = [200, 100, 200];

/// 휴대폰 통화 화면 시트를 엽니다 (기획서 5.3).
Future<void> openCallSheet(
  BuildContext context, {
  String? localParticipantId,
  required String callerId,
  required String calleeId,
  String? peerPhone,
  String? peerName,
  String? initialCallId,
  RtcPeerSession? rtcSession,
  CallChunkRecorder? chunkRecorder,
}) => showFbSheet<void>(
  context,
  builder: (_) => CallSheet(
    localParticipantId: localParticipantId ?? callerId,
    callerId: callerId,
    calleeId: calleeId,
    peerPhone: peerPhone,
    peerName: peerName,
    initialCallId: initialCallId,
    rtcSession: rtcSession,
    chunkRecorder: chunkRecorder,
  ),
);

class CallSheet extends StatefulWidget {
  final String localParticipantId;
  final String callerId;
  final String calleeId;
  final String? peerPhone;
  final String? peerName;
  final String? initialCallId;
  final RtcPeerSession? rtcSession;
  final CallChunkRecorder? chunkRecorder;

  const CallSheet({
    super.key,
    required this.localParticipantId,
    required this.callerId,
    required this.calleeId,
    this.peerPhone,
    this.peerName,
    this.initialCallId,
    this.rtcSession,
    this.chunkRecorder,
  });

  @override
  State<CallSheet> createState() => _CallSheetState();
}

class _CallSheetState extends State<CallSheet> {
  late final FamilyCubit _family;
  late final RtcPeerSession _rtc;
  late final CallChunkRecorder _recorder;
  final FocusNode _hangupFocus = FocusNode();

  StreamSubscription<FamilyEvent>? _eventSub;
  StreamSubscription<Map<String, dynamic>>? _signalSub;

  String? _callId;
  bool _starting = false;
  bool _busy = false;
  bool _rtcStarted = false;
  bool _recordingStarted = false;
  bool _serverEnded = false;
  String? _rtcStatus;
  String? _recordingError;
  bool _warningAnnounced = false;
  String? _eventWarningExplanation;
  List<String> _eventWarningReasons = const [];

  @override
  void initState() {
    super.initState();
    _family = context.read<FamilyCubit>();
    _rtc = widget.rtcSession ?? FlutterWebRtcPeerSession();
    _recorder = widget.chunkRecorder ?? RecordChunkRecorder();
    _callId = widget.initialCallId;

    _eventSub = _family.events.listen(_onFamilyEvent);
    _signalSub = _family.rtcSignals.listen(_rtc.onSignal);

    if (_callId == null) {
      _initiateCall();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final existing = _family.state.snapshot?.callOrNull(_callId);
        if (existing != null) {
          _syncCallRuntime(existing);
        }
      });
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _signalSub?.cancel();
    _recorder.stop();
    _rtc.close();
    final id = _callId;
    if (id != null && !_serverEnded && !_family.isClosed) {
      _serverEnded = true;
      unawaited(
        _family.endCall(id).catchError(
              (_) => CallSession(
                id: id,
                callerId: widget.callerId,
                calleeId: widget.calleeId,
                status: CallStatus.ended,
                createdAt: DateTime.now(),
              ),
            ),
      );
    }
    _hangupFocus.dispose();
    super.dispose();
  }

  void _onRtcStateChanged(String statusText) {
    if (!mounted) return;
    setState(() => _rtcStatus = statusText);
  }

  void _stopCallMedia() {
    _recorder.stop();
    _rtc.close();
  }

  Future<void> _initiateCall() async {
    setState(() => _starting = true);
    final shell = context.read<ShellCubit>();
    try {
      final session = await _family.startCall(
        callerId: widget.callerId,
        calleeId: widget.calleeId,
        peerPhone: widget.peerPhone,
        peerName: widget.peerName,
      );
      if (!mounted) {
        _serverEnded = true;
        if (!_family.isClosed) {
          unawaited(_family.endCall(session.id).catchError((_) => session));
        }
        return;
      }
      setState(() {
        _callId = session.id;
        _starting = false;
      });
      _syncCallRuntime(session);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      shell.say(e.message);
    }
  }

  void _onFamilyEvent(FamilyEvent e) {
    if (!mounted) return;
    if (e.type == 'call_warning' && (e.callId == null || _callId == null || e.callId == _callId)) {
      final exp = (e.explanation?.isNotEmpty ?? false)
          ? e.explanation!
          : (e.message.isNotEmpty
                ? e.message
                : '기관을 사칭하거나 적금 해지·안전계좌 이체를 요구하는 보이스피싱 의심 통화예요. 지금 바로 통화를 끊으세요.');
      setState(() {
        _eventWarningExplanation = exp;
        if (e.reasons.isNotEmpty) _eventWarningReasons = e.reasons;
      });
      _announceWarningOnce(exp, callId: e.callId ?? _callId);
    }
  }

  void _announceWarningOnce(String explanation, {String? callId}) {
    if (_warningAnnounced) return;
    _warningAnnounced = true;
    final shell = context.read<ShellCubit>();
    shell.announceCallWarningOnce(
      callId ?? _callId ?? '',
      '보이스피싱 위험 경고 · $explanation',
      toast: false,
      vibrate: callWarningVibration,
      speak: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hangupFocus.requestFocus();
    });
  }

  void _syncCallRuntime(CallSession call) {
    if (!_rtcStarted && !call.isEnded) {
      if (widget.localParticipantId == call.callerId) {
        _rtcStarted = true;
        _rtc.startAsCaller(
          callId: call.id,
          localId: widget.localParticipantId,
          sendSignal: _family.sendRtcSignal,
          onStateChanged: _onRtcStateChanged,
        );
      } else if (call.isActive) {
        _rtcStarted = true;
        _rtc.startAsCallee(
          callId: call.id,
          localId: widget.localParticipantId,
          sendSignal: _family.sendRtcSignal,
          onStateChanged: _onRtcStateChanged,
        );
      }
    }

    if (call.isActive && call.analyzed && !_recordingStarted && _recordingError == null) {
      _recordingStarted = true;
      _recorder.start(
        onChunk: (b64, fmt) async {
          if (!mounted) return;
          try {
            await _family.sendCallAudio(call.id, audioBase64: b64, audioFormat: fmt);
          } on ApiException {
            // 조각 업로드 실패로 통화가 끊기지 않게 합니다.
          }
        },
        onFailure: (msg) {
          if (!mounted) return;
          setState(() => _recordingError = msg);
        },
      );
    }

    if (call.isDanger) {
      final exp = call.warningExplanation.isNotEmpty
          ? call.warningExplanation
          : '기관을 사칭하거나 적금 해지·안전계좌 이체를 요구하는 보이스피싱 의심 통화예요. 지금 바로 통화를 끊으세요.';
      _announceWarningOnce(exp, callId: call.id);
    }

    if (call.isEnded) {
      _serverEnded = true;
      _stopCallMedia();
    }
  }

  Future<void> _answerCall(String callId) async {
    setState(() => _busy = true);
    final shell = context.read<ShellCubit>();
    try {
      if (!_rtcStarted) {
        _rtcStarted = true;
        // 음성 연결 준비가 늦거나 멈춰도 전화 받기는 막히지 않게 기다리지 않습니다.
        unawaited(
          _rtc.startAsCallee(
            callId: callId,
            localId: widget.localParticipantId,
            sendSignal: _family.sendRtcSignal,
            onStateChanged: _onRtcStateChanged,
          ),
        );
      }
      final updated = await _family.answerCall(callId);
      if (!mounted) return;
      setState(() => _busy = false);
      _syncCallRuntime(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      shell.say(e.message);
    }
  }

  Future<void> _endCall(String? callId) async {
    final targetId = callId ?? _callId;
    await _recorder.stop();
    await _rtc.close();
    if (!mounted) return;
    if (targetId == null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _busy = true);
    final shell = context.read<ShellCubit>();
    try {
      _serverEnded = true;
      await _family.endCall(targetId);
      if (!mounted) return;
      setState(() => _busy = false);
      shell.say('통화를 종료했어요');
    } on ApiException {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    final targetId = _callId;
    _stopCallMedia();
    if (targetId != null && !_serverEnded && !_family.isClosed) {
      _serverEnded = true;
      try {
        await _family.endCall(targetId);
      } on ApiException {
        // 이미 종료되었거나 실패해도 시트는 닫습니다.
      }
    }
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _switchToGuardianCall({
    required String? callId,
    required String memberId,
    required Guardian? guardian,
  }) async {
    final nav = Navigator.of(context);
    final targetId = callId ?? _callId;
    if (mounted) setState(() => _busy = true);
    await _recorder.stop();
    await _rtc.close();
    if (targetId != null && !_serverEnded && !_family.isClosed) {
      _serverEnded = true;
      try {
        await _family.endCall(targetId);
      } on ApiException {
        // 기존 통화 종료 요청이 실패해도 보호자 통화로 전환합니다.
      }
    }
    await nav.maybePop();
    final navContext = nav.context;
    if (!navContext.mounted) return;
    await openCallSheet(
      navContext,
      callerId: memberId == 'guardian' ? 'senior' : memberId,
      calleeId: 'guardian',
      peerName: guardian != null && guardian.name.isNotEmpty ? '보호자 ${guardian.name}' : '보호자',
      peerPhone: guardian?.phone,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FamilyCubit, FamilyState>(
      listener: (context, state) {
        final call = state.snapshot?.callOrNull(_callId);
        if (call != null) {
          _syncCallRuntime(call);
        } else if (_callId != null && !_starting) {
          _serverEnded = true;
          _stopCallMedia();
        }
      },
      builder: (context, state) {
        final c = context.fb;
        final call = state.snapshot?.callOrNull(_callId);

        final status = call?.status ?? (_starting ? CallStatus.ringing : CallStatus.ended);
        final effectiveCallerId = call?.callerId ?? widget.callerId;
        final effectiveCalleeId = call?.calleeId ?? widget.calleeId;
        final isIncoming = status == CallStatus.ringing &&
            effectiveCalleeId == widget.localParticipantId &&
            effectiveCallerId != widget.localParticipantId;
        final analyzed = call?.analyzed ??
            ({effectiveCallerId, effectiveCalleeId}.contains('counterpart') &&
                ({effectiveCallerId, effectiveCalleeId}.contains('senior') ||
                    {effectiveCallerId, effectiveCalleeId}.contains('child')));

        final String peerName;
        final String peerPhone;
        if (widget.localParticipantId != effectiveCallerId && effectiveCallerId == 'guardian') {
          final g = state.snapshot?.guardian;
          peerName = g != null && g.name.isNotEmpty ? '보호자 ${g.name}' : '보호자';
          peerPhone = g != null && g.phone.isNotEmpty ? g.phone : '앱 안 통화';
        } else if (widget.localParticipantId == 'guardian' &&
            (effectiveCallerId == 'senior' || effectiveCallerId == 'child')) {
          final m = state.snapshot?.memberOrNull(effectiveCallerId);
          peerName = m?.label ?? ((call?.peerName.isNotEmpty ?? false) ? call!.peerName : '가족');
          peerPhone = '앱 안 통화';
        } else {
          peerName = (call?.peerName.isNotEmpty ?? false)
              ? call!.peerName
              : (widget.peerName ?? (effectiveCalleeId == 'guardian' ? '보호자' : '시연 상대'));
          peerPhone = (call?.peerPhone.isNotEmpty ?? false)
              ? call!.peerPhone
              : (widget.peerPhone ?? (effectiveCalleeId == 'guardian' ? '앱 안 통화' : '02-0000-1332'));
        }

        final hasWarning = (call?.isDanger ?? false) || _eventWarningExplanation != null;
        final warningExplanation = (call?.warningExplanation.isNotEmpty ?? false)
            ? call!.warningExplanation
            : (_eventWarningExplanation ??
                  '기관을 사칭하거나 적금 해지·안전계좌 이체를 요구하는 보이스피싱 의심 통화예요. 지금 바로 통화를 끊으세요.');
        final warningReasons = (call?.warningReasons.isNotEmpty ?? false) ? call!.warningReasons : _eventWarningReasons;

        final statusTitle = switch (status) {
          CallStatus.ringing => isIncoming ? '전화가 걸려 왔어요' : '발신 중...',
          CallStatus.active => '통화 중',
          CallStatus.ended => '통화가 종료되었어요',
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHead(title: '전화', onClose: _close),
            if (hasWarning) ...[
              _CallWarningBanner(
                explanation: warningExplanation,
                reasons: warningReasons,
                hangupFocus: _hangupFocus,
                busy: _busy,
                onHangup: () => _endCall(call?.id),
                onCallGuardian: () {
                  final member = effectiveCallerId == 'counterpart' ? effectiveCalleeId : effectiveCallerId;
                  _switchToGuardianCall(
                    callId: call?.id,
                    memberId: member,
                    guardian: state.snapshot?.guardian,
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: hasWarning ? c.redSoft : c.soft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: hasWarning ? c.red : c.blueSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasWarning ? FbIcons.alert : FbIcons.phone,
                      size: 30,
                      color: hasWarning ? Colors.white : c.blueStrong,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      statusTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: hasWarning ? c.redStrong : c.blueStrong,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    peerName,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    peerPhone,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink2),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      analyzed ? 'AI 실시간 보이스피싱 감지 작동 중' : '가족 안심 통화 · 통화 내용을 분석하지 않아요',
                      style: TextStyle(
                        fontSize: 12.6,
                        fontWeight: FontWeight.w700,
                        color: analyzed ? c.blueStrong : c.muted,
                      ),
                    ),
                  ),
                  if (_rtcStatus != null && status != CallStatus.ended) ...[
                    const SizedBox(height: 8),
                    Text(
                      _rtcStatus!,
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w700,
                        color: _rtcStatus == rtcFailedText ? c.redStrong : c.ink2,
                      ),
                    ),
                  ],
                  if (_recordingError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FbIcons.alert, size: 16, color: c.ink2),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _recordingError!,
                              style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w700, color: c.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (status == CallStatus.ringing && isIncoming && call != null)
              FbButtonRow(
                children: [
                  FbButton(
                    '통화 끊기',
                    variant: FbButtonVariant.red,
                    icon: FbIcons.close,
                    busy: _busy,
                    onPressed: _busy ? null : () => _endCall(call.id),
                  ),
                  FbButton(
                    '전화 받기',
                    icon: FbIcons.phone,
                    busy: _busy,
                    onPressed: _busy ? null : () => _answerCall(call.id),
                  ),
                ],
              )
            else if (status != CallStatus.ended) ...[
              FbButton(
                '통화 끊기',
                variant: FbButtonVariant.red,
                icon: FbIcons.phone,
                busy: _busy,
                onPressed: _busy ? null : () => _endCall(call?.id),
              ),
              if (analyzed && call != null) ...[
                const SizedBox(height: 8),
                FbButton.gray(
                  '시연 상대 화면 열기',
                  onPressed: () => openCounterpartSheet(
                    context,
                    rtcSession: NoopRtcPeerSession(),
                    chunkRecorder: NoopChunkRecorder(),
                  ),
                ),
              ],
            ] else
              FbButton('닫기', onPressed: _close),
          ],
        );
      },
    );
  }
}

/// 통화 화면 위에 뜨는 큰 경고 카드 (기획서 5.3, 7.3: 깜박이지 않음, 쉬운 설명 한 줄, 소리와 같은 글자, [통화 끊기]).
class _CallWarningBanner extends StatelessWidget {
  final String explanation;
  final List<String> reasons;
  final FocusNode hangupFocus;
  final bool busy;
  final VoidCallback onHangup;
  final VoidCallback? onCallGuardian;

  const _CallWarningBanner({
    required this.explanation,
    required this.reasons,
    required this.hangupFocus,
    required this.busy,
    required this.onHangup,
    this.onCallGuardian,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Semantics(
      liveRegion: true,
      container: true,
      label: '보이스피싱 위험 경고. $explanation',
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.redSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.redStrong, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Semantics(
                    label: '위험 경고',
                    child: Icon(FbIcons.alert, size: 24, color: c.redStrong),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '보이스피싱 위험 경고',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: c.redStrong,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                explanation,
                style: TextStyle(
                  fontSize: 15.2,
                  height: 1.5,
                  fontWeight: FontWeight.w800,
                  color: c.ink,
                ),
              ),
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final reason in reasons)
                  BulletText(
                    reason,
                    style: TextStyle(fontSize: 13.4, height: 1.5, color: c.ink2, fontWeight: FontWeight.w600),
                  ),
              ],
              const SizedBox(height: 14),
              Focus(
                focusNode: hangupFocus,
                child: FbButton(
                  '통화 끊기',
                  variant: FbButtonVariant.red,
                  icon: FbIcons.phone,
                  busy: busy,
                  onPressed: busy ? null : onHangup,
                ),
              ),
              const SizedBox(height: 10),
              FraudHelpButton(onCallGuardian: onCallGuardian),
            ],
          ),
        ),
      ),
    );
  }
}
