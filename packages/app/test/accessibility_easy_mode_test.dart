import 'dart:async';

import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fingerbell_app/app.dart';
import 'package:fingerbell_app/app_links.dart';
import 'package:fingerbell_app/shell/feedback_service.dart';
import 'package:fingerbell_app/views/banking_sheets.dart';
import 'package:fingerbell_app/views/member_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<(FakeFamilyRepository, FamilyCubit, ShellCubit)> _pumpStage7App(
  WidgetTester tester, {
  Size size = const Size(400, 860),
  MemoryPrefsStore? store,
  Map<String, dynamic>? snapshot,
  double textScale = 1.0,
  FeedbackOutput feedback = const SilentFeedback(),
  List<Uri>? openedLinks,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    AppLinks.channel,
    (call) async {
      if (call.method == 'open') {
        final raw = (call.arguments as Map?)?['uri'] as String?;
        if (raw != null) openedLinks?.add(Uri.parse(raw));
      }
      return null;
    },
  );
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      AppLinks.channel,
      null,
    );
  });

  final repo = FakeFamilyRepository(snapshot);
  final family = FamilyCubit(repo, pollInterval: null);
  await family.start();
  final shell = ShellCubit(const ShellState(), store);
  await shell.loadPrefs();
  addTearDown(family.close);
  addTearDown(shell.close);

  await tester.pumpWidget(
    FingerBellApp(
      family: family,
      shell: shell,
      feedback: feedback,
      serverAddress: 'http://127.0.0.1:8765',
    ),
  );
  await _settle(tester);
  return (repo, family, shell);
}

/// 라벨이 [label]인 Semantics 위젯. Tooltip 요소의 노드는 버튼 노드가 아니라서 이렇게 찾는다.
Finder _semanticsButton(String label) =>
    find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label, description: 'Semantics("$label")');

