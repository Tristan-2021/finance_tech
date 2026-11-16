import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:fingerbell_app/app.dart';
import 'package:fingerbell_app/shell/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(FakeFamilyRepository, ShellCubit)> _pumpApp(
  WidgetTester tester, {
  Map<String, dynamic>? snapshot,
}) async {
  tester.view.physicalSize = const Size(420, 920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = FakeFamilyRepository(snapshot);
  final family = FamilyCubit(repo, pollInterval: null);
  await family.start();
  final shell = ShellCubit();
  addTearDown(family.close);
  addTearDown(shell.close);

  await tester.pumpWidget(
    FingerBellApp(
      family: family,
      shell: shell,
      feedback: const SilentFeedback(),
      serverAddress: 'http://127.0.0.1:8765',
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return (repo, shell);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('guardian flow: evidence summary, hold extend/release, call family, caution release, and risk history', (tester) async {
    final now = DateTime.utc(2026, 10, 26, 14, 0);
    final activeInc = incidentJson(id: 'inc-live-1', status: 'open', now: now);
    final holdReq = pendingTransferJson(id: 'req-live-1', incidentId: 'inc-live-1', now: now);

    final (repo, shell) = await _pumpApp(
      tester,
      snapshot: demoSnapshotJson(
        now: now,
        seniorCautionMode: true,
        seniorActiveIncident: activeInc,
        requests: [holdReq],
      ),
    );

    shell.goto(Persona.guardian, AppTab.home);
    await _settle(tester);

    // 1. 진행 중인 사건 근거 요약 확인 (보류 카드에서 한 번에 열기)
    expect(find.text('위험 근거 요약'), findsOneWidget);
    await tester.ensureVisible(find.text('위험 근거 요약 보기'));
    await tester.pump();
    await tester.tap(find.text('위험 근거 요약 보기'));
    await _settle(tester);
    expect(find.text('문자'), findsWidgets);
    await tester.tap(find.byTooltip('닫기').last);
    await _settle(tester);

    // 2. 보류 연장 후 해제
    await tester.ensureVisible(find.text('연장'));
    await tester.pump();
    await tester.tap(find.text('연장'));
    await _settle(tester);
    expect(repo.calls, contains('extend:req-live-1'));

    await tester.ensureVisible(find.text('해제'));
    await tester.pump();
    await tester.tap(find.text('해제'));
    await _settle(tester);
    expect(repo.calls, contains('decide:req-live-1:approve'));

    // 3. 가족에게 전화하기
    await tester.ensureVisible(find.text('어머니에게 전화하기'));
    await tester.pump();
    await tester.tap(find.text('어머니에게 전화하기'));
    await _settle(tester);
    expect(repo.calls, contains('startCall:guardian:senior:앱 안 통화'));
    await tester.tap(find.text('통화 끊기'));
    await _settle(tester);
    await tester.ensureVisible(find.text('닫기').last);
    await tester.pump();
    await tester.tap(find.text('닫기').last);
    await _settle(tester);

    // 4. 주의 모드 해제
    await tester.ensureVisible(find.text('주의 모드 해제'));
    await tester.pump();
    await tester.tap(find.text('주의 모드 해제'));
    await _settle(tester);
    expect(repo.calls, contains('releaseCautionMode:senior'));

    // 5. 지난 위험 기록 보기 → 상세
    await tester.ensureVisible(find.text('전체보기').last);
    await tester.pump();
    await tester.tap(find.text('전체보기').last);
    await _settle(tester);
    expect(find.text('가족 알림'), findsOneWidget);
    expect(find.textContaining('어머니 김순자'), findsOneWidget);

    await tester.tap(find.textContaining('어머니 김순자'));
    await _settle(tester);
    expect(find.textContaining('종료됨 (보호자 해제)'), findsOneWidget);
  });

  testWidgets('settings allows re-running QR/code pairing and consent flow', (tester) async {
    final (repo, shell) = await _pumpApp(tester);
    shell.switchTab(AppTab.settings);
    await _settle(tester);

    expect(find.text('보호자 연결 다시 해 보기'), findsOneWidget);
    await tester.ensureVisible(find.text('보호자 연결 다시 해 보기'));
    await tester.pump();
    await tester.tap(find.text('보호자 연결 다시 해 보기'));
    await _settle(tester);

    expect(find.text('1 / 5'), findsOneWidget);
    await tester.ensureVisible(find.text('보호자 QR 코드 만들기'));
    await tester.pump();
    await tester.tap(find.text('보호자 QR 코드 만들기'));
    await _settle(tester);
    expect(find.text('2 / 5'), findsOneWidget);

    await tester.ensureVisible(find.text('어르신 기기에서 입력하기'));
    await tester.pump();
    await tester.tap(find.text('어르신 기기에서 입력하기'));
    await _settle(tester);

    expect(find.text('3 / 5'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pairing-code-input')), '482910');
    await tester.ensureVisible(find.text('다음'));
    await tester.pump();
    await tester.tap(find.text('다음'));
    await _settle(tester);

    expect(find.text('4 / 5'), findsOneWidget);
    await tester.ensureVisible(find.text('동의'));
    await tester.pump();
    await tester.tap(find.text('동의'));
    await _settle(tester);

    expect(repo.calls, contains('connectPairing:senior:482910:true'));
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('보호자와 연결했어요'), findsOneWidget);
  });

  testWidgets('guardian receives toast feedback for reconfirm realtime event', (tester) async {
    final (repo, shell) = await _pumpApp(tester);
    final messages = <String>[];
    final sub = shell.feedback.listen((f) => messages.add(f.message));
    addTearDown(sub.cancel);

    shell.goto(Persona.guardian, AppTab.home);
    await _settle(tester);

    repo.emitEvent(
      const FamilyEvent(
        type: 'reconfirm',
        message: '이정민님께 송금 보류 시간이 지나 본인 재확인을 기다리고 있어요',
        memberId: 'senior',
        requestId: 'req-1',
      ),
    );
    await _settle(tester);

    expect(messages, contains('이정민님께 송금 보류 시간이 지나 본인 재확인을 기다리고 있어요'));
  });
}
