import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'chunk_recorder.dart';
import 'rtc_session.dart';

const List<CallScript> _fallbackScripts = [
  CallScript(
    id: 'phishing',
    kind: 'phishing',
    title: '사기 대본 (금융감독원 사칭 → 적금 해지 요구)',
    callerName: '금융감독원 민원실(사칭)',
    callerPhone: '02-0000-1332',
    lines: [
      '여기는 금융감독원 민원실 김철수 조사관입니다. 어르신 명의 대포통장이 개설되어 사건이 접수되었습니다.',
      '지금 당장 노후 적금을 만기 전 해지하시고 금융감독원 안전계좌로 전액 이체하셔야 자금을 보호할 수 있습니다.',
      '수사 기밀이니 가족이나 은행 직원에게는 절대 비밀로 하시고 지금 바로 처리해 주세요.',
    ],
  ),
  CallScript(
    id: 'normal',
    kind: 'normal',
    title: '정상 대본 (가족 안부)',
    callerName: '김사랑 (딸)',
    callerPhone: '010-0000-1024',
    lines: [
      '엄마, 오늘 점심 식사는 맛있게 챙겨 드셨어요?',
      '이번 주말에 민준이랑 좋아하는 반찬 가지고 집에 들를게요.',
      '날씨가 쌀쌀하니까 외출하실 때 따뜻한 옷 챙겨 입으세요.',
    ],
  ),
];

/// 시연 상대 화면 시트를 엽니다 (기획서 3절, 8절, 지시서 12번).
/// 은행 기능이 없는 시연 전용 화면입니다.
Future<void> openCounterpartSheet(
  BuildContext context, {
  RtcPeerSession? rtcSession,
  RtcPeerSession Function()? rtcSessionFactory,
  CallChunkRecorder? chunkRecorder,
}) => showFbSheet<void>(
  context,
  builder: (_) => CounterpartSheet(
    rtcSession: rtcSession,
    rtcSessionFactory: rtcSessionFactory,
    chunkRecorder: chunkRecorder,
  ),
);

class CounterpartSheet extends StatefulWidget {
  final RtcPeerSession? rtcSession;
  final RtcPeerSession Function()? rtcSessionFactory;
  final CallChunkRecorder? chunkRecorder;

  const CounterpartSheet({
    super.key,
    this.rtcSession,
    this.rtcSessionFactory,
    this.chunkRecorder,
  });

  @override
  State<CounterpartSheet> createState() => _CounterpartSheetState();
}

class _CounterpartSheetState extends State<CounterpartSheet> {
  RtcPeerSession? _rtc;
  bool _usedInitialRtc = false;
  late final CallChunkRecorder _recorder;
  StreamSubscription<Map<String, dynamic>>? _signalSub;

  String? _busyKey;
  String? _statusNote;
  String? _rtcStatus;
  String? _recordingError;
  String? _boundCallId;

  @override
  void initState() {
    super.initState();
    _recorder = widget.chunkRecorder ?? RecordChunkRecorder();
    final family = context.read<FamilyCubit>();
    _signalSub = family.rtcSignals.listen((signal) => _rtc?.onSignal(signal));
  }

  @override
  void dispose() {
    _signalSub?.cancel();
    _recorder.stop();
    _rtc?.close();
    _rtc = null;
    super.dispose();
  }

  Future<RtcPeerSession> _newRtcSession() async {
    final prev = _rtc;
    _rtc = null;
    if (prev != null) {
      await prev.close();
    }
    final RtcPeerSession next;
    if (widget.rtcSessionFactory != null) {
      next = widget.rtcSessionFactory!();
    } else if (widget.rtcSession != null && !_usedInitialRtc) {
      _usedInitialRtc = true;
      next = widget.rtcSession!;
    } else if (widget.rtcSession is NoopRtcPeerSession) {
      next = NoopRtcPeerSession(
        simulateFailure: (widget.rtcSession as NoopRtcPeerSession).simulateFailure,
      );
    } else {
      next = FlutterWebRtcPeerSession();
    }
    _rtc = next;
    return next;
  }

  void _onRtcStateChanged(String statusText) {
    if (!mounted) return;
    setState(() => _rtcStatus = statusText);
  }

  void _cleanupCallRuntime({String? note}) {
    _boundCallId = null;
    _rtcStatus = null;
    _recorder.stop();
    final prev = _rtc;
    _rtc = null;
    prev?.close();
    if (note != null && mounted) {
      setState(() => _statusNote = note);
    }
  }

