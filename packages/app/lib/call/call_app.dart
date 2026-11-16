import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_call/feature_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app_links.dart';
import '../companion_app.dart';
import '../shell/feedback_service.dart';

Future<void> runCallApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final config = ApiConfig.fromEnvironment();
  final repository = ApiFamilyRepository(FingerBellApi(config));
  final family = FamilyCubit(repository)..start();
  final shell = ShellCubit(const ShellState(), ProviderPrefsStore());
  await shell.loadPrefs();
  runApp(
    CallApp(
      family: family,
      shell: shell,
      feedback: DeviceFeedback(),
      serverAddress: config.toString(),
    ),
  );
}

/// 핑거벨 전화 앱.
/// 첫 화면에는 연락할 수 있는 가족 목록과 통화 버튼만 두고,
/// 발신·수신·통화 중 위험 경고와 시연 상대 화면은 전체 화면으로 엽니다.
class CallApp extends StatefulWidget {
  final FamilyCubit? family;
  final ShellCubit? shell;
  final LocalPrefsStore? store;
  final FeedbackOutput? feedback;
  final String? serverAddress;
  final Uri? initialLink;
  final RtcPeerSession Function()? rtcSessionFactory;
  final CallChunkRecorder Function()? chunkRecorderFactory;

  const CallApp({
    super.key,
    this.family,
    this.shell,
    this.store,
    this.feedback,
    this.serverAddress,
    this.initialLink,
    this.rtcSessionFactory,
    this.chunkRecorderFactory,
  });

  @override
  State<CallApp> createState() => _CallAppState();
}

class _CallAppState extends State<CallApp> {
  final _navKey = GlobalKey<NavigatorState>();
  Object? _activeCounterpartToken;
  Object? _activeCallToken;
  String? _activeCallRouteId;
  String? _shownIncomingCallKey;

  bool get _inCounterpart => _activeCounterpartToken != null;
  bool get _inCallRoute => _activeCallToken != null;

  RtcPeerSession _createRtcSession() =>
      widget.rtcSessionFactory?.call() ?? FlutterWebRtcPeerSession();

  CallChunkRecorder _createChunkRecorder() =>
      widget.chunkRecorderFactory?.call() ?? RecordChunkRecorder();

  void _handleLink(Uri uri, CompanionScope scope) {
    final data = scope.family.state.snapshot;
    if (data == null) return;
    final persona = scope.shell.state.persona;
    final link = AppLinks.parseCallLink(uri, localPersona: persona, snapshot: data);
    if (link == null) return;

    switch (link.kind) {
      case CallLinkKind.home:
        _navKey.currentState?.popUntil((r) => r.isFirst);
      case CallLinkKind.counterpart:
        unawaited(_openCounterpart());
      case CallLinkKind.incoming:
        _checkIncomingCall(scope, requiredCallId: link.callId);
      case CallLinkKind.dial:
        final resolved = _resolvePeerInfo(
          data,
          peerId: link.peerId!,
          fallbackPhone: link.phone,
          fallbackName: link.name,
        );
        if (resolved == null) {
          _navKey.currentState?.popUntil((r) => r.isFirst);
          return;
        }
        unawaited(
          _openCallRoute(
            scope,
            localParticipantId: persona.name,
            callerId: persona.name,
            calleeId: link.peerId!,
            peerName: resolved.name,
            peerPhone: resolved.phone,
          ),
        );
    }
  }

  ({String? name, String? phone})? _resolvePeerInfo(
    FamilySnapshot data, {
    required String peerId,
    String? fallbackPhone,
    String? fallbackName,
  }) {
    if (peerId == 'guardian') {
      final g = data.guardian;
      return (name: '보호자 ${g.name}', phone: g.phone);
    }
    if (peerId == 'senior' || peerId == 'child') {
      final m = data.memberOrNull(peerId);
      if (m == null) return null;
      return (name: m.label, phone: '앱 안 통화');
    }
    if (peerId == 'counterpart') {
      return (name: fallbackName, phone: fallbackPhone);
    }
    return null;
  }

  void _handleEvent(FamilyEvent e, CompanionScope scope) {
    if (e.type == 'reset' && !e.fromThisDevice) {
      _shownIncomingCallKey = null;
      _navKey.currentState?.popUntil((r) => r.isFirst);
      if (scope.isForeground && e.message.isNotEmpty) scope.shell.say(e.message);
    }
  }

