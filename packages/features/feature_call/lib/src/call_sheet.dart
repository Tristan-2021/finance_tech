import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'call_colors.dart';
import 'chunk_recorder.dart';
import 'rtc_session.dart';

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
  Duration endedAutoCloseDelay = const Duration(milliseconds: 900),
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
    endedAutoCloseDelay: endedAutoCloseDelay,
  ),
);

/// 일반 전화 앱 모양의 발신·수신·통화 중·위험 경고 화면.
class CallSheet extends StatefulWidget {
  final String localParticipantId;
  final String callerId;
  final String calleeId;
  final String? peerPhone;
  final String? peerName;
  final String? initialCallId;
  final RtcPeerSession? rtcSession;
  final CallChunkRecorder? chunkRecorder;
  final Duration endedAutoCloseDelay;
  final Future<void> Function({
    required String callerId,
    required String calleeId,
    String? peerName,
    String? peerPhone,
  })? onSwitchCall;

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
    this.endedAutoCloseDelay = const Duration(milliseconds: 900),
    this.onSwitchCall,
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
  Timer? _elapsedTimer;
  Timer? _endedTimer;

  String? _callId;
  bool _starting = false;
  bool _busy = false;
  bool _rtcStarted = false;
  bool _recordingStarted = false;
  bool _serverEnded = false;
  bool _localEnded = false;
  bool _endedScheduled = false;
  bool _muted = false;
  bool _speakerphone = false;
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
        } else {
          _scheduleEndedAutoClose();
        }
      });
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _endedTimer?.cancel();
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

  void _syncElapsedTimer(CallStatus status, DateTime? answeredAt) {
    if (status == CallStatus.active && answeredAt != null) {
      _elapsedTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _elapsedTimer?.cancel();
      _elapsedTimer = null;
    }
  }

  void _scheduleEndedAutoClose() {
    if (_endedScheduled) return;
    _endedScheduled = true;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _endedTimer = Timer(widget.endedAutoCloseDelay, () {
      if (mounted) Navigator.of(context).maybePop();
    });
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
      setState(() {
        _starting = false;
        _localEnded = true;
      });
      shell.say(e.message);
      _scheduleEndedAutoClose();
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

    _syncElapsedTimer(call.status, call.answeredAt);

    if (call.isEnded) {
      _serverEnded = true;
      _stopCallMedia();
      _scheduleEndedAutoClose();
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
      _localEnded = true;
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _busy = true);
    final shell = context.read<ShellCubit>();
    try {
      _serverEnded = true;
      await _family.endCall(targetId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _localEnded = true;
      });
      shell.say('통화를 종료했어요', toast: false);
      _scheduleEndedAutoClose();
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _localEnded = true;
      });
      _scheduleEndedAutoClose();
    }
  }

  void _toggleMute() {
    final next = !_muted;
    setState(() => _muted = next);
    unawaited(_rtc.setMicrophoneMuted(next));
  }

  void _toggleSpeaker() {
    final next = !_speakerphone;
    setState(() => _speakerphone = next);
    unawaited(_rtc.setSpeakerphoneEnabled(next));
  }

  Future<void> _switchToGuardianCall({
    required String? callId,
    required String memberId,
    required Guardian? guardian,
  }) async {
    final nav = Navigator.of(context);
    final targetId = callId ?? _callId;
    _endedTimer?.cancel();
    _elapsedTimer?.cancel();
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
    final switchCall = widget.onSwitchCall;
    if (switchCall != null) {
      await switchCall(
        callerId: memberId == 'guardian' ? 'senior' : memberId,
        calleeId: 'guardian',
        peerName: guardian != null && guardian.name.isNotEmpty ? '보호자 ${guardian.name}' : '보호자',
        peerPhone: guardian?.phone,
      );
      return;
    }
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

  static String _formatCallDuration(Duration d) {
    final total = d.isNegative ? 0 : d.inSeconds;
    final hours = total ~/ 3600;
    final mins = (total % 3600) ~/ 60;
    final secs = total % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (hours > 0) return '$hours:${two(mins)}:${two(secs)}';
    return '${two(mins)}:${two(secs)}';
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
          _scheduleEndedAutoClose();
        }
      },
      builder: (context, state) {
        final highContrast = context.fb.cardBorder != null;
        final call = state.snapshot?.callOrNull(_callId);

        final status = _localEnded
            ? CallStatus.ended
            : (call?.status ?? (_starting ? CallStatus.ringing : CallStatus.ended));
        final effectiveCallerId = call?.callerId ?? widget.callerId;
        final effectiveCalleeId = call?.calleeId ?? widget.calleeId;
        final isIncoming = status == CallStatus.ringing &&
            effectiveCalleeId == widget.localParticipantId &&
            effectiveCallerId != widget.localParticipantId;

        final String peerName;
        final String peerPhone;
        if (widget.localParticipantId != effectiveCallerId && effectiveCallerId == 'guardian') {
          final g = state.snapshot?.guardian;
          peerName = g != null && g.name.isNotEmpty ? '보호자 ${g.name}' : '보호자';
          peerPhone = g != null && g.phone.isNotEmpty ? g.phone : '';
        } else if (widget.localParticipantId == 'guardian' &&
            (effectiveCallerId == 'senior' || effectiveCallerId == 'child')) {
          final m = state.snapshot?.memberOrNull(effectiveCallerId);
          peerName = m?.label ?? ((call?.peerName.isNotEmpty ?? false) ? call!.peerName : '가족');
          peerPhone = '';
        } else {
          peerName = (call?.peerName.isNotEmpty ?? false)
              ? call!.peerName
              : (widget.peerName ?? (effectiveCalleeId == 'guardian' ? '보호자' : '시연 상대'));
          final rawPhone = (call?.peerPhone.isNotEmpty ?? false)
              ? call!.peerPhone
              : (widget.peerPhone ?? (effectiveCalleeId == 'guardian' ? '' : '02-0000-1332'));
          peerPhone = rawPhone == '앱 안 통화' ? '' : rawPhone;
        }

        final hasWarning = (call?.isDanger ?? false) || _eventWarningExplanation != null;
        final warningExplanation = (call?.warningExplanation.isNotEmpty ?? false)
            ? call!.warningExplanation
            : (_eventWarningExplanation ??
                  '기관을 사칭하거나 적금 해지·안전계좌 이체를 요구하는 보이스피싱 의심 통화예요. 지금 바로 통화를 끊으세요.');
        final warningReasons = (call?.warningReasons.isNotEmpty ?? false) ? call!.warningReasons : _eventWarningReasons;

        final String statusText;
        if (_starting) {
          statusText = '연결 중…';
        } else {
          switch (status) {
            case CallStatus.ringing:
              statusText = isIncoming ? '휴대전화' : '발신 중…';
            case CallStatus.active:
              final answeredAt = call?.answeredAt;
              statusText = answeredAt != null
                  ? _formatCallDuration(_family.now().difference(answeredAt))
                  : '연결 중…';
            case CallStatus.ended:
              statusText = '통화 종료';
          }
        }

        final palette = CallUiColors.of(highContrast: highContrast);
        final darkBg = palette.callBg;
        final statusSubColor = palette.callSubText;
        final nameColor = palette.callNameText;
        final actionLabelColor = palette.callActionLabel;
        final endedRedText = palette.callEndedText;
        final actionBorderColor = palette.callActionBorder;

        final mediaPadding = MediaQuery.paddingOf(context);
        final topPadding = (77.0 - mediaPadding.top).clamp(24.0, 77.0);
        final bottomPadding = (47.0 - mediaPadding.bottom).clamp(24.0, 47.0);

        final subStyle = TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w400,
          height: 1.35,
          letterSpacing: -0.23,
          color: status == CallStatus.ended ? endedRedText : statusSubColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        final displayName = peerName.isNotEmpty ? peerName : peerPhone;
        final subPhone = (peerName.isNotEmpty && peerPhone.isNotEmpty && peerPhone != peerName) ? peerPhone : '';

        final topSection = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              children: [
                Semantics(
                  liveRegion: status != CallStatus.active,
                  label: isIncoming && status == CallStatus.ringing && !_starting
                      ? '전화가 걸려 왔어요, $statusText'
                      : null,
                  excludeSemantics: isIncoming && status == CallStatus.ringing && !_starting,
                  child: Text(statusText, textAlign: TextAlign.center, style: subStyle),
                ),
                if (displayName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: nameColor,
                    ),
                  ),
                ],
                if (subPhone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subPhone,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                      letterSpacing: -0.23,
                      color: statusSubColor,
                    ),
                  ),
                ],
                if (_rtcStatus != null && status != CallStatus.ended) ...[
                  const SizedBox(height: 10),
                  Text(
                    _rtcStatus!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: _rtcStatus == rtcFailedText ? endedRedText : statusSubColor,
                    ),
                  ),
                ],
                if (_recordingError != null && status != CallStatus.ended) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: palette.callActionSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: actionBorderColor),
                    ),
                    child: Text(
                      _recordingError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

        final actionGradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.callActionSurfaceTop, palette.callActionSurfaceBottom],
        );

        final speakerButton = _CircleCallAction(
          icon: Icons.volume_up_rounded,
          label: '스피커',
          backgroundGradient: _speakerphone ? null : actionGradient,
          backgroundColor: _speakerphone ? Colors.white : palette.callActionSurface,
          foregroundColor: _speakerphone ? Colors.black : Colors.white,
          labelColor: actionLabelColor,
          circleSize: 78,
          borderColor: actionBorderColor,
          toggled: _speakerphone,
          onPressed: _toggleSpeaker,
        );

        final muteButton = _CircleCallAction(
          icon: Icons.mic_off_rounded,
          label: '소리 끔',
          backgroundGradient: _muted ? null : actionGradient,
          backgroundColor: _muted ? Colors.white : palette.callActionSurface,
          foregroundColor: _muted ? Colors.black : Colors.white,
          labelColor: actionLabelColor,
          circleSize: 78,
          borderColor: actionBorderColor,
          toggled: _muted,
          onPressed: _toggleMute,
        );

        final endButton = _CircleCallAction(
          icon: Icons.call_end_rounded,
          label: '종료',
          backgroundColor: palette.callEndRed,
          foregroundColor: Colors.white,
          labelColor: actionLabelColor,
          circleSize: 78,
          busy: _busy,
          onPressed: _busy ? null : () => _endCall(call?.id),
        );

        final bottomSection = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 354),
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  if (status == CallStatus.ringing && isIncoming && call != null)
                    Row(
                      children: [
                        Expanded(
                          child: _CircleCallAction(
                            icon: Icons.call_end_rounded,
                            label: '거절',
                            backgroundColor: palette.callDeclineRed,
                            foregroundColor: Colors.white,
                            labelColor: actionLabelColor,
                            circleSize: 78,
                            busy: _busy,
                            onPressed: _busy ? null : () => _endCall(call.id),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _CircleCallAction(
                            icon: Icons.call_rounded,
                            label: '받기',
                            backgroundColor: palette.callGreen,
                            foregroundColor: Colors.white,
                            labelColor: actionLabelColor,
                            circleSize: 78,
                            busy: _busy,
                            onPressed: _busy ? null : () => _answerCall(call.id),
                          ),
                        ),
                      ],
                    )
                  else if (status != CallStatus.ended) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: speakerButton),
                        const Expanded(child: SizedBox.shrink()),
                        Expanded(child: muteButton),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        Expanded(child: endButton),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        Widget buildWarningCard() => _CallWarningBanner(
          explanation: warningExplanation,
          reasons: warningReasons,
          hangupFocus: _hangupFocus,
          busy: _busy,
          redColor: palette.callEndRed,
          onHangup: () => _endCall(call?.id),
          onCallGuardian: () {
            final member = effectiveCallerId == 'counterpart' ? effectiveCalleeId : effectiveCallerId;
            _switchToGuardianCall(
              callId: call?.id,
              memberId: member,
              guardian: state.snapshot?.guardian,
            );
          },
        );

        return Theme(
          data: Theme.of(context).copyWith(
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ColoredBox(
            color: darkBg,
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (!constraints.hasBoundedHeight) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(14, topPadding, 14, bottomPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasWarning) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: buildWarningCard(),
                          ),
                          const SizedBox(height: 20),
                        ],
                        topSection,
                        bottomSection,
                      ],
                    ),
                  );
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(14, topPadding, 14, bottomPadding),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              topSection,
                              bottomSection,
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (hasWarning)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.62),
                          child: SafeArea(
                            child: Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 356),
                                  child: buildWarningCard(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// iOS 통화 화면의 동그란 아이콘 버튼과 아래 글자 라벨.
class _CircleCallAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Gradient? backgroundGradient;
  final Color foregroundColor;
  final Color labelColor;
  final double circleSize;
  final Color? borderColor;
  final bool? toggled;
  final bool busy;
  final VoidCallback? onPressed;

  const _CircleCallAction({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    this.backgroundGradient,
    required this.foregroundColor,
    required this.labelColor,
    this.circleSize = 78,
    this.borderColor,
    this.toggled,
    this.busy = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: toggled,
      label: busy ? '$label, 처리 중' : label,
      onTap: enabled ? onPressed : null,
      excludeSemantics: true,
      child: InkWell(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        onTap: enabled ? onPressed : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 78, minHeight: 78),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: enabled || busy ? 1 : 0.45,
                child: Container(
                  width: circleSize,
                  height: circleSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: backgroundGradient == null ? backgroundColor : null,
                    gradient: backgroundGradient,
                    shape: BoxShape.circle,
                    border: borderColor != null ? Border.all(color: borderColor!, width: 1) : null,
                  ),
                  child: busy
                      ? SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: foregroundColor),
                        )
                      : Icon(icon, size: 32, color: foregroundColor),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                      color: labelColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 통화 화면 위에 뜨는 iOS 스타일 위험 경고 카드 (기획서 5.3, 7.3: 깜박이지 않음, 쉬운 설명 한 줄, [통화 끊기]).
class _CallWarningBanner extends StatelessWidget {
  final String explanation;
  final List<String> reasons;
  final FocusNode hangupFocus;
  final bool busy;
  final Color redColor;
  final VoidCallback onHangup;
  final VoidCallback? onCallGuardian;

  const _CallWarningBanner({
    required this.explanation,
    required this.reasons,
    required this.hangupFocus,
    required this.busy,
    required this.redColor,
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: redColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Semantics(
                    label: '위험 경고',
                    child: Icon(FbIcons.alert, size: 26, color: redColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '보이스피싱 위험 경고',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: redColor,
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
                  fontWeight: FontWeight.w700,
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
              const SizedBox(height: 16),
              Focus(
                focusNode: hangupFocus,
                child: FilledButton.icon(
                  onPressed: busy ? null : onHangup,
                  icon: ExcludeSemantics(child: Icon(FbIcons.phone, size: 20, color: Colors.white)),
                  label: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Text(
                          '통화 끊기',
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: redColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: redColor.withValues(alpha: 0.6),
                    splashFactory: NoSplash.splashFactory,
                    minimumSize: const Size(57, 57),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
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
