import 'dart:async';

import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_sms/feature_sms.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app_links.dart';
import '../companion_app.dart';
import '../ios/ios_chrome.dart';
import '../shell/feedback_service.dart';

Future<void> runSmsApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final config = ApiConfig.fromEnvironment();
  final repository = ApiFamilyRepository(FingerBellApi(config));
  final family = FamilyCubit(repository)..start();
  final shell = ShellCubit(const ShellState(), ProviderPrefsStore());
  await shell.loadPrefs();
  runApp(
    SmsApp(
      family: family,
      shell: shell,
      feedback: DeviceFeedback(),
      serverAddress: config.toString(),
    ),
  );
}

/// 핑거벨 문자 앱. iOS 메시지 앱 모양을 흉내 낸 대화 목록·대화 화면·위험 경고·링크 차단 화면을 전체 화면으로 보여 줍니다.
class SmsApp extends StatefulWidget {
  final FamilyCubit? family;
  final ShellCubit? shell;
  final LocalPrefsStore? store;
  final FeedbackOutput? feedback;
  final String? serverAddress;
  final Uri? initialLink;

  const SmsApp({
    super.key,
    this.family,
    this.shell,
    this.store,
    this.feedback,
    this.serverAddress,
    this.initialLink,
  });

  @override
  State<SmsApp> createState() => _SmsAppState();
}

class _SmsAppState extends State<SmsApp> {
  String? _selectedPhone;
  int _selectionTick = 0;
  String? _shownIncomingCallKey;

  String _memberIdFor(Persona persona, FamilySnapshot data) =>
      persona.memberId ?? data.guardian.banking?.id ?? 'guardian';

  void _handleLink(Uri uri, CompanionScope scope) {
    final link = AppLinks.parseSmsLink(uri);
    if (link == null) return;
    final data = scope.family.state.snapshot;
    if (data == null) return;
    final memberId = _memberIdFor(scope.shell.state.persona, data);
    final member = data.memberOrNull(memberId);
    String? nextPhone;
    if (link.kind == SmsLinkKind.conversation && link.senderPhone != null && member != null) {
      final exists = member.smsConversations.any((c) => c.senderPhone == link.senderPhone);
      if (exists) nextPhone = link.senderPhone;
    }
    if (!mounted) return;
    setState(() {
      _selectedPhone = nextPhone;
      _selectionTick += 1;
    });
  }

  void _handleEvent(FamilyEvent e, CompanionScope scope) {
    if (e.type == 'reset' && !e.fromThisDevice) {
      if (mounted) {
        setState(() {
          _selectedPhone = null;
          _selectionTick += 1;
        });
      }
      if (scope.isForeground && e.message.isNotEmpty) scope.shell.say(e.message);
      return;
    }
    if (!scope.isForeground) return;
    final data = scope.family.state.snapshot;
    final persona = scope.shell.state.persona;
    if (e.type == 'sms' && !e.fromThisDevice && e.message.isNotEmpty) {
      final mine = data != null ? _memberIdFor(persona, data) : persona.memberId;
      if (mine != null && mine == e.memberId) {
        final dangerSms = e.level == 'danger';
        scope.shell.say(
          e.message,
          vibrate: dangerSms ? const [80, 40, 80] : const [60],
          alertSound: dangerSms,
        );
      }
    }
  }

  void _checkIncomingCall(CompanionScope scope) {
    if (!scope.isForeground) return;
    final activeCall = scope.family.state.snapshot?.activeCall;
    if (activeCall == null || !activeCall.isRinging || scope.family.isCallEnding(activeCall.id)) {
      _shownIncomingCallKey = null;
      return;
    }
    final myId = scope.shell.state.persona.name;
    if (activeCall.calleeId != myId) return;
    final key = '${activeCall.id}:$myId';
    if (_shownIncomingCallKey == key) return;
    _shownIncomingCallKey = key;
    unawaited(AppLinks.openIncomingCall(scope.shell, callId: activeCall.id));
  }

  @override
  Widget build(BuildContext context) {
    return CompanionApp(
      title: '핑거벨 문자',
      host: 'sms',
      family: widget.family,
      shell: widget.shell,
      store: widget.store,
      feedback: widget.feedback,
      serverAddress: widget.serverAddress,
      initialLink: widget.initialLink,
      onLink: _handleLink,
      onEvent: _handleEvent,
      onStateSynced: _checkIncomingCall,
      builder: (context, _) {
        final highContrast = context.fb.cardBorder != null;
        final persona = context.select((ShellCubit s) => s.state.persona);
        final familyState = context.watch<FamilyCubit>().state;
        final data = familyState.data;
        final shell = context.read<ShellCubit>();
        final memberId = _memberIdFor(persona, data);
        return Theme(
          data: iosNoSplashTheme(context),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark,
            child: Scaffold(
              backgroundColor: Colors.white,
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
                      child: SmsSheet(
                        memberId: memberId,
                        asScreen: true,
                        initialSenderPhone: _selectedPhone,
                        selectionTick: _selectionTick,
                        onTapPhone: (phone) => AppLinks.openCall(
                          shell,
                          peer: 'counterpart',
                          phone: phone,
                        ),
                        onCallGuardian: persona == Persona.guardian
                            ? null
                            : () => AppLinks.openCall(shell, peer: 'guardian'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
