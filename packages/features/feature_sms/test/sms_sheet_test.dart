import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_sms/feature_sms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Future<FakeFamilyRepository> pumpSmsSheet(
  WidgetTester tester, {
  List<Map<String, dynamic>>? smsMessages,
  String? initialSenderPhone,
  ValueChanged<String>? onTapPhone,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeFamilyRepository(
    demoSnapshotJson(seniorSmsMessages: smsMessages),
  );
  final family = FamilyCubit(repo, pollInterval: null);
  await family.start();
  final shell = ShellCubit();
  addTearDown(family.close);
  addTearDown(shell.close);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: family),
        BlocProvider.value(value: shell),
      ],
      child: MaterialApp(
        theme: FbTheme.build(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SmsSheet(
              memberId: 'senior',
              initialSenderPhone: initialSenderPhone,
              onTapPhone: onTapPhone,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return repo;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('danger sms bubble displays warning badge, icon, easy explanation and reasons', (tester) async {
    await pumpSmsSheet(
      tester,
      smsMessages: [scamSmsJson(), normalSmsJson()],
    );

    expect(find.text('위험 문자 경고'), findsOneWidget);
    expect(find.text('위험'), findsOneWidget);
    expect(find.byIcon(FbIcons.alert), findsWidgets);
    expect(
      find.textContaining('기관이나 회사를 사칭해 링크를 누르게 하거나 전화를 유도하는 사기 의심 문자예요.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('공공·금융기관 사칭 의심 표현(금융감독원)이 들어 있어요'),
      findsOneWidget,
    );
  });

  testWidgets('tapping link in danger sms opens blocked link screen and never opens external url', (tester) async {
    await pumpSmsSheet(
      tester,
      smsMessages: [scamSmsJson()],
    );

    const fakeUrl = 'http://fss-verify.invalid/case/8821';
    expect(find.text(fakeUrl), findsOneWidget);

    await tester.tap(find.text(fakeUrl));
    await settle(tester);

    expect(find.text('이 링크를 열지 않았어요'), findsOneWidget);
    expect(find.text(fakeUrl), findsOneWidget);
    expect(
      find.textContaining('기관이나 회사를 사칭해 링크를 누르게 하거나 전화를 유도하는 사기 의심 문자예요.'),
      findsOneWidget,
    );

    await tester.tap(find.text('문자로 돌아가기'));
    await settle(tester);
    expect(find.text('이 링크를 열지 않았어요'), findsNothing);
    expect(find.text('위험 문자 경고'), findsOneWidget);
  });

  testWidgets('normal sms shows message without any warning badge or explanation', (tester) async {
    await pumpSmsSheet(
      tester,
      smsMessages: [normalSmsJson()],
    );

    expect(find.textContaining('주문하신 건강즙 상품이 오늘 오후 배송 완료되었습니다'), findsWidgets);
    expect(find.text('위험 문자 경고'), findsNothing);
    expect(find.text('주의가 필요한 문자예요'), findsNothing);
    expect(find.text('위험'), findsNothing);
  });

  testWidgets('phone number is non-clickable text until callback is connected', (tester) async {
    await pumpSmsSheet(
      tester,
      smsMessages: [scamSmsJson()],
    );
    expect(find.text('전화번호 02-0000-1332'), findsOneWidget);

    String? dialed;
    await pumpSmsSheet(
      tester,
      smsMessages: [scamSmsJson()],
      onTapPhone: (phone) => dialed = phone,
    );
    await tester.tap(find.text('02-0000-1332'));
    await settle(tester);
    expect(dialed, '02-0000-1332');
  });

  testWidgets('SmsSheet asScreen mode renders Greeting without sheet close button and hides close in blocked link view', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = FakeFamilyRepository(demoSnapshotJson(seniorSmsMessages: [scamSmsJson()]));
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
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SmsSheet(memberId: 'senior', asScreen: true),
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    expect(find.byTooltip('닫기'), findsNothing);
    expect(find.text('김순자님 · 사기 문자를 자동으로 살펴봐요'), findsOneWidget);

    await tester.tap(find.text('http://fss-verify.invalid/case/8821'));
    await settle(tester);
    expect(find.text('이 링크를 열지 않았어요'), findsOneWidget);
    expect(find.byTooltip('닫기'), findsNothing);
  });
}
