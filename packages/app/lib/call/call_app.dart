import 'dart:async';
import 'dart:ui';

import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_call/feature_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app_links.dart';
import '../companion_app.dart';
import '../ios/ios_chrome.dart';
import '../shell/feedback_service.dart';
import 'call_lookup.dart';

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
/// 일반 전화 앱 모양(키패드 · 최근 기록 · 연락처)과 전체 화면 발신·수신·통화 중 화면을 제공합니다.
class CallApp extends StatefulWidget {
  final FamilyCubit? family;
  final ShellCubit? shell;
  final LocalPrefsStore? store;
  final FeedbackOutput? feedback;
  final String? serverAddress;
  final Uri? initialLink;
  final RtcPeerSession Function()? rtcSessionFactory;
  final CallChunkRecorder Function()? chunkRecorderFactory;
  final Duration callEndedAutoCloseDelay;

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
    this.callEndedAutoCloseDelay = const Duration(milliseconds: 900),
  });

  @override
  State<CallApp> createState() => _CallAppState();
}

enum _CallHomeTab {
  recent('최근 기록', Icons.access_time_filled_rounded),
  contacts('연락처', Icons.account_circle_rounded),
  keypad('키패드', Icons.dialpad_rounded);

  final String label;
  final IconData icon;
  const _CallHomeTab(this.label, this.icon);
}

class _CallAppState extends State<CallApp> {
  final _navKey = GlobalKey<NavigatorState>();
  _CallHomeTab _tab = _CallHomeTab.keypad;
  String _dialInput = '';
  String? _dialError;
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

  void _goHomeKeypad() {
    _navKey.currentState?.popUntil((r) => r.isFirst);
    if (mounted) {
      setState(() {
        _tab = _CallHomeTab.keypad;
        _dialError = null;
      });
    }
  }

  void _handleLink(Uri uri, CompanionScope scope) {
    final data = scope.family.state.snapshot;
    if (data == null) return;
    final persona = scope.shell.state.persona;
    final link = AppLinks.parseCallLink(uri, localPersona: persona, snapshot: data);
    if (link == null) return;

    switch (link.kind) {
      case CallLinkKind.home:
        _goHomeKeypad();
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
          _goHomeKeypad();
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
      var name = fallbackName;
      if ((name == null || name.isEmpty) && fallbackPhone != null) {
        final match = resolveCallTargetByPhone(data, fallbackPhone);
        if (match != null && match.peerId == 'counterpart') {
          name = match.peerName;
        }
      }
      return (name: name, phone: fallbackPhone);
    }
    return null;
  }