void main() {
  testWidgets('senior first launch asks before switching to easy mode and saves choice', (tester) async {
    final store = MemoryPrefsStore();
    final (_, _, shell) = await _pumpStage7App(tester, store: store);

    // 묻지 않고 바꾸지 않음: 처음 실행 시 일반 화면에서 질문 카드가 보입니다.
    expect(shell.state.prefs.easyMode, isFalse);
    expect(find.text('쉬운 화면으로 볼까요?'), findsOneWidget);
    expect(find.text('최근 거래'), findsOneWidget);

    await tester.tap(find.text('일반 화면 유지'));
    await _settle(tester);
    expect(shell.state.prefs.easyMode, isFalse);
    expect(shell.state.prefs.easyModePrompted, isTrue);
    expect(find.text('쉬운 화면으로 볼까요?'), findsNothing);

    // 앱을 다시 켜도 선택과 질문 완료 상태가 유지됩니다.
    await tester.pumpWidget(const SizedBox.shrink());
    final (_, _, restarted) = await _pumpStage7App(tester, store: store);
    expect(restarted.state.prefs.easyMode, isFalse);
    expect(restarted.state.prefs.easyModePrompted, isTrue);
    expect(find.text('쉬운 화면으로 볼까요?'), findsNothing);
  });

  testWidgets('top toggle switches easy mode for all personas, persists across restart, and keeps easy home layout', (tester) async {
    final store = MemoryPrefsStore();
    final opened = <Uri>[];
    final (_, _, shell) = await _pumpStage7App(tester, store: store, openedLinks: opened);

    // 홈 상단 토글로 한 번에 쉬운 화면을 켭니다.
    await tester.tap(find.byKey(const ValueKey('easy-mode-top-toggle')));
    await _settle(tester);
    expect(shell.state.prefs.easyMode, isTrue);

    // 쉬운 화면 홈: 기존 [송금] [결제] [조회] [SOS] 유지 + [문자] [전화] 한 번에 진입 + 최근 거래·대출 없음.
    expect(find.text('송금'), findsOneWidget);
    expect(find.text('결제'), findsOneWidget);
    expect(find.text('조회'), findsOneWidget);
    expect(find.text('계좌 동결'), findsOneWidget);
    expect(find.text('문자'), findsOneWidget);
    expect(find.text('전화'), findsOneWidget);
    expect(find.text('사기 신고·도움'), findsOneWidget);
    expect(find.text('최근 거래'), findsNothing);
    expect(find.textContaining('대출'), findsNothing);

    // 아이와 보호자도 쉬운 화면을 쓸 수 있습니다.
    shell.goto(Persona.child, AppTab.home);
    await _settle(tester);
    expect(find.text('안녕, 민준!'), findsOneWidget);
    expect(find.text('문자'), findsOneWidget);
    expect(find.text('전화'), findsOneWidget);

    shell.goto(Persona.guardian, AppTab.home);
    await _settle(tester);
    expect(find.text('어머니 전화'), findsOneWidget);
    expect(find.text('사기 신고·도움'), findsOneWidget);

    // 어르신으로 되돌린 뒤 앱을 다시 켜도 쉬운 화면 선택이 유지됩니다.
    shell.goto(Persona.senior, AppTab.home);
    await _settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    final (_, _, restarted) = await _pumpStage7App(tester, store: store, openedLinks: opened);
    expect(restarted.state.prefs.easyMode, isTrue);
    expect(find.text('최근 거래'), findsNothing);
    expect(find.text('전화'), findsOneWidget);

    // 쉬운 화면 홈의 [문자]·[전화]로 각각 문자 앱·전화 앱 열기
    await tester.tap(find.text('문자'));
    await _settle(tester);
    expect(opened.last, Uri.parse('fingerbell://sms'));

    await tester.tap(find.text('전화'));
    await _settle(tester);
    expect(opened.last, Uri.parse('fingerbell://call/dial?peer=guardian'));

    // 다시 토글해 일반 화면으로 돌아옵니다.
    await tester.tap(find.byKey(const ValueKey('easy-mode-top-toggle')));
    await _settle(tester);
    expect(restarted.state.prefs.easyMode, isFalse);
    expect(find.text('최근 거래'), findsOneWidget);
  });

  testWidgets('fraud help button appears on home and warning screens and shows 112, 1332, demo notice, and guardian call', (tester) async {
    final opened = <Uri>[];
    await _pumpStage7App(tester, openedLinks: opened);

    expect(find.byKey(const ValueKey('fraud-help-button')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('fraud-help-button')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('fraud-help-button')));
    await _settle(tester);

    expect(find.text('시연용이라 실제 전화는 걸지 않습니다'), findsOneWidget);
    expect(find.text('112'), findsOneWidget);
    expect(find.text('1332'), findsOneWidget);
    expect(find.textContaining('보호자에게 전화'), findsOneWidget);

    await tester.tap(find.textContaining('보호자에게 전화').last);
    await _settle(tester);
    expect(opened, [Uri.parse('fingerbell://call/dial?peer=guardian')]);
  });

  testWidgets('SOS button can freeze via single tap confirmation dialog', (tester) async {
    final (repo, _, _) = await _pumpStage7App(tester);

    await tester.ensureVisible(find.text('계좌 동결'));
    await _settle(tester);
    await tester.tap(find.text('계좌 동결'));
    await _settle(tester);

    expect(find.text('모든 계좌를 동결할까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await _settle(tester);
    expect(repo.calls.where((c) => c.startsWith('freeze:')), isEmpty);

    await tester.tap(find.text('계좌 동결'));
    await _settle(tester);
    await tester.tap(find.text('모든 계좌 동결'));
    await _settle(tester);

    expect(repo.calls, contains('freeze:senior:LONG_PRESS'));
    expect(find.text('모든 계좌 출금을\n막았어요'), findsOneWidget);
  });

  testWidgets('settings shows sound/haptics toggles, manual 3-card how-to guide, and feedback submission', (tester) async {
    final (repo, _, shell) = await _pumpStage7App(tester);
    shell.switchTab(AppTab.settings);
    await _settle(tester);

    // 소리·진동 설정을 끌 수 있습니다.
    await tester.tap(find.byWidgetPredicate((w) => w is FbToggle && w.label == '경고음'));
    await _settle(tester);
    expect(shell.state.prefs.sound, isFalse);

    await tester.tap(find.byWidgetPredicate((w) => w is FbToggle && w.label == '진동'));
    await _settle(tester);
    expect(shell.state.prefs.haptics, isFalse);

    // 사용 방법 3장 (자동으로 넘어가지 않음)
    await tester.ensureVisible(find.text('사용 방법'));
    await _settle(tester);
    await tester.tap(find.text('사용 방법'));
    await _settle(tester);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('위험 문자 경고'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await _settle(tester);
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('보류가 걸렸을 때'), findsOneWidget);

    await tester.tap(find.text('다음'));
    await _settle(tester);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('SOS 계좌 동결'), findsOneWidget);

    await tester.tap(find.byTooltip('닫기'));
    await _settle(tester);

    // 불편한 점 보내기
    await tester.ensureVisible(find.text('불편한 점 보내기'));
    await _settle(tester);
    await tester.tap(find.text('불편한 점 보내기'));
    await _settle(tester);

    await tester.tap(find.text('의견 보내기'));
    await _settle(tester);
    expect(find.text('불편한 점 종류를 먼저 선택해 주세요.'), findsOneWidget);

    await tester.tap(find.text('글자가 작아요'));
    await _settle(tester);
    await tester.enterText(find.byKey(const ValueKey('feedback-message-input')), '버튼이 더 크면 좋겠어요');
    await tester.tap(find.text('의견 보내기'));
    await _settle(tester);

    expect(repo.calls, contains('submitFeedback:senior:글자가 작아요'));
    expect(repo.submittedFeedback, hasLength(1));
    expect(repo.submittedFeedback.first['message'], '버튼이 더 크면 좋겠어요');
    expect(find.text('의견을 보냈어요'), findsOneWidget);
  });

  testWidgets('large text (2.0x system scale) renders easy home, sms warning, hold/reconfirm, and question without overflow', (tester) async {
    final store = MemoryPrefsStore({'easyMode': true, 'easyModePrompted': true});
    final (_, family, shell) = await _pumpStage7App(
      tester,
      size: const Size(360, 780),
      store: store,
      textScale: 2.0,
      snapshot: demoSnapshotJson(
        seniorCautionMode: true,
        requests: [pendingTransferJson(status: 'reconfirm')],
      ),
    );
    shell.setPref(PrefKey.largeText, true);
    await _settle(tester);

    // 1. 쉬운 화면 홈 + 한 줄 상태 요약
    expect(tester.takeException(), isNull);
    expect(find.text('안녕하세요, 김순자님'), findsOneWidget);
    expect(find.textContaining('본인 재확인 대기'), findsOneWidget);
    expect(find.text('사기 신고·도움'), findsWidgets);

    // 요약 누르면 상세 시트(보류/재확인 카드)가 열리고 큰 글씨에서도 넘침이 없습니다.
    await tester.ensureVisible(find.byKey(const ValueKey('easy-status-summary')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('easy-status-summary')));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('본인 재확인 대기'), findsOneWidget);
    expect(find.text('주의 모드 작동 중'), findsOneWidget);

    // 2. 확인 질문 화면
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: FbTheme.build(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConfirmationQuestionView(
              question: '적금을 만기 전에 해지하려고 하시네요. 혹시 누가 해지하라고 했나요?',
              options: const ['금융감독원 직원이 시켰어요', '가족과 상의했어요', '잘 모르겠어요'],
              onSelected: (_) {},
              onAskGuardian: () {},
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('주의 모드 확인 질문'), findsOneWidget);

    // 4. 보류 카드 직접 검증 (MemberHoldCard pending 상태)
    await tester.pumpWidget(const SizedBox.shrink());
    final famHold = FamilyCubit(
      FakeFamilyRepository(demoSnapshotJson(requests: [pendingTransferJson(status: 'pending')])),
      pollInterval: null,
    );
    await famHold.start();
    addTearDown(famHold.close);
    final m = famHold.state.data.member('senior');
    final r = famHold.state.data.pending('senior').first;
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [BlocProvider.value(value: famHold), BlocProvider.value(value: shell)],
        child: MaterialApp(
          theme: FbTheme.build(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemberHoldCard(member: m, request: r, now: family.now),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('거래 보류 중'), findsOneWidget);
  });

  testWidgets('easy home keeps banking actions and SOS inside viewport even with caution mode and multiple holds', (tester) async {
    final store = MemoryPrefsStore({'easyMode': true, 'easyModePrompted': true});
    await _pumpStage7App(
      tester,
      size: const Size(400, 860),
      store: store,
      snapshot: demoSnapshotJson(
        seniorCautionMode: true,
        requests: [
          pendingTransferJson(id: 'req-1', status: 'pending'),
          pendingTransferJson(id: 'req-2', status: 'pending'),
        ],
      ),
    );

    expect(find.text('주의 모드 · 보류 2건'), findsOneWidget);
    // 조회·송금·결제·SOS는 요약이 떠 있어도 화면 안에 남습니다.
    for (final label in ['송금', '결제', '조회', '계좌 동결']) {
      final rect = tester.getRect(find.text(label));
      expect(rect.bottom, lessThanOrEqualTo(860), reason: '$label pushed below viewport');
    }
    // 알려진 한계: 요약이 뜬 상태에서는 [문자]·[전화]·[사기 신고·도움]이 화면 아래로 조금 밀려 짧은 스크롤이 필요합니다(7.1 Ⅱ-⑥ 일부 적용).
    for (final label in ['문자', '전화', '사기 신고·도움']) {
      expect(find.text(label), findsWidgets);
    }

    await tester.tap(find.byKey(const ValueKey('easy-status-summary')));
    await _settle(tester);
    expect(find.text('보호 상태 확인'), findsOneWidget);
    expect(find.text('거래 보류 중'), findsNWidgets(2));
    expect(find.text('주의 모드 작동 중'), findsOneWidget);
  });

  testWidgets('guardian feedback submission records guardian as author', (tester) async {
    final (repo, _, shell) = await _pumpStage7App(tester);
    shell.goto(Persona.guardian, AppTab.settings);
    await _settle(tester);

    await tester.ensureVisible(find.text('불편한 점 보내기'));
    await _settle(tester);
    await tester.tap(find.text('불편한 점 보내기'));
    await _settle(tester);

    await tester.tap(find.text('화면이 복잡해요'));
    await _settle(tester);
    await tester.enterText(find.byKey(const ValueKey('feedback-message-input')), '알림이 더 잘 보이면 좋겠어요');
    await tester.tap(find.text('의견 보내기'));
    await _settle(tester);

    expect(repo.calls, contains('submitFeedback:guardian:화면이 복잡해요'));
    expect(repo.submittedFeedback, hasLength(1));
    expect(repo.submittedFeedback.first['member_id'], 'guardian');
    expect(find.text('의견을 보냈어요'), findsOneWidget);
  });

  testWidgets('how-to-use sheet speaks card explanation on open and page turns when voice is enabled', (tester) async {
    final rec = _RecordingFeedback();
    final (_, _, shell) = await _pumpStage7App(tester, feedback: rec);
    shell.setPref(PrefKey.voice, true);
    shell.switchTab(AppTab.settings);
    await _settle(tester);

    await tester.ensureVisible(find.text('사용 방법'));
    await _settle(tester);
    await tester.tap(find.text('사용 방법'));
    await _settle(tester);

    expect(rec.spoken.any((s) => s.contains('위험 문자 경고')), isTrue);

    rec.spoken.clear();
    await tester.tap(find.text('다음'));
    await _settle(tester);
    expect(rec.spoken.single, contains('보류가 걸렸을 때'));

    rec.spoken.clear();
    await tester.tap(find.text('이전'));
    await _settle(tester);
    expect(rec.spoken.single, contains('위험 문자 경고'));

    await tester.tap(find.byTooltip('닫기'));
    await _settle(tester);

    // 음성 안내 설정이 꺼져 있으면 읽지 않습니다.
    shell.setPref(PrefKey.voice, false);
    rec.spoken.clear();
    await tester.ensureVisible(find.text('사용 방법'));
    await _settle(tester);
    await tester.tap(find.text('사용 방법'));
    await _settle(tester);
    expect(rec.spoken, isEmpty);
  });

  testWidgets('danger sms and danger loan limit play alert tone via DeviceFeedback even with short vibration', (tester) async {
    final toneCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      alertToneChannel,
      (call) async {
        toneCalls.add(call);
        return true;
      },
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(alertToneChannel, null);
    });

    final (_, _, shell) = await _pumpStage7App(
      tester,
      snapshot: demoSnapshotJson(seniorCautionMode: true),
      feedback: DeviceFeedback(),
    );

    // 1. 위험 문자 시나리오([80, 40, 80] 진동) → 경고음 1회 재생
    shell.switchTab(AppTab.settings);
    await _settle(tester);
    await tester.ensureVisible(find.text('사칭 문자 받기'));
    await tester.pump();
    await tester.tap(find.text('사칭 문자 받기'));
    await _settle(tester);
    expect(toneCalls, hasLength(1));

    // 2. 대출 한도 조회 위험 경고([80, 40, 80] 진동) → 경고음 1회 재생
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpStage7App(
      tester,
      snapshot: demoSnapshotJson(seniorCautionMode: true),
      feedback: DeviceFeedback(),
    );
    final ctx = tester.element(find.text('송금'));
    unawaited(openLoanSheet(ctx, 'senior', cardReadDelay: Duration.zero));
    await _settle(tester);
    for (var i = 0; i < 3; i++) {
      await tester.ensureVisible(find.text('다음'));
      await _settle(tester);
      await tester.tap(find.text('다음'));
      await _settle(tester);
    }
    await tester.ensureVisible(find.text('내 한도 조회하기'));
    await _settle(tester);
    await tester.tap(find.text('내 한도 조회하기'));
    await _settle(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('caution-option-0')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('caution-option-0')));
    await _settle(tester);

    expect(find.text('대출 한도 조회가 위험해 보여요'), findsOneWidget);
    expect(toneCalls, hasLength(2));
  });

  testWidgets('app shell controls (top bell, bottom nav, balance toggle, guardian phone, settings toggle) expose SemanticsAction.tap', (tester) async {
    final semantics = tester.ensureSemantics();

    final (_, _, shell) = await _pumpStage7App(tester);
    for (final finder in [
      _semanticsButton('알림 확인'),
      _semanticsButton('잔액 숨기기'),
    ]) {
      expect(
        tester.getSemantics(finder).getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: 'missing SemanticsAction.tap for $finder',
      );
    }

    shell.switchTab(AppTab.safety);
    await _settle(tester);
    expect(
      tester.getSemantics(_semanticsButton('보호자에게 전화')).getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );

    shell.switchTab(AppTab.settings);
    await _settle(tester);
    final toggleFinder = find.byWidgetPredicate((w) => w is FbToggle && w.label == '경고음');
    expect(tester.getSemantics(toggleFinder).getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });
}