  Future<void> _sendDemoSms(String kind) async {
    setState(() => _busyKey = 'sms-$kind');
    final family = context.read<FamilyCubit>();
    final shell = context.read<ShellCubit>();
    try {
      final res = await family.receiveSms('senior', kind: kind);
      if (!mounted) return;
      final label = kind == 'phishing' ? '사칭 문자' : '정상 문자';
      setState(() {
        _busyKey = null;
        _statusNote = '어르신 기기로 $label를 보냈어요 (${res.message.senderPhone})';
      });
      shell.say('어르신 기기로 $label를 보냈어요');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyKey = null);
      shell.say(e.message);
    }
  }

  Future<void> _dialSenior() async {
    setState(() => _busyKey = 'dial');
    final family = context.read<FamilyCubit>();
    final shell = context.read<ShellCubit>();
    try {
      await _recorder.stop();
      final rtc = await _newRtcSession();
      final call = await family.startCall(
        callerId: 'counterpart',
        calleeId: 'senior',
        peerPhone: '02-0000-1332',
        peerName: '금융감독원 민원실(사칭)',
      );
      if (!mounted) return;
      setState(() {
        _busyKey = null;
        _boundCallId = call.id;
        _statusNote = '어르신에게 전화를 걸고 있어요';
      });
      await rtc.startAsCaller(
        callId: call.id,
        localId: 'counterpart',
        sendSignal: family.sendRtcSignal,
        onStateChanged: _onRtcStateChanged,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyKey = null);
      shell.say(e.message);
    }
  }

  Future<void> _answerCall(CallSession call) async {
    setState(() => _busyKey = 'answer');
    final family = context.read<FamilyCubit>();
    final shell = context.read<ShellCubit>();
    try {
      await _recorder.stop();
      final rtc = await _newRtcSession();
      // 음성 연결 준비가 늦거나 멈춰도 전화 받기는 막히지 않게 기다리지 않습니다.
      unawaited(
        rtc.startAsCallee(
          callId: call.id,
          localId: 'counterpart',
          sendSignal: family.sendRtcSignal,
          onStateChanged: _onRtcStateChanged,
        ),
      );
      final active = await family.answerCall(call.id);
      if (!mounted) return;
      setState(() {
        _busyKey = null;
        _boundCallId = active.id;
        _statusNote = '전화를 받았어요 · 아래 대본 문장을 눌러 보낼 수 있어요';
      });
      if (active.analyzed) {
        await _recorder.start(
          onChunk: (b64, fmt) async {
            if (!mounted) return;
            try {
              await family.sendCallAudio(active.id, audioBase64: b64, audioFormat: fmt);
            } on ApiException {
              // 조각 업로드 실패 시에도 통화는 유지합니다.
            }
          },
          onFailure: (msg) {
            if (!mounted) return;
            setState(() => _recordingError = msg);
          },
        );
      }
      shell.say('어르신과의 통화가 연결되었어요');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyKey = null);
      shell.say(e.message);
    }
  }

  Future<void> _endCall(CallSession call) async {
    setState(() => _busyKey = 'end');
    _cleanupCallRuntime();
    if (!mounted) return;
    final family = context.read<FamilyCubit>();
    final shell = context.read<ShellCubit>();
    try {
      await family.endCall(call.id);
      if (!mounted) return;
      setState(() {
        _busyKey = null;
        _statusNote = '통화를 종료했어요';
      });
      shell.say('통화를 종료했어요');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyKey = null);
      shell.say(e.message);
    }
  }

  Future<void> _sendScriptLine(String line, {CallSession? activeCall}) async {
    setState(() => _busyKey = line);
    final family = context.read<FamilyCubit>();
    final shell = context.read<ShellCubit>();
    try {
      final callId = activeCall?.id ?? _boundCallId ?? 'active';
      final res = await family.sendCallTranscript(callId, text: line);
      if (!mounted) return;
      setState(() {
        _busyKey = null;
        _boundCallId = res.call?.id ?? _boundCallId;
        _statusNote = res.isDanger
            ? '사기 징후가 감지되어 어르신 통화 화면에 경고와 보호자 알림을 보냈어요'
            : '정상 대본 문장을 보냈어요 (경고 없음)';
      });
      if (res.isDanger) {
        shell.announceCallWarningOnce(
          res.call?.id ?? callId,
          '보이스피싱 위험 경고 · ${res.explanation}',
          toast: false,
          vibrate: const [200, 100, 200],
        );
      } else {
        shell.say('대본 문장을 보냈어요');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyKey = null);
      shell.say(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FamilyCubit, FamilyState>(
      listener: (context, state) {
        final boundId = _boundCallId;
        if (boundId == null) return;
        final boundCall = state.snapshot?.callOrNull(boundId);
        final activeCall = state.snapshot?.activeCall;
        if (boundCall == null || boundCall.isEnded || activeCall == null || activeCall.id != boundId || activeCall.isEnded) {
          _cleanupCallRuntime(note: '상대가 통화를 종료했어요');
        }
      },
      builder: (context, state) {
        final c = context.fb;
        final data = state.snapshot;
        final activeCall = data?.activeCall;
        final scripts = (data != null && data.callScripts.isNotEmpty) ? data.callScripts : _fallbackScripts;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHead(title: '시연 상대 화면'),
            Text(
              '사기범·가족 역할을 맡은 기기용 시연 전용 화면입니다 (은행 기능 없음).',
              style: FbText.hint(c),
            ),
            if (_statusNote != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: c.blueSoft, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  _statusNote!,
                  style: TextStyle(fontSize: 13.4, fontWeight: FontWeight.w700, color: c.blueStrong),
                ),
              ),
            ],
            const SizedBox(height: 14),
            // 1. 시연 문자 보내기
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('시연 문자 보내기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.ink)),
                  const SizedBox(height: 4),
                  Text('어르신 문자 화면으로 시연 문자를 바로 보냅니다.', style: FbText.small(c)),
                  const SizedBox(height: 12),
                  FbButtonRow(
                    children: [
                      FbButton(
                        '사칭 문자 보내기',
                        variant: FbButtonVariant.red,
                        busy: _busyKey == 'sms-phishing',
                        onPressed: _busyKey == null ? () => _sendDemoSms('phishing') : null,
                      ),
                      FbButton.gray(
                        '정상 문자 보내기',
                        busy: _busyKey == 'sms-normal',
                        onPressed: _busyKey == null ? () => _sendDemoSms('normal') : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // 2. 걸려 온 전화 받기 / 통화 연결
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: activeCall != null && activeCall.isRinging ? c.blueSoft : c.soft,
                borderRadius: BorderRadius.circular(16),
                border: activeCall != null && activeCall.isRinging ? Border.all(color: c.blue, width: 1.5) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(FbIcons.phone, size: 18, color: c.blueStrong),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          activeCall == null
                              ? '걸려 온 전화 대기 중'
                              : activeCall.isRinging
                              ? '걸려 온 전화 (${activeCall.peerPhone})'
                              : '통화 중 (${activeCall.peerPhone})',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.ink),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activeCall == null
                        ? '어르신 화면에서 문자 속 전화번호를 누르면 여기에 수신 버튼이 나타납니다.'
                        : activeCall.isRinging
                        ? '어르신 기기에서 전화가 걸려 왔어요. [전화 받기]를 눌러 연결하세요.'
                        : '통화가 연결되어 있어요. 아래 대본 문장을 눌러 보낼 수 있어요.',
                    style: FbText.small(c),
                  ),
                  if (_rtcStatus != null && activeCall != null && !activeCall.isEnded) ...[
                    const SizedBox(height: 6),
                    Text(
                      _rtcStatus!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _rtcStatus == rtcFailedText ? c.redStrong : c.ink2,
                      ),
                    ),
                  ],
                  if (_recordingError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _recordingError!,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.redStrong),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (activeCall != null && activeCall.isRinging)
                    FbButtonRow(
                      children: [
                        FbButton.gray(
                          '통화 끊기',
                          busy: _busyKey == 'end',
                          onPressed: _busyKey == null ? () => _endCall(activeCall) : null,
                        ),
                        FbButton(
                          '전화 받기',
                          icon: FbIcons.phone,
                          busy: _busyKey == 'answer',
                          onPressed: _busyKey == null ? () => _answerCall(activeCall) : null,
                        ),
                      ],
                    )
                  else if (activeCall != null && activeCall.isActive)
                    FbButton(
                      '통화 끊기',
                      variant: FbButtonVariant.red,
                      icon: FbIcons.phone,
                      busy: _busyKey == 'end',
                      onPressed: _busyKey == null ? () => _endCall(activeCall) : null,
                    )
                  else
                    FbButton.gray(
                      '어르신에게 전화 걸기',
                      icon: FbIcons.phone,
                      busy: _busyKey == 'dial',
                      onPressed: _busyKey == null ? _dialSenior : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // 3. 통화 대본 표시 및 대본 문장 보내기
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('통화 대본 · 대본 문장 보내기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.ink)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '음성인식 없이 문장을 보냅니다',
                      style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w700, color: c.blueStrong),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final script in scripts) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6, top: 4),
                      child: Text(
                        '${script.title} · ${script.callerPhone}',
                        style: TextStyle(
                          fontSize: 13.6,
                          fontWeight: FontWeight.w800,
                          color: script.isPhishing ? c.redStrong : c.ink2,
                        ),
                      ),
                    ),
                    for (var i = 0; i < script.lines.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ScriptLineTile(
                          key: ValueKey('script-${script.id}-$i'),
                          line: script.lines[i],
                          isPhishing: script.isPhishing,
                          busy: _busyKey == script.lines[i],
                          onTap: _busyKey == null ? () => _sendScriptLine(script.lines[i], activeCall: activeCall) : null,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScriptLineTile extends StatelessWidget {
  final String line;
  final bool isPhishing;
  final bool busy;
  final VoidCallback? onTap;

  const _ScriptLineTile({
    super.key,
    required this.line,
    required this.isPhishing,
    required this.busy,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Semantics(
      button: true,
      label: '대본 문장 보내기: $line',
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isPhishing ? c.redStrong : c.line, width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    line,
                    style: TextStyle(fontSize: 13.6, height: 1.5, color: c.ink, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                if (busy)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPhishing ? c.redSoft : c.blueSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '문장 보내기',
                      style: TextStyle(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w800,
                        color: isPhishing ? c.redStrong : c.blueStrong,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
