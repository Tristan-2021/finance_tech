import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fingerbell_app/app.dart';
import 'package:fingerbell_app/shell/feedback_service.dart';
import 'package:fingerbell_app/views/banking_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(FakeFamilyRepository, FamilyCubit, ShellCubit)> pumpBankingApp(
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
  return (repo, family, shell);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('senior home keeps existing buttons, omits loan, and opens accounts sheet from 조회', (tester) async {
    await pumpBankingApp(tester);
    expect(find.text('송금'), findsOneWidget);
    expect(find.text('결제'), findsOneWidget);
    expect(find.text('조회'), findsOneWidget);
    // 대출은 어르신 큰 버튼 홈에 내놓지 않습니다 (기획서 7.1 Ⅱ-⑥).
    expect(find.textContaining('대출'), findsNothing);

    await tester.tap(find.text('조회'));
    await settle(tester);

    expect(find.text('계좌 조회'), findsOneWidget);
    expect(find.text('노후 생활비 통장'), findsOneWidget);
    expect(find.text('만기 전 해지'), findsOneWidget);
    expect(find.text('대출 한도 조회·신청'), findsOneWidget);
  });

  testWidgets('savings early cancellation flow in caution mode goes through disclosure, dialog, comprehension, question, and 30-min hold', (tester) async {
    final (repo, family, shell) = await pumpBankingApp(
      tester,
      snapshot: demoSnapshotJson(seniorCautionMode: true),
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [BlocProvider.value(value: family), BlocProvider.value(value: shell)],
        child: MaterialApp(
          theme: FbTheme.build(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SavingsCancelSheet(
                memberId: 'senior',
                accountId: 'a2',
                cardReadDelay: Duration.zero,
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    // 1 / 4: 이자율 먼저 + 중요사항 표시 + 보호자에게 물어보기
    expect(find.text('꼭 알아야 할 내용'), findsOneWidget);
    expect(find.text('금융소비자보호법 제19조의 중요한 사항입니다'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('약정 이자율'), findsOneWidget);
    expect(find.text('연 4.2%'), findsOneWidget);
    expect(find.text('보호자에게 물어보기'), findsOneWidget);

    await tester.ensureVisible(find.text('다음'));
    await settle(tester);
    await tester.tap(find.text('다음'));
    await settle(tester);

    // 2 / 4: 줄어드는 이자 강조
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('줄어드는 이자 883,200원'), findsOneWidget);

    await tester.ensureVisible(find.text('다음'));
    await settle(tester);
    await tester.tap(find.text('다음'));
    await settle(tester);

    // 3 / 4: 실수령액 확인 → 별도 확인창 한 번
    expect(find.text('3 / 4'), findsOneWidget);
    expect(find.text('18,676,000원'), findsOneWidget);
    await tester.ensureVisible(find.text('다음'));
    await settle(tester);
    await tester.tap(find.text('다음'));
    await settle(tester);

    expect(find.text('줄어드는 이자를 확인하셨나요?'), findsOneWidget);
    await tester.tap(find.text('확인했어요'));
    await settle(tester);

    // 4 / 4: 이해 확인 (어느 답도 미리 선택되지 않음 + 분쟁 고지)
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('이해하지 못한 채 확인하면 나중에 분쟁에서 불리할 수 있어요'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      final sem = tester.widget<Semantics>(find.byKey(ValueKey('comprehension-option-$i')));
      expect(sem.properties.selected, isFalse);
    }

    await tester.ensureVisible(find.byKey(const ValueKey('comprehension-option-1')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('comprehension-option-1')));
    await settle(tester);
    await tester.ensureVisible(find.text('해지 신청하기'));
    await settle(tester);
    await tester.tap(find.text('해지 신청하기'));
    await settle(tester);

    // 주의 모드 확인 질문 화면: 미리 선택된 답 없음
    expect(find.text('주의 모드 확인 질문'), findsOneWidget);
    expect(find.textContaining('누가 해지하라고 했나요?'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      final sem = tester.widget<Semantics>(find.byKey(ValueKey('caution-option-$i')));
      expect(sem.properties.selected, isFalse);
    }

    await tester.ensureVisible(find.byKey(const ValueKey('caution-option-0')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('caution-option-0')));
    await settle(tester);

    expect(repo.calls, contains('cancelSavings:senior:a2:pending'));
    expect(find.text('거래를 30분 동안 보류했어요'), findsOneWidget);
  });

  testWidgets('loan flow shows 5-step disclosure, glossary, and updates monthly payment when amount is picked', (tester) async {
    final (_, family, shell) = await pumpBankingApp(tester);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [BlocProvider.value(value: family), BlocProvider.value(value: shell)],
        child: MaterialApp(
          theme: FbTheme.build(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: LoanSheet(memberId: 'senior', cardReadDelay: Duration.zero),
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    // 1 / 5: 전체 5단계 표시 + 금리·변동여부·중도상환수수료
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.textContaining('전체 5단계'), findsOneWidget);
    expect(find.text('꼭 알아야 할 내용'), findsOneWidget);
    expect(find.text('금융소비자보호법 제19조의 중요한 사항입니다'), findsOneWidget);
    expect(find.text('연 5.4%'), findsOneWidget);

    // 어려운 말 풀이 확인
    await tester.ensureVisible(find.text('변동금리 뜻 보기'));
    await settle(tester);
    await tester.tap(find.text('변동금리 뜻 보기'));
    await settle(tester);
    expect(find.text('변동금리'), findsOneWidget);
    await tester.tap(find.text('이해했어요'));
    await settle(tester);

    await tester.ensureVisible(find.text('다음'));
    await settle(tester);
    await tester.tap(find.text('다음'));
    await settle(tester);

    // 2 / 5: 상환 방식
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('원리금균등분할상환'), findsOneWidget);
    await tester.ensureVisible(find.text('다음'));
    await settle(tester);
    await tester.tap(find.text('다음'));
    await settle(tester);

    // 3 / 5: 연체 불이익과 청약철회권
    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.textContaining('연체 불이익'), findsWidgets);
    expect(find.textContaining('14일 안에 취소 가능'), findsOneWidget);
    await tester.ensureVisible(find.text('다음'));
    await settle(tester);
    await tester.tap(find.text('다음'));
    await settle(tester);

    // 4 / 5: 금액 선택 시 월 납입액 자동 갱신
    expect(find.text('4 / 5'), findsOneWidget);
    expect(find.text('220,254원'), findsOneWidget); // 500만원 기준 월 납입액

    await tester.ensureVisible(find.text('1000만원'));
    await settle(tester);
    await tester.tap(find.text('1000만원'));
    await settle(tester);
    expect(find.text('440,507원'), findsOneWidget); // 1,000만원 기준 월 납입액
  });
}