  void _handleEvent(FamilyEvent e, CompanionScope scope) {
    if (e.type == 'reset' && !e.fromThisDevice) {
      _shownIncomingCallKey = null;
      if (mounted) {
        setState(() {
          _dialInput = '';
          _dialError = null;
          _tab = _CallHomeTab.keypad;
        });
      }
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
            localParticipantId: localParticipantId,
            callerId: callerId,
            calleeId: calleeId,
            peerName: peerName,
            peerPhone: peerPhone,
            initialCallId: initialCallId,
            rtcSession: _createRtcSession(),
            chunkRecorder: _createChunkRecorder(),
            endedAutoCloseDelay: widget.callEndedAutoCloseDelay,
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

  void _appendDialChar(String ch) {
    if (_dialInput.length >= 16) return;
    setState(() {
      _dialInput += ch;
      _dialError = null;
    });
  }

  void _backspaceDial() {
    if (_dialInput.isEmpty && _dialError == null) return;
    setState(() {
      if (_dialInput.isNotEmpty) {
        _dialInput = _dialInput.substring(0, _dialInput.length - 1);
      }
      _dialError = null;
    });
  }

  void _clearDial() {
    if (_dialInput.isEmpty && _dialError == null) return;
    setState(() {
      _dialInput = '';
      _dialError = null;
    });
  }

  void _dialFromKeypad(CompanionScope scope, FamilySnapshot data, Persona persona) {
    if (_dialInput.trim().isEmpty) return;
    final target = resolveCallTargetByPhone(data, _dialInput, localPersona: persona);
    if (target == null) {
      setState(() => _dialError = '지금 거신 번호는 없는 번호입니다');
      return;
    }
    setState(() {
      _dialInput = '';
      _dialError = null;
    });
    unawaited(
      _openCallRoute(
        scope,
        localParticipantId: persona.name,
        callerId: persona.name,
        calleeId: target.peerId,
        peerName: target.peerName,
        peerPhone: target.peerPhone,
      ),
    );
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
        final highContrast = context.fb.cardBorder != null;
        final persona = context.select((ShellCubit s) => s.state.persona);
        final familyState = context.watch<FamilyCubit>().state;
        final data = familyState.data;
        final iosTheme = iosNoSplashTheme(context);
        return Theme(
          data: iosTheme,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark,
            child: Scaffold(
              backgroundColor: CallUiColors.of(highContrast: highContrast).homeBg,
              extendBody: true,
              body: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!familyState.reachable)
                      IosOfflineNoticeBar(
                        highContrast: highContrast,
                        onRetry: context.read<FamilyCubit>().refresh,
                      ),
                    Expanded(
                      child: switch (_tab) {
                        _CallHomeTab.keypad => _DialPadTab(
                            rawNumber: _dialInput,
                            errorMessage: _dialError,
                            highContrast: highContrast,
                            onDigit: _appendDialChar,
                            onBackspace: _backspaceDial,
                            onClear: _clearDial,
                            onCall: () => _dialFromKeypad(scope, data, persona),
                          ),
                        _CallHomeTab.recent => _RecentCallsTab(
                            entries: recentCallsForPersona(data, persona),
                            now: context.read<FamilyCubit>().now(),
                            highContrast: highContrast,
                            onCallEntry: (entry) => _openCallRoute(
                              scope,
                              localParticipantId: persona.name,
                              callerId: persona.name,
                              calleeId: entry.peerId,
                              peerName: entry.dialName,
                              peerPhone: entry.dialPhone,
                            ),
                          ),
                        _CallHomeTab.contacts => _ContactsTab(
                            persona: persona,
                            data: data,
                            highContrast: highContrast,
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
                      },
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: _CallBottomNav(
                current: _tab,
                highContrast: highContrast,
                onSelect: (next) {
                  if (_tab == next) return;
                  setState(() {
                    _tab = next;
                    _dialError = null;
                  });
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DialPadTab extends StatelessWidget {
  final String rawNumber;
  final String? errorMessage;
  final bool highContrast;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCall;

  const _DialPadTab({
    required this.rawNumber,
    required this.errorMessage,
    required this.highContrast,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onCall,
  });

  static const _rows = <List<String>>[
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['*', '0', '#'],
  ];

  @override
  Widget build(BuildContext context) {
    final palette = CallUiColors.of(highContrast: highContrast);
    final ink = palette.homeInk;
    final ink2 = palette.homeSubInk;
    final keyBg = palette.dialKeyBg;
    final green = palette.callGreen;
    final red = palette.homeErrorRed;
    final formatted = formatDialPadNumber(rawNumber);
    final navClearance = MediaQuery.paddingOf(context).bottom + 16;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, navClearance),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 54,
                          child: Center(
                            child: formatted.isEmpty
                                ? Text(
                                    '번호를 눌러 주세요',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: ink2),
                                  )
                                : Semantics(
                                    liveRegion: true,
                                    label: '입력한 번호 $formatted',
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        formatted,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.w400,
                                          color: ink,
                                          letterSpacing: 0.4,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (errorMessage != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: red),
                            ),
                          )
                        else
                          const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 304),
                      child: Column(
                        children: [
                          for (final row in _rows) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (final digit in row)
                                  _DialKeyButton(
                                    digit: digit,
                                    backgroundColor: keyBg,
                                    foregroundColor: ink,
                                    borderColor: highContrast ? palette.homeBorderHighContrast : null,
                                    onTap: () => onDigit(digit),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 15),
                          ],
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(width: 78, height: 78),
                              _DialCallButton(
                                key: const ValueKey('dial-call-button'),
                                green: green,
                                onTap: onCall,
                              ),
                              if (rawNumber.isNotEmpty)
                                _DialBackspaceButton(
                                  key: const ValueKey('dial-backspace-button'),
                                  iconColor: ink2,
                                  onTap: onBackspace,
                                  onLongPress: onClear,
                                )
                              else
                                const SizedBox(width: 78, height: 78),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DialKeyButton extends StatelessWidget {
  final String digit;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _DialKeyButton({
    required this.digit,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
    required this.onTap,
  });

  String get _semanticLabel => switch (digit) {
    '*' => '별표',
    '#' => '우물정',
    _ => digit,
  };

  @override
  Widget build(BuildContext context) {
    final keyId = switch (digit) {
      '*' => 'star',
      '#' => 'hash',
      _ => digit,
    };
    return Semantics(
      button: true,
      label: _semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        key: ValueKey('dial-key-$keyId'),
        color: backgroundColor,
        shape: CircleBorder(
          side: borderColor != null ? BorderSide(color: borderColor!, width: 1.5) : BorderSide.none,
        ),
        child: InkWell(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: const Color(0x18000000),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 78,
            height: 78,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  digit,
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: foregroundColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialCallButton extends StatelessWidget {
  final Color green;
  final VoidCallback onTap;

  const _DialCallButton({
    super.key,
    required this.green,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '통화',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: green,
        shape: const CircleBorder(),
        child: InkWell(
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: const Color(0x18000000),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 78,
            height: 78,
            child: Center(
              child: Icon(Icons.call_rounded, size: 34, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialBackspaceButton extends StatelessWidget {
  final Color iconColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DialBackspaceButton({
    super.key,
    required this.iconColor,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '지우기',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: const Color(0x14000000),
        customBorder: const CircleBorder(),
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 78,
          height: 78,
          child: Center(
            child: Icon(Icons.backspace_rounded, size: 26, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _RecentCallsTab extends StatelessWidget {
  final List<RecentCallEntry> entries;
  final DateTime now;
  final bool highContrast;
  final Future<void> Function(RecentCallEntry entry) onCallEntry;

  const _RecentCallsTab({
    required this.entries,
    required this.now,
    required this.highContrast,
    required this.onCallEntry,
  });

  @override
  Widget build(BuildContext context) {
    final palette = CallUiColors.of(highContrast: highContrast);
    final ink = palette.homeInk;
    final ink2 = palette.homeSubInk;
    final red = palette.homeErrorRed;
    final divider = palette.homeDivider;
    final navClearance = MediaQuery.paddingOf(context).bottom + 16;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Semantics(
            header: true,
            child: Text(
              '최근 기록',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: ink),
            ),
          ),
        ),
        Divider(height: 1, color: divider),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: navClearance),
                    child: Text(
                      '최근 기록이 없어요',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: ink2),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.only(bottom: navClearance),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => Divider(height: 1, indent: 48, color: divider),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final isMissed = entry.direction == CallDirection.missed;
                    final whenText = formatWhen(entry.session.createdAt, now);
                    final subDetail = entry.dialPhone.isNotEmpty &&
                            entry.dialPhone != '앱 안 통화' &&
                            entry.dialPhone != entry.displayTitle
                        ? entry.dialPhone
                        : '휴대전화';

                    return Semantics(
                      button: true,
                      label: '${entry.displayTitle}, ${entry.direction.label}, $subDetail, $whenText, 전화 걸기',
                      onTap: () => onCallEntry(entry),
                      excludeSemantics: true,
                      child: InkWell(
                        key: ValueKey('recent-call-${entry.session.id}'),
                        splashFactory: NoSplash.splashFactory,
                        splashColor: Colors.transparent,
                        highlightColor: const Color(0x0D000000),
                        onTap: () => onCallEntry(entry),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 62),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 11, 20, 11),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: entry.direction == CallDirection.outgoing
                                        ? Icon(Icons.phone_forwarded_rounded, size: 17, color: ink2)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.displayTitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: isMissed ? red : ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      if (isMissed)
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              '부재중',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: red,
                                              ),
                                            ),
                                            Text(
                                              ' · $subDetail',
                                              style: TextStyle(fontSize: 14, color: ink2),
                                            ),
                                          ],
                                        )
                                      else
                                        Text(
                                          subDetail,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 14, color: ink2),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 132),
                                  child: Text(
                                    whenText,
                                    textAlign: TextAlign.right,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      color: ink2,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ContactsTab extends StatelessWidget {
  final Persona persona;
  final FamilySnapshot data;
  final bool highContrast;
  final Future<void> Function({
    required String calleeId,
    required String peerName,
    required String peerPhone,
  }) onCall;

  const _ContactsTab({
    required this.persona,
    required this.data,
    required this.highContrast,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final palette = CallUiColors.of(highContrast: highContrast);
    final ink = palette.homeInk;
    final ink2 = palette.homeSubInk;
    final divider = palette.homeDivider;
    final avatarBg = palette.contactAvatarBg;
    final avatarFg = palette.contactAvatarFg;
    final navClearance = MediaQuery.paddingOf(context).bottom + 16;

    final List<({String keyId, String name, String? phone, String calleeId, String peerName, String peerPhone})> items;
    if (persona == Persona.guardian) {
      items = [
        for (final m in data.members)
          (
            keyId: 'call-contact-${m.id}',
            name: m.label,
            phone: null,
            calleeId: m.id,
            peerName: m.label,
            peerPhone: '앱 안 통화',
          ),
      ];
    } else {
      final g = data.guardian;
      final me = data.accountOf(persona);
      final relation = me?.guardianRelation ?? '보호자';
      items = [
        (
          keyId: 'call-contact-guardian',
          name: '보호자 ${g.name} ($relation)',
          phone: g.phone.isNotEmpty ? g.phone : null,
          calleeId: 'guardian',
          peerName: '보호자 ${g.name}',
          peerPhone: g.phone,
        ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Semantics(
            header: true,
            child: Text(
              '연락처',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: ink),
            ),
          ),
        ),
        Divider(height: 1, color: divider),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: navClearance),
                    child: Text(
                      '연락할 수 있는 가족이 없어요',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: ink2),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.only(bottom: navClearance),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => Divider(height: 1, indent: 78, color: divider),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final initialSource = item.peerName.replaceFirst('보호자 ', '').trim();
                    final initial = initialSource.isEmpty ? '?' : initialSource.characters.first;

                    return Semantics(
                      button: true,
                      label: item.phone != null ? '${item.name}, ${item.phone}, 전화 걸기' : '${item.name}, 전화 걸기',
                      onTap: () => onCall(
                        calleeId: item.calleeId,
                        peerName: item.peerName,
                        peerPhone: item.peerPhone,
                      ),
                      excludeSemantics: true,
                      child: InkWell(
                        key: ValueKey(item.keyId),
                        splashFactory: NoSplash.splashFactory,
                        splashColor: Colors.transparent,
                        highlightColor: const Color(0x0D000000),
                        onTap: () => onCall(
                          calleeId: item.calleeId,
                          peerName: item.peerName,
                          peerPhone: item.peerPhone,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 62),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: avatarBg,
                                    shape: BoxShape.circle,
                                    border: highContrast
                                        ? Border.all(color: palette.homeBorderHighContrast, width: 1.5)
                                        : null,
                                  ),
                                  child: Text(
                                    initial,
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: avatarFg),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ink),
                                      ),
                                      if (item.phone != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.phone!,
                                          style: TextStyle(fontSize: 14, color: ink2),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CallBottomNav extends StatelessWidget {
  final _CallHomeTab current;
  final bool highContrast;
  final ValueChanged<_CallHomeTab> onSelect;

  const _CallBottomNav({
    required this.current,
    required this.highContrast,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final palette = CallUiColors.of(highContrast: highContrast);
    final bg = palette.tabBarBg;
    final border = palette.tabBarBorder;
    final activeFg = palette.tabActiveBlue;
    final idleFg = palette.tabIdleGray;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border(top: BorderSide(color: border, width: highContrast ? 1.5 : 0.8)),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 58),
              child: Row(
                children: [
                  for (final tab in _CallHomeTab.values)
                    Expanded(
                      child: Semantics(
                        selected: current == tab,
                        button: true,
                        label: tab.label,
                        onTap: () => onSelect(tab),
                        excludeSemantics: true,
                        child: InkWell(
                          key: ValueKey('call-tab-${tab.name}'),
                          splashFactory: NoSplash.splashFactory,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () => onSelect(tab),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(tab.icon, size: 25, color: current == tab ? activeFg : idleFg),
                                const SizedBox(height: 3),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    tab.label,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: current == tab ? FontWeight.w600 : FontWeight.w500,
                                      color: current == tab ? activeFg : idleFg,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CallScreenPage extends StatelessWidget {
  final String localParticipantId;
  final String callerId;
  final String calleeId;
  final String? peerPhone;
  final String? peerName;
  final String? initialCallId;
  final RtcPeerSession rtcSession;
  final CallChunkRecorder chunkRecorder;
  final Duration endedAutoCloseDelay;
  final Future<void> Function({
    required String callerId,
    required String calleeId,
    String? peerName,
    String? peerPhone,
  }) onSwitchCall;

  const _CallScreenPage({
    required this.localParticipantId,
    required this.callerId,
    required this.calleeId,
    required this.rtcSession,
    required this.chunkRecorder,
    required this.endedAutoCloseDelay,
    required this.onSwitchCall,
    this.peerPhone,
    this.peerName,
    this.initialCallId,
  });

  @override
  Widget build(BuildContext context) {
    final highContrast = context.fb.cardBorder != null;
    final darkBg = CallUiColors.of(highContrast: highContrast).callBg;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: darkBg,
        body: SafeArea(
          child: CallSheet(
            localParticipantId: localParticipantId,
            callerId: callerId,
            calleeId: calleeId,
            peerPhone: peerPhone,
            peerName: peerName,
            initialCallId: initialCallId,
            rtcSession: rtcSession,
            chunkRecorder: chunkRecorder,
            endedAutoCloseDelay: endedAutoCloseDelay,
            onSwitchCall: onSwitchCall,
          ),
        ),
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
