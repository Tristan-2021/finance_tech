import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_transfer/feature_transfer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(FakeFamilyRepository, ShellCubit)> pumpSheet(WidgetTester tester, {String memberId = 'senior'}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeFamilyRepository();
  final family = FamilyCubit(repo, pollInterval: null);
  await family.start();
  final shell = ShellCubit();
  addTearDown(family.close);
  addTearDown(shell.close);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [BlocProvider.value(value: family), BlocProvider.value(value: shell)],
      child: MaterialApp(
        theme: FbTheme.build(),
        home: Scaffold(body: SingleChildScrollView(child: TransferSheet(memberId: memberId))),
      ),
    ),
  );
  await tester.pump();
  return (repo, shell);
}

/// 반복 애니메이션(커서 깜빡임, 전화 울림) 때문에 pumpAndSettle 대신 몇 프레임만 진행합니다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('safe transfer to a contact goes straight through', (tester) async {
    final (repo, _) = await pumpSheet(tester);
    expect(find.text('누구에게 보낼까요?'), findsOneWidget);
    await tester.tap(find.textContaining('김사랑', findRichText: true).first);
    await settle(tester);
    expect(find.text('얼마를 보낼까요?'), findsOneWidget);

    await tester.tap(find.text('+5만'));
    await tester.pump();
    await tester.tap(find.text('다음'));
    await settle(tester);
    expect(repo.calls, contains('assess:senior:50000'));
    expect(find.text('안전한 거래로 보여요'), findsOneWidget);

    await tester.tap(find.text('보내기'));
    await settle(tester);
    expect(repo.calls, contains('transfer:senior:50000'));
    expect(find.text('김사랑님께 50,000원을 보냈어요'), findsOneWidget);
  });

  testWidgets('new account shows the high risk check and waits for the guardian', (tester) async {
    final (repo, _) = await pumpSheet(tester);
    await tester.tap(find.text('새 계좌로 보내기'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, '계좌번호'), '12345678907788');
    await tester.enterText(find.widgetWithText(TextField, '받는 분 이름'), '이정민');
    await tester.tap(find.text('다음'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), '500000');
    await tester.tap(find.text('다음'));
    await settle(tester);
    expect(find.text('사기 위험이 높은 거래예요'), findsOneWidget);
    expect(find.text('처음 보내는 계좌예요'), findsOneWidget);

    repo.snapshotJson = demoSnapshotJson(requests: [pendingTransferJson()]);
    await tester.tap(find.text('보호자에게 확인 요청'));
    await settle(tester);
    expect(find.text('거래를 30분 동안 보류했어요'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await settle(tester);
    expect(repo.calls, contains('cancel:req-1:senior'));
    expect(find.text('송금이 취소됐어요'), findsOneWidget);
  });

  testWidgets('reconfirm waiting in transfer sheet executes, stops, or reports failure', (tester) async {
    final (repo, shell) = await pumpSheet(tester);
    final messages = <String>[];
    final sub = shell.feedback.listen((f) => messages.add(f.message));
    addTearDown(sub.cancel);

    await tester.tap(find.text('새 계좌로 보내기'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, '계좌번호'), '12345678907788');
    await tester.enterText(find.widgetWithText(TextField, '받는 분 이름'), '이정민');
    await tester.tap(find.text('다음'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '500000');
    await tester.tap(find.text('다음'));
    await settle(tester);

    repo.snapshotJson = demoSnapshotJson(requests: [pendingTransferJson(status: 'reconfirm')]);
    await tester.tap(find.text('보호자에게 확인 요청'));
    await settle(tester);
    expect(find.text('본인 재확인 대기'), findsOneWidget);

    repo.failDecisionReason = '잔액이 부족해 보내지 못했어요.';
    await tester.tap(find.text('그래도 진행'));
    await settle(tester);
    expect(repo.calls, contains('reconfirm:req-1:senior:true'));
    expect(find.text('처리하지 못했어요'), findsOneWidget);
    expect(find.textContaining('잔액이 부족해 보내지 못했어요.'), findsOneWidget);
    expect(messages.last, '처리하지 못했어요 · 잔액이 부족해 보내지 못했어요.');
  });

  testWidgets('caution level shows warning and easy explanation and proceeds on confirmation', (tester) async {
    final (repo, _) = await pumpSheet(tester);
    await tester.tap(find.text('새 계좌로 보내기'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, '계좌번호'), '12345678907788');
    await tester.enterText(find.widgetWithText(TextField, '받는 분 이름'), '이정민');
    await tester.tap(find.text('다음'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), '50000');
    await tester.tap(find.text('다음'));
    await settle(tester);
    expect(find.text('한 번 더 확인이 필요해요'), findsOneWidget);
    expect(find.text('처음 보내는 계좌예요'), findsOneWidget);

    await tester.tap(find.text('확인했어요, 보내기'));
    await settle(tester);
    expect(repo.calls, contains('transfer:senior:50000:confirmed'));
    expect(find.text('이정민님께 50,000원을 보냈어요'), findsOneWidget);
  });

  testWidgets('guardian sends from their own account without waiting for approval', (tester) async {
    final (repo, _) = await pumpSheet(tester, memberId: 'guardian');
    expect(find.text('핑거벨 주거래 통장 · 잔액 3,480,000원'), findsOneWidget);
    expect(find.textContaining('이민준', findRichText: true), findsOneWidget);

    await tester.tap(find.text('새 계좌로 보내기'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, '계좌번호'), '12345678907788');
    await tester.enterText(find.widgetWithText(TextField, '받는 분 이름'), '이정민');
    await tester.tap(find.text('다음'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '500000');
    await tester.tap(find.text('다음'));
    await settle(tester);

    // 위험도는 똑같이 보여 주고, 보호자 요청 대신 본인이 확인하고 보냅니다
    expect(find.text('사기 위험이 높은 거래예요'), findsOneWidget);
    expect(find.text('보호자에게 확인 요청'), findsNothing);
    await tester.tap(find.text('확인했어요, 보내기'));
    await settle(tester);
    expect(repo.calls, contains('transfer:guardian:500000:confirmed'));
    expect(find.text('이정민님께 500,000원을 보냈어요'), findsOneWidget);
  });

  testWidgets('rejects an empty account number', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.text('새 계좌로 보내기'));
    await settle(tester);
    await tester.tap(find.text('다음'));
    await tester.pump();
    expect(find.text('계좌번호는 숫자 10~14자리로 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('large transfer in caution mode asks confirmation question with no preselected option', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeFamilyRepository(demoSnapshotJson(seniorCautionMode: true));
    final family = FamilyCubit(repo, pollInterval: null);
    await family.start();
    final shell = ShellCubit();
    addTearDown(family.close);
    addTearDown(shell.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [BlocProvider.value(value: family), BlocProvider.value(value: shell)],
        child: MaterialApp(
          theme: FbTheme.build(),
          home: const Scaffold(body: SingleChildScrollView(child: TransferSheet(memberId: 'senior'))),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.textContaining('김사랑', findRichText: true).first);
    await settle(tester);
    await tester.enterText(find.byType(TextField), '200000');
    await tester.tap(find.text('다음'));
    await settle(tester);

    await tester.tap(find.text('보내기'));
    await settle(tester);

    expect(find.text('주의 모드 확인 질문'), findsOneWidget);
    expect(find.textContaining('평소보다 큰 금액을 보내려고 하시네요'), findsOneWidget);
    // 어느 선택지도 미리 선택되지 않았는지 확인합니다.
    for (var i = 0; i < 4; i++) {
      final optFinder = find.byKey(ValueKey('caution-option-$i'));
      expect(optFinder, findsOneWidget);
      final sem = tester.widget<Semantics>(optFinder);
      expect(sem.properties.selected, isFalse);
    }

    await tester.ensureVisible(find.byKey(const ValueKey('caution-option-0')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('caution-option-0')));
    await settle(tester);
    expect(find.text('거래를 30분 동안 보류했어요'), findsOneWidget);
  });

  testWidgets('caution verdict after question in caution mode shows new explanation and requires fresh confirmation', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final snap = demoSnapshotJson(seniorCautionMode: true);
    final members = snap['members'] as List<dynamic>;
    (members[0] as Map<String, dynamic>)['avg_transfer'] = 50000;

    final repo = FakeFamilyRepository(snap);
    final family = FamilyCubit(repo, pollInterval: null);
    await family.start();
    final shell = ShellCubit();
    addTearDown(family.close);
    addTearDown(shell.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [BlocProvider.value(value: family), BlocProvider.value(value: shell)],
        child: MaterialApp(
          theme: FbTheme.build(),
          home: const Scaffold(body: SingleChildScrollView(child: TransferSheet(memberId: 'senior'))),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('새 계좌로 보내기'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, '계좌번호'), '12345678907788');
    await tester.enterText(find.widgetWithText(TextField, '받는 분 이름'), '이정민');
    await tester.tap(find.text('다음'));
    await settle(tester);

    await tester.enterText(find.byType(TextField), '80000');
    await tester.tap(find.text('다음'));
    await settle(tester);

    // 1차 FDS 주의 경고 확인 후 확인 질문으로 이동
    expect(find.text('한 번 더 확인이 필요해요'), findsOneWidget);
    expect(find.text('처음 보내는 계좌예요'), findsOneWidget);
    await tester.ensureVisible(find.text('확인했어요, 보내기'));
    await settle(tester);
    await tester.tap(find.text('확인했어요, 보내기'));
    await settle(tester);

    expect(find.text('주의 모드 확인 질문'), findsOneWidget);

    // 답 제출 시 이전 confirmed 값을 재사용하지 않고 새 종합 판정 '주의' 설명을 먼저 보여 주어야 합니다
    await tester.ensureVisible(find.byKey(const ValueKey('caution-option-1')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('caution-option-1')));
    await settle(tester);

    expect(repo.calls, contains('transfer:senior:80000:caution'));
    expect(repo.calls, isNot(contains('transfer:senior:80000:done')));
    expect(find.text('한 번 더 확인이 필요해요'), findsOneWidget);
    expect(find.text('주의 모드 중 거래를 진행하고 있어요. 다시 한 번 확인해 주세요.'), findsOneWidget);
    expect(find.text('이정민님께 80,000원을 보냈어요'), findsNothing);

    // 새 설명을 본 뒤 본인이 확인해야 송금이 완료됩니다
    await tester.ensureVisible(find.text('확인했어요, 보내기'));
    await settle(tester);
    await tester.tap(find.text('확인했어요, 보내기'));
    await settle(tester);

    expect(repo.calls, contains('transfer:senior:80000:done'));
    expect(find.text('이정민님께 80,000원을 보냈어요'), findsOneWidget);
  });
}
