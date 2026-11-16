import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fingerbell_app/app.dart';
import 'package:fingerbell_app/companion_app.dart';
import 'package:fingerbell_app/shell/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingPrefsStore implements LocalPrefsStore {
  @override
  Future<Map<String, Object?>> load() => Future.error(PlatformException(code: 'missing', message: 'not installed'));

  @override
  Future<void> saveBool(String key, bool value) => Future.error(UnsupportedError('read-only'));

  @override
  Future<void> saveString(String key, String value) => Future.error(UnsupportedError('read-only'));

  @override
  Future<void> clear() => Future.error(UnsupportedError('read-only'));
}

class _RecordingFeedback implements FeedbackOutput {
  final List<String> spoken = [];
  final List<List<int>> vibrated = [];
  int toneCount = 0;

  @override
  Future<void> playAlertTone() async {
    toneCount += 1;
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> vibrate(List<int> pattern, {bool playSound = true, bool playHaptics = true}) async {
    if (playHaptics) vibrated.add(pattern);
  }
}

void main() {
  testWidgets('CompanionApp falls back to defaults without crashing when reading fails', (tester) async {
    final repo = FakeFamilyRepository();
    final family = FamilyCubit(repo, pollInterval: null);
    await family.start();
    addTearDown(family.close);

    await tester.pumpWidget(
      CompanionApp(
        title: '핑거벨 문자',
        host: 'sms',
        family: family,
        store: _ThrowingPrefsStore(),
        builder: (context, _) {
          final persona = context.select((ShellCubit s) => s.state.persona);
          return Scaffold(body: Center(child: Text('현재 역할: ${persona.label}')));
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('현재 역할: 어르신'), findsOneWidget);

    final ctx = tester.element(find.text('현재 역할: 어르신'));
    expect(ctx.fb.cardBorder, isNull);
    expect(
      MediaQuery.textScalerOf(ctx).scale(1),
      closeTo(FingerBellApp.textFactor(const ShellState()), 1e-6),
    );
  });

  testWidgets('CompanionApp applies shared role, highContrast, textFactor and refreshes prefs + server on resume', (tester) async {
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    final store = MemoryPrefsStore({
      'persona': 'guardian',
      'highContrast': true,
      'largeText': true,
    });
    final repo = FakeFamilyRepository();
    final family = FamilyCubit(repo, pollInterval: null);
    await family.start();
    addTearDown(family.close);

    await tester.pumpWidget(
      CompanionApp(
        title: '핑거벨 전화',
        host: 'call',
        family: family,
        store: store,
        builder: (context, _) {
          final persona = context.select((ShellCubit s) => s.state.persona);
          return Scaffold(body: Center(child: Text('현재 역할: ${persona.label}')));
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('현재 역할: 보호자'), findsOneWidget);
    var ctx = tester.element(find.text('현재 역할: 보호자'));
    expect(ctx.fb.cardBorder, isNotNull);
    expect(
      MediaQuery.textScalerOf(ctx).scale(1),
      closeTo(
        FingerBellApp.textFactor(
          const ShellState(
            persona: Persona.guardian,
            prefs: AppPrefs(highContrast: true, largeText: true),
          ),
        ),
        1e-6,
      ),
    );

    final fetchesBeforeResume = repo.calls.where((c) => c == 'fetchState').length;

    // 핑거벨에서 초기화(어르신·기본 설정)한 뒤 앱으로 돌아오면(resume) 설정과 서버 상태를 다시 읽습니다.
    await store.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('현재 역할: 어르신'), findsOneWidget);
    expect(repo.calls.where((c) => c == 'fetchState').length, greaterThan(fetchesBeforeResume));
    ctx = tester.element(find.text('현재 역할: 어르신'));
    expect(ctx.fb.cardBorder, isNull);
    expect(
      MediaQuery.textScalerOf(ctx).scale(1),
      closeTo(FingerBellApp.textFactor(const ShellState()), 1e-6),
    );
  });

  testWidgets('CompanionApp delivers FeedbackOutput respecting shared sound, haptics, and voice prefs', (tester) async {
    final store = MemoryPrefsStore({'sound': true, 'haptics': true, 'voice': true});
    final repo = FakeFamilyRepository();
    final family = FamilyCubit(repo, pollInterval: null);
    await family.start();
    addTearDown(family.close);
    final feedback = _RecordingFeedback();

    late ShellCubit capturedShell;
    await tester.pumpWidget(
      CompanionApp(
        title: '핑거벨 문자',
        host: 'sms',
        family: family,
        store: store,
        feedback: feedback,
        builder: (context, scope) {
          capturedShell = scope.shell;
          return const Scaffold(body: Center(child: Text('본문')));
        },
      ),
    );
    await tester.pumpAndSettle();

    capturedShell.say('위험 문자 안내', vibrate: const [80, 40, 80], alertSound: true, speak: true);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('위험 문자 안내'), findsOneWidget);
    expect(feedback.toneCount, 1);
    expect(feedback.vibrated, [const [80, 40, 80]]);
    expect(feedback.spoken, ['위험 문자 안내']);
  });

  testWidgets('CompanionApp suppresses FeedbackOutput and toast while paused', (tester) async {
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));

    final store = MemoryPrefsStore({'sound': true, 'haptics': true, 'voice': true});
    final repo = FakeFamilyRepository();
    final family = FamilyCubit(repo, pollInterval: null);
    await family.start();
    addTearDown(family.close);
    final feedback = _RecordingFeedback();

    late ShellCubit capturedShell;
    await tester.pumpWidget(
      CompanionApp(
        title: '핑거벨 전화',
        host: 'call',
        family: family,
        store: store,
        feedback: feedback,
        builder: (context, scope) {
          capturedShell = scope.shell;
          return const Scaffold(body: Center(child: Text('본문')));
        },
      ),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    capturedShell.announceCallWarningOnce(
      'paused-companion-call',
      '백그라운드 통화 경고',
      toast: true,
      vibrate: callWarningVibration,
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('백그라운드 통화 경고'), findsNothing);
    expect(feedback.toneCount, 0);
    expect(feedback.vibrated, isEmpty);
    expect(feedback.spoken, isEmpty);
  });
}
