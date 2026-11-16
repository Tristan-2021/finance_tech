import 'dart:async';

import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_guardian/feature_guardian.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<(FakeFamilyRepository, FamilyCubit, ShellCubit)> _pumpGuardianWidget(
  WidgetTester tester, {
  required Map<String, dynamic> snapshot,
  required Widget Function(FamilySnapshot data) builder,
}) async {
  tester.view.physicalSize = const Size(420, 920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = FakeFamilyRepository(snapshot);
  final family = FamilyCubit(repo, pollInterval: null);
  await family.start();
  final shell = ShellCubit()..goto(Persona.guardian, AppTab.home);
  addTearDown(family.close);
  addTearDown(shell.close);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [BlocProvider.value(value: family), BlocProvider.value(value: shell)],
      child: MaterialApp(
        theme: FbTheme.build(),
        home: Scaffold(
          body: BlocBuilder<FamilyCubit, FamilyState>(
            builder: (context, state) {
              if (!state.isReady) return const SizedBox.shrink();
              return SingleChildScrollView(child: builder(state.data));
            },
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return (repo, family, shell);
}

void main() {
  testWidgets('incident summary displays items chronologically and opens from hold card', (tester) async {
    final now = DateTime.utc(2026, 10, 26, 14, 0);
    // 서버 JSON이 시간순과 섞여 들어와도 화면에서는 시간순으로 정렬해 보여 줍니다.
    final shuffledItems = [
      {
        'id': 'ev-3',
        'kind': 'hold',
        'summary': '노후 생활비 통장 만기 전 해지 18,676,000원 보류',
        'at': now.subtract(const Duration(minutes: 2)).toIso8601String(),
      },
      {
        'id': 'ev-1',
        'kind': 'sms',
        'summary': '위험 문자 수신 (금융감독원) · 기관 사칭 의심',
        'at': now.subtract(const Duration(minutes: 10)).toIso8601String(),
      },
      {
        'id': 'ev-2',
        'kind': 'call',
        'summary': '위험 통화 감지 (금융감독원) · 적금 해지 요구',
        'at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
      },
    ];
    final activeInc = incidentJson(id: 'inc-open', now: now, items: shuffledItems);
    final holdReq = pendingTransferJson(id: 'req-hold-1', incidentId: 'inc-open', now: now);

    await _pumpGuardianWidget(
      tester,
      snapshot: demoSnapshotJson(
        now: now,
        seniorCautionMode: true,
        seniorActiveIncident: activeInc,
        requests: [holdReq],
      ),
      builder: (data) => GuardianHomeView(data: data),
    );

    expect(find.text('위험 근거 요약'), findsOneWidget);
    final y1 = tester.getTopLeft(find.text('위험 문자 수신 (금융감독원) · 기관 사칭 의심').first).dy;
    final y2 = tester.getTopLeft(find.text('위험 통화 감지 (금융감독원) · 적금 해지 요구').first).dy;
    final y3 = tester.getTopLeft(find.text('노후 생활비 통장 만기 전 해지 18,676,000원 보류').first).dy;
    expect(y1, lessThan(y2));
    expect(y2, lessThan(y3));

    // 보류 카드에서 한 번에 위험 근거 요약 시트를 열 수 있습니다.
    final openBtn = find.text('위험 근거 요약 보기');
    await tester.ensureVisible(openBtn);
    await tester.pumpAndSettle();
    await tester.tap(openBtn);
    await _settle(tester);

    expect(find.text('문자'), findsWidgets);
    expect(find.text('통화 징후'), findsWidgets);
    expect(find.text('보류'), findsWidgets);

    final sheetY1 = tester.getTopLeft(find.text('위험 문자 수신 (금융감독원) · 기관 사칭 의심').last).dy;
    final sheetY2 = tester.getTopLeft(find.text('위험 통화 감지 (금융감독원) · 적금 해지 요구').last).dy;
    final sheetY3 = tester.getTopLeft(find.text('노후 생활비 통장 만기 전 해지 18,676,000원 보류').last).dy;
    expect(sheetY1, lessThan(sheetY2));
    expect(sheetY2, lessThan(sheetY3));
  });

  testWidgets('risk history list opens past incident chronological summary on tap', (tester) async {
    final now = DateTime.utc(2026, 10, 26, 14, 0);
    final closedInc = incidentJson(id: 'inc-closed-1', status: 'closed', now: now);

    await _pumpGuardianWidget(
      tester,
      snapshot: demoSnapshotJson(now: now, incidents: [closedInc]),
      builder: (data) => GuardianAlertsView(data: data),
    );

    await tester.tap(find.text('위험 기록'));
    await _settle(tester);

    expect(find.textContaining('어머니 김순자'), findsOneWidget);
    expect(find.text('보호자 해제'), findsOneWidget);

    await tester.tap(find.textContaining('어머니 김순자'));
    await _settle(tester);

    expect(find.text('위험 근거 요약'), findsOneWidget);
    expect(find.textContaining('종료됨 (보호자 해제)'), findsOneWidget);
    expect(find.text('주의 모드 해제 (보호자 해제)'), findsOneWidget);
    expect(find.text('보호자 조치'), findsOneWidget);
  });

  testWidgets('pairing flow shows 5 steps, supports direct code entry, and connects only when consent button is tapped', (tester) async {
    final (repo, _, _) = await _pumpGuardianWidget(
      tester,
      snapshot: demoSnapshotJson(),
      builder: (data) => Builder(
        builder: (ctx) => FbButton(
          '연결 시작',
          onPressed: () => openPairingSheet(ctx),
        ),
      ),
    );

    await tester.tap(find.text('연결 시작'));
    await _settle(tester);

    // 1 / 5: 전체 단계 안내
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.textContaining('전체 5단계'), findsOneWidget);

    await tester.ensureVisible(find.text('보호자 QR 코드 만들기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('보호자 QR 코드 만들기'));
    await _settle(tester);

    // 2 / 5: 보호자 QR + 코드 발급
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('482910'), findsOneWidget);
    expect(repo.calls, contains('issuePairingCode:guardian:senior:482910'));

    await tester.ensureVisible(find.text('어르신 기기에서 입력하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('어르신 기기에서 입력하기'));
    await _settle(tester);

    // 3 / 5: 직접 코드 입력
    expect(find.text('3 / 5'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('pairing-code-input')), '482910');
    await tester.ensureVisible(find.text('다음'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음'));
    await _settle(tester);

    // 4 / 5: 동의 화면 - [동의]를 누르기 전에는 connectPairing이 호출되지 않습니다.
    expect(find.text('4 / 5'), findsOneWidget);
    expect(find.text('위험 알림'), findsOneWidget);
    expect(find.text('위험 근거 요약'), findsOneWidget);
    expect(find.text('보류 상태'), findsOneWidget);
    expect(repo.calls.where((c) => c.startsWith('connectPairing')), isEmpty);

    await tester.ensureVisible(find.text('동의'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('동의'));
    await _settle(tester);

    expect(repo.calls, contains('connectPairing:senior:482910:true'));
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('보호자와 연결했어요'), findsOneWidget);
  });

  testWidgets('pairing step 3 also supports QR scanner callback', (tester) async {
    final (repo, _, _) = await _pumpGuardianWidget(
      tester,
      snapshot: demoSnapshotJson(),
      builder: (data) => Builder(
        builder: (ctx) => FbButton(
          '연결 시작',
          onPressed: () => openPairingSheet(
            ctx,
            qrScannerBuilder: (_, onDetected) => FbButton(
              '가짜 QR 인식',
              onPressed: () => onDetected('482910'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('연결 시작'));
    await _settle(tester);
    await tester.ensureVisible(find.text('보호자 QR 코드 만들기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('보호자 QR 코드 만들기'));
    await _settle(tester);
    await tester.ensureVisible(find.text('어르신 기기에서 입력하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('어르신 기기에서 입력하기'));
    await _settle(tester);

    await tester.ensureVisible(find.text('카메라로 QR 찍기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('카메라로 QR 찍기'));
    await _settle(tester);
    await tester.ensureVisible(find.text('가짜 QR 인식'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('가짜 QR 인식'));
    await _settle(tester);

    expect(find.text('4 / 5'), findsOneWidget);
    await tester.ensureVisible(find.text('동의'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('동의'));
    await _settle(tester);

    expect(repo.calls, contains('connectPairing:senior:482910:true'));
    expect(find.text('5 / 5'), findsOneWidget);
  });

  testWidgets('hold card opens originating incident after caution ends and hides button outside caution mode', (tester) async {
    final now = DateTime.utc(2026, 10, 26, 14, 0);
    final oldClosedInc = incidentJson(
      id: 'inc-old',
      status: 'closed',
      now: now.subtract(const Duration(hours: 2)),
      items: [
        {
          'id': 'ev-old-1',
          'kind': 'hold',
          'summary': '이전 사건에서 보류된 송금 근거',
          'at': now.subtract(const Duration(hours: 2)).toIso8601String(),
        },
      ],
    );
    final newOpenInc = incidentJson(
      id: 'inc-new',
      status: 'open',
      now: now,
      items: [
        {
          'id': 'ev-new-1',
          'kind': 'sms',
          'summary': '새 사건에서 감지된 문자 근거',
          'at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
        },
      ],
    );
    final holdFromOldInc = pendingTransferJson(id: 'req-from-old', incidentId: 'inc-old', now: now);
    final holdOutsideCaution = pendingTransferJson(id: 'req-outside', now: now);

    await _pumpGuardianWidget(
      tester,
      snapshot: demoSnapshotJson(
        now: now,
        seniorCautionMode: true,
        seniorActiveIncident: newOpenInc,
        incidents: [oldClosedInc],
        requests: [holdFromOldInc, holdOutsideCaution],
      ),
      builder: (data) => Column(
        children: [
          RequestCard(
            key: const ValueKey('card-outside'),
            request: data.request('req-outside')!,
            data: data,
            now: () => now,
          ),
          RequestCard(
            key: const ValueKey('card-old'),
            request: data.request('req-from-old')!,
            data: data,
            now: () => now,
          ),
        ],
      ),
    );

    // 주의 모드 밖에서 만들어진 보류 카드에는 요약 버튼이 없습니다.
    expect(
      find.descendant(of: find.byKey(const ValueKey('card-outside')), matching: find.text('위험 근거 요약 보기')),
      findsNothing,
    );

    // 주의 모드 중 만들어진 보류 카드는 사건이 종료되고 새 사건이 열렸어도 원래 사건을 엽니다.
    final oldCardBtn = find.descendant(
      of: find.byKey(const ValueKey('card-old')),
      matching: find.text('위험 근거 요약 보기'),
    );
    expect(oldCardBtn, findsOneWidget);
    await tester.ensureVisible(oldCardBtn);
    await tester.pumpAndSettle();
    await tester.tap(oldCardBtn);
    await _settle(tester);

    expect(find.text('이전 사건에서 보류된 송금 근거'), findsOneWidget);
    expect(find.text('새 사건에서 감지된 문자 근거'), findsNothing);
  });

  testWidgets('open incident summary sheet refreshes live when new items are added', (tester) async {
    final now = DateTime.utc(2026, 10, 26, 14, 0);
    final initialItems = [
      {
        'id': 'ev-1',
        'kind': 'sms',
        'summary': '위험 문자 수신 (금융감독원) · 기관 사칭 의심',
        'at': now.subtract(const Duration(minutes: 10)).toIso8601String(),
      },
    ];
    final activeInc = incidentJson(id: 'inc-live', now: now, items: initialItems);
    final holdReq = pendingTransferJson(id: 'req-live', incidentId: 'inc-live', now: now);

    final (repo, _, _) = await _pumpGuardianWidget(
      tester,
      snapshot: demoSnapshotJson(
        now: now,
        seniorCautionMode: true,
        seniorActiveIncident: activeInc,
        requests: [holdReq],
      ),
      builder: (data) => RequestCard(
        request: data.request('req-live')!,
        data: data,
        now: () => now,
      ),
    );

    await tester.ensureVisible(find.text('위험 근거 요약 보기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('위험 근거 요약 보기'));
    await _settle(tester);

    expect(find.text('위험 문자 수신 (금융감독원) · 기관 사칭 의심'), findsOneWidget);
    expect(find.text('위험 통화 감지 · 적금 해지 요구'), findsNothing);
    expect(find.text('이정민님께 송금 보류 만료 · 본인 재확인 대기'), findsNothing);

    // 시트가 열린 상태에서 통화 징후·금융 행동·재확인 기록이 새로 쌓이면 즉시 반영됩니다.
    final updatedInc = incidentJson(
      id: 'inc-live',
      now: now,
      items: [
        ...initialItems,
        {
          'id': 'ev-2',
          'kind': 'call',
          'summary': '위험 통화 감지 · 적금 해지 요구',
          'at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
        },
        {
          'id': 'ev-3',
          'kind': 'action',
          'summary': '이정민님께 500,000원 송금 시도',
          'at': now.subtract(const Duration(minutes: 2)).toIso8601String(),
        },
        {
          'id': 'ev-4',
          'kind': 'hold',
          'summary': '이정민님께 송금 보류 만료 · 본인 재확인 대기',
          'at': now.subtract(const Duration(minutes: 1)).toIso8601String(),
        },
      ],
    );
    repo.snapshotJson = demoSnapshotJson(
      now: now,
      seniorCautionMode: true,
      seniorActiveIncident: updatedInc,
      requests: [holdReq],
    );
    repo.emitEvent(const FamilyEvent(type: 'reconfirm', memberId: 'senior', requestId: 'req-live'));
    await _settle(tester);

    expect(find.text('위험 통화 감지 · 적금 해지 요구'), findsOneWidget);
    expect(find.text('이정민님께 500,000원 송금 시도'), findsOneWidget);
    expect(find.text('이정민님께 송금 보류 만료 · 본인 재확인 대기'), findsOneWidget);
  });

  testWidgets('pairing sheet discards stale pairing code response when member changes mid-flight', (tester) async {
    tester.view.physicalSize = const Size(420, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _DelayedPairingRepo();
    final family = FamilyCubit(repo, pollInterval: null);
    await family.start();
    final shell = ShellCubit()..goto(Persona.guardian, AppTab.home);
    addTearDown(family.close);
    addTearDown(shell.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [BlocProvider.value(value: family), BlocProvider.value(value: shell)],
        child: MaterialApp(
          theme: FbTheme.build(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => FbButton(
                '연결 시작',
                onPressed: () => openPairingSheet(ctx),
              ),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('연결 시작'));
    await _settle(tester);

    // 1. 어머니(senior)로 코드 발급 요청 시작 (응답 대기 중)
    await tester.ensureVisible(find.text('보호자 QR 코드 만들기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('보호자 QR 코드 만들기'));
    await _settle(tester);
    expect(repo.pendingIssues.containsKey('senior'), isTrue);

    // 2. 응답이 오기 전에 뒤로 가서 아들(child)로 변경한 뒤 다시 발급 요청
    await tester.tap(find.byTooltip('뒤로'));
    await _settle(tester);
    await tester.tap(find.text('아들 이민준'));
    await _settle(tester);
    await tester.ensureVisible(find.text('보호자 QR 코드 만들기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('보호자 QR 코드 만들기'));
    await _settle(tester);
    expect(repo.pendingIssues.containsKey('child'), isTrue);

    // 3. 먼저 보냈던 senior 응답이 늦게 도착해도 버려져야 합니다.
    repo.pendingIssues['senior']!.complete(
      PairingCodeResult(
        code: '111111',
        qrValue: '111111',
        guardianId: 'guardian',
        guardianName: '김사랑',
        memberId: 'senior',
        memberName: '김순자',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      ),
    );
    await _settle(tester);
    expect(find.text('111111'), findsNothing);
    expect(find.textContaining('아들 이민준 기기에서'), findsOneWidget);

    // 4. 현재 선택한 child 응답이 오면 정상 표시됩니다.
    repo.pendingIssues['child']!.complete(
      PairingCodeResult(
        code: '222222',
        qrValue: '222222',
        guardianId: 'guardian',
        guardianName: '김사랑',
        memberId: 'child',
        memberName: '이민준',
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      ),
    );
    await _settle(tester);
    expect(find.text('222222'), findsOneWidget);
    expect(find.text('111111'), findsNothing);
  });
}

class _DelayedPairingRepo extends FakeFamilyRepository {
  final Map<String, Completer<PairingCodeResult>> pendingIssues = {};

  @override
  Future<PairingCodeResult> issuePairingCode(String guardianId, String memberId) {
    calls.add('issuePairingCode:$guardianId:$memberId');
    final completer = Completer<PairingCodeResult>();
    pendingIssues[memberId] = completer;
    return completer.future;
  }
}