  void _checkIncomingCall(CompanionScope scope, {String? requiredCallId}) {
    if (!scope.isForeground || _inCounterpart) return;
    final activeCall = scope.family.state.snapshot?.activeCall;
    if (activeCall == null ||
        !activeCall.isRinging ||
        scope.family.isCallEnding(activeCall.id)) {
      _shownIncomingCallKey = null;
      return;
    }
    if (requiredCallId != null && activeCall.id != requiredCallId) return;
    final myId = scope.shell.state.persona.name;
    if (activeCall.calleeId != myId) return;
    final key = '${activeCall.id}:$myId';
    if (_shownIncomingCallKey == key || _activeCallRouteId == activeCall.id) return;
    _shownIncomingCallKey = key;
    unawaited(
      _openCallRoute(
        scope,
        localParticipantId: myId,
        callerId: activeCall.callerId,
        calleeId: activeCall.calleeId,
        peerName: activeCall.peerName,
        peerPhone: activeCall.peerPhone,
        initialCallId: activeCall.id,
      ),
    );
  }

  Future<void> _openCallRoute(
    CompanionScope scope, {
    required String localParticipantId,
    required String callerId,
    required String calleeId,
    String? peerName,
    String? peerPhone,
    String? initialCallId,
  }) async {
    final nav = _navKey.currentState;
    if (nav == null) return;
    if (_inCallRoute || _inCounterpart) {
      final prevId = _activeCallRouteId;
      nav.popUntil((r) => r.isFirst);
      if (prevId != null && !scope.family.isCallEnding(prevId)) {
        final prevCall = scope.family.state.snapshot?.callOrNull(prevId);
        if (prevCall != null && !prevCall.isEnded) {
          try {
            await scope.family.endCall(prevId);
          } on ApiException {
            // 기존 통화 종료에 실패해도 새 통화 화면으로 넘어갑니다.
          }
        }
      }
    }
    if (!mounted) return;
    final token = Object();
    _activeCallToken = token;
    _activeCallRouteId = initialCallId;
    try {
      await nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _CallScreenPage(
            roleLabel: scope.shell.state.persona.label,
            localParticipantId: localParticipantId,
            callerId: callerId,
            calleeId: calleeId,
            peerName: peerName,
            peerPhone: peerPhone,
            initialCallId: initialCallId,
            rtcSession: _createRtcSession(),
            chunkRecorder: _createChunkRecorder(),
            onOpenCounterpart: () => _openCounterpart(singleDevicePreview: true),
            onSwitchCall: ({
              required String callerId,
              required String calleeId,
              String? peerName,
              String? peerPhone,
            }) => _openCallRoute(
              scope,
              localParticipantId: callerId,
              callerId: callerId,
              calleeId: calleeId,
              peerName: peerName,
              peerPhone: peerPhone,
            ),
          ),
        ),
      );
    } finally {
      if (identical(_activeCallToken, token)) {
        _activeCallToken = null;
        _activeCallRouteId = null;
      }
    }
  }

  Future<void> _openCounterpart({bool singleDevicePreview = false}) async {
    final nav = _navKey.currentState;
    if (nav == null || _inCounterpart) return;
    final token = Object();
    _activeCounterpartToken = token;
    try {
      await nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _CounterpartScreenPage(
            rtcSessionFactory: singleDevicePreview ? NoopRtcPeerSession.new : _createRtcSession,
            chunkRecorder: singleDevicePreview ? NoopChunkRecorder() : _createChunkRecorder(),
          ),
        ),
      );
    } finally {
      if (identical(_activeCounterpartToken, token)) {
        _activeCounterpartToken = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompanionApp(
      title: '핑거벨 전화',
      host: 'call',
      family: widget.family,
      shell: widget.shell,
      store: widget.store,
      feedback: widget.feedback,
      serverAddress: widget.serverAddress,
      navigatorKey: _navKey,
      initialLink: widget.initialLink,
      onLink: _handleLink,
      onEvent: _handleEvent,
      onStateSynced: _checkIncomingCall,
      builder: (context, scope) {
        final c = context.fb;
        final persona = context.select((ShellCubit s) => s.state.persona);
        final data = context.select((FamilyCubit f) => f.state.data);
        return Scaffold(
          backgroundColor: c.bg,
          body: Column(
            children: [
              CompanionHeader(title: '핑거벨 전화', roleLabel: persona.label),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CompanionOfflineBanner(),
                      _CallContactsHome(
                        persona: persona,
                        data: data,
                        onCall: ({
                          required String calleeId,
                          required String peerName,
                          required String peerPhone,
                        }) => _openCallRoute(
                          scope,
                          localParticipantId: persona.name,
                          callerId: persona.name,
                          calleeId: calleeId,
                          peerName: peerName,
                          peerPhone: peerPhone,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CallContactsHome extends StatelessWidget {
  final Persona persona;
  final FamilySnapshot data;
  final Future<void> Function({
    required String calleeId,
    required String peerName,
    required String peerPhone,
  }) onCall;

  const _CallContactsHome({
    required this.persona,
    required this.data,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    if (persona == Persona.guardian) {
      return FbView(
        children: [
          const Greeting('전화', sub: '연락할 가족을 고르세요'),
          if (data.members.isEmpty)
            const FbCard(child: EmptyText('연락할 수 있는 가족이 없어요'))
          else
            for (final m in data.members)
              FbCard(
                key: ValueKey('call-contact-${m.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        TxLogo.initial(m.name, blue: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.label, style: FbText.cardTitle(c)),
                              const SizedBox(height: 2),
                              Text('앱 안 통화 · 가족 안심 통화', style: FbText.small(c)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FbButton(
                      '${m.label}에게 전화하기',
                      icon: FbIcons.phone,
                      onPressed: () => onCall(
                        calleeId: m.id,
                        peerName: m.label,
                        peerPhone: '앱 안 통화',
                      ),
                    ),
                  ],
                ),
              ),
        ],
      );
    }

    final g = data.guardian;
    final me = data.accountOf(persona);
    final relation = me?.guardianRelation ?? '보호자';
    return FbView(
      children: [
        const Greeting('전화', sub: '연락할 가족을 고르세요'),
        FbCard(
          key: const ValueKey('call-contact-guardian'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TxLogo.initial(g.name, blue: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('보호자 ${g.name} ($relation)', style: FbText.cardTitle(c)),
                        const SizedBox(height: 2),
                        Text(
                          g.phone.isNotEmpty ? '${g.phone} · 가족 안심 통화' : '앱 안 통화 · 가족 안심 통화',
                          style: FbText.small(c),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FbButton(
                '보호자에게 전화하기',
                icon: FbIcons.phone,
                onPressed: () => onCall(
                  calleeId: 'guardian',
                  peerName: '보호자 ${g.name}',
                  peerPhone: g.phone,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CallScreenPage extends StatelessWidget {
  final String roleLabel;
  final String localParticipantId;
  final String callerId;
  final String calleeId;
  final String? peerPhone;
  final String? peerName;
  final String? initialCallId;
  final RtcPeerSession rtcSession;
  final CallChunkRecorder chunkRecorder;
  final Future<void> Function() onOpenCounterpart;
  final Future<void> Function({
    required String callerId,
    required String calleeId,
    String? peerName,
    String? peerPhone,
  }) onSwitchCall;

  const _CallScreenPage({
    required this.roleLabel,
    required this.localParticipantId,
    required this.callerId,
    required this.calleeId,
    required this.rtcSession,
    required this.chunkRecorder,
    required this.onOpenCounterpart,
    required this.onSwitchCall,
    this.peerPhone,
    this.peerName,
    this.initialCallId,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          CompanionHeader(title: '핑거벨 전화', roleLabel: roleLabel),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: CallSheet(
                localParticipantId: localParticipantId,
                callerId: callerId,
                calleeId: calleeId,
                peerPhone: peerPhone,
                peerName: peerName,
                initialCallId: initialCallId,
                rtcSession: rtcSession,
                chunkRecorder: chunkRecorder,
                onOpenCounterpart: onOpenCounterpart,
                onSwitchCall: onSwitchCall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterpartScreenPage extends StatelessWidget {
  final RtcPeerSession Function() rtcSessionFactory;
  final CallChunkRecorder chunkRecorder;

  const _CounterpartScreenPage({
    required this.rtcSessionFactory,
    required this.chunkRecorder,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          const CompanionHeader(title: '핑거벨 전화', roleLabel: '시연 상대'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: CounterpartSheet(
                rtcSessionFactory: rtcSessionFactory,
                chunkRecorder: chunkRecorder,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
