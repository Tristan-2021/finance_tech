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
  bool asScreen = false,
  ValueChanged<String>? onTapPhone,
  VoidCallback? onCallGuardian,
  DateTime? now,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = FakeFamilyRepository(
    demoSnapshotJson(now: now, seniorSmsMessages: smsMessages),
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
          body: SmsSheet(
            memberId: 'senior',
            asScreen: asScreen,
            initialSenderPhone: initialSenderPhone,
            onTapPhone: onTapPhone,
            onCallGuardian: onCallGuardian,
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

Map<String, dynamic> cautionSmsJson({
  String id = 'sms-caution-1',
  String senderName = '택배안내',
  String senderPhone = '070-0000-4419',
  String body = '배송 확인이 필요합니다 http://delivery-check.invalid/1',
  DateTime? now,
}) {
  final t = (now ?? DateTime.now()).toUtc();
  return {
    'id': id,
    'member_id': 'senior',
    'sender_name': senderName,
    'sender_phone': senderPhone,
    'body': body,
    'level': 'caution',
    'reasons': ['문자 안에 출처가 불분명한 인터넷 주소(링크)가 들어 있어요'],
    'explanation': '문자 안에 확인이 필요한 링크나 표현이 있어요. 아는 번호인지 먼저 확인해 주세요.',
    'links': ['http://delivery-check.invalid/1'],
    'phones': <String>[],
    'at': t.toIso8601String(),
  };
}

void main() {
  group('sms_format pure helpers', () {
    test('formatSmsListWhen and formatSmsThreadWhen use iOS Korean date/time strings', () {
      final now = DateTime(2026, 11, 17, 16, 0);
      expect(formatSmsListWhen(DateTime(2026, 11, 17, 15, 12), now), '오후 3:12');
      expect(formatSmsListWhen(DateTime(2026, 11, 17, 9, 5), now), '오전 9:05');
      expect(formatSmsListWhen(DateTime(2026, 11, 16, 20, 0), now), '어제');
      expect(formatSmsListWhen(DateTime(2026, 11, 15, 12, 30), now), '11월 15일');

      expect(formatSmsThreadWhen(DateTime(2026, 11, 17, 15, 12), now), '오늘 오후 3:12');
      expect(formatSmsThreadWhen(DateTime(2026, 11, 15, 15, 12), now), '11월 15일 (일) 오후 3:12');
    });

    test('parseSmsBodySegments splits inline links and phones without injecting missing sender phones', () {
      final scamSegs = parseSmsBodySegments(
        '사건 확인 http://fss-verify.invalid/case/8821 담당 02-0000-1332',
        links: const ['http://fss-verify.invalid/case/8821'],
        phones: const ['02-0000-1332'],
      );
      expect(scamSegs, const [
        SmsBodySegment(SmsSegmentKind.text, '사건 확인 '),
        SmsBodySegment(SmsSegmentKind.link, 'http://fss-verify.invalid/case/8821'),
        SmsBodySegment(SmsSegmentKind.text, ' 담당 '),
        SmsBodySegment(SmsSegmentKind.phone, '02-0000-1332'),
      ]);

      final normalSegs = parseSmsBodySegments(
        '주문하신 상품이 배송되었습니다.',
        links: const [],
        phones: const ['02-0000-5880'],
      );
      expect(normalSegs, const [
        SmsBodySegment(SmsSegmentKind.text, '주문하신 상품이 배송되었습니다.'),
      ]);

      expect(extractSmsLinkHost('http://fss-verify.invalid/case/8821'), 'fss-verify.invalid');
      expect(extractSmsLinkHost('https://spo-check.invalid:8443/doc'), 'spo-check.invalid');
      expect(extractSmsLinkHost('delivery-check.invalid/1'), 'delivery-check.invalid');
    });
  });

  testWidgets('conversation list renders newest first with icon + risk labels and person icon for nameless sender', (tester) async {
    final now = DateTime(2026, 11, 17, 16, 0);
    await pumpSmsSheet(
      tester,
      now: now,
      asScreen: true,
      smsMessages: [
        normalSmsJson(
          id: 'old-normal',
          senderName: '안심택배',
          senderPhone: '02-0000-5880',
          now: now.subtract(const Duration(days: 2)),
        ),
        cautionSmsJson(
          id: 'mid-caution',
          senderName: '',
          senderPhone: '070-0000-4419',
          now: now.subtract(const Duration(days: 1)),
        ),
        scamSmsJson(
          id: 'new-danger',
          senderName: '금융감독원 민원실(사칭)',
          senderPhone: '02-0000-1332',
          now: now.subtract(const Duration(minutes: 10)),
        ),
      ],
    );

    expect(find.text('메시지'), findsOneWidget);
    expect(find.textContaining('사기 문자를 자동으로 살펴봐요'), findsNothing);
    expect(find.text('위험'), findsOneWidget);
    expect(find.text('주의'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.text('어제'), findsOneWidget);
    expect(find.text('11월 15일'), findsOneWidget);

    final dangerY = tester.getTopLeft(find.byKey(const ValueKey('conv-02-0000-1332'))).dy;
    final cautionY = tester.getTopLeft(find.byKey(const ValueKey('conv-070-0000-4419'))).dy;
    final normalY = tester.getTopLeft(find.byKey(const ValueKey('conv-02-0000-5880'))).dy;
    expect(dangerY, lessThan(cautionY));
    expect(cautionY, lessThan(normalY));

    // 대화를 누르면 대화 화면으로 들어가고 뒤로 가면 목록으로 돌아옵니다.
    await tester.tap(find.byKey(const ValueKey('conv-02-0000-1332')));
    await settle(tester);
    expect(find.text('사기 의심 문자'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('conversation-back-button')));
    await settle(tester);
    expect(find.text('메시지'), findsOneWidget);
    expect(find.text('사기 의심 문자'), findsNothing);
  });

  testWidgets('danger sms bubble displays iOS warning card, icon, easy explanation and reasons', (tester) async {
    await pumpSmsSheet(
      tester,
      initialSenderPhone: '02-0000-1332',
      smsMessages: [scamSmsJson(), normalSmsJson()],
    );

    expect(find.text('사기 의심 문자'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(
      find.textContaining('기관이나 회사를 사칭해 링크를 누르게 하거나 전화를 유도하는 사기 의심 문자예요.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('공공·금융기관 사칭 의심 표현(금융감독원)이 들어 있어요'),
      findsOneWidget,
    );
    expect(find.text('사기 신고·도움'), findsOneWidget);
  });

  testWidgets('tapping link in danger sms opens blocked link screen and never opens external url', (tester) async {
    await pumpSmsSheet(
      tester,
      initialSenderPhone: '02-0000-1332',
      smsMessages: [scamSmsJson()],
    );

    const fakeUrl = 'http://fss-verify.invalid/case/8821';
    expect(find.textContaining(fakeUrl), findsOneWidget);

    await tester.tapOnText(find.textRange.ofSubstring(fakeUrl));
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
    expect(find.text('사기 의심 문자'), findsOneWidget);
  });

  testWidgets('normal sms without links shows message without preview rows, warning card, or badge', (tester) async {
    await pumpSmsSheet(
      tester,
      initialSenderPhone: '02-0000-5880',
      smsMessages: [normalSmsJson()],
      onTapPhone: (_) {},
    );

    expect(find.textContaining('주문하신 건강즙 상품이 오늘 오후 배송 완료되었습니다'), findsOneWidget);
    expect(find.text('링크'), findsNothing);
    expect(find.text('전화 걸기'), findsNothing);
    expect(find.text('사기 의심 문자'), findsNothing);
    expect(find.text('주의가 필요한 문자'), findsNothing);
    expect(find.text('위험'), findsNothing);
    expect(find.text('사기 신고·도움'), findsNothing);
  });

  testWidgets('danger sms shows >=57dp link and phone preview rows below bubble that open blocked link view and dial phone', (tester) async {
    final dialed = <String>[];
    await pumpSmsSheet(
      tester,
      initialSenderPhone: '02-0000-1332',
      smsMessages: [scamSmsJson()],
      onTapPhone: dialed.add,
    );

    const fakeUrl = 'http://fss-verify.invalid/case/8821';
    final linkRow = find.byKey(const ValueKey('sms-link-preview-$fakeUrl'));
    final phoneRow = find.byKey(const ValueKey('sms-phone-preview-02-0000-1332'));

    expect(linkRow, findsOneWidget);
    expect(phoneRow, findsOneWidget);
    expect(find.text('fss-verify.invalid'), findsOneWidget);
    expect(find.text('링크'), findsOneWidget);
    expect(find.text('전화 걸기'), findsOneWidget);
    expect(tester.getSize(linkRow).height, greaterThanOrEqualTo(57));
    expect(tester.getSize(phoneRow).height, greaterThanOrEqualTo(57));

    // 미리보기 줄이 말풍선 아래, 경고 띠 위에 놓입니다.
    final bubbleBottom = tester.getBottomLeft(find.byKey(const ValueKey('sms-bubble-text-sms-phishing-1'))).dy;
    final linkTop = tester.getTopLeft(linkRow).dy;
    final phoneTop = tester.getTopLeft(phoneRow).dy;
    final warningTop = tester.getTopLeft(find.text('사기 의심 문자')).dy;
    expect(bubbleBottom, lessThan(linkTop));
    expect(linkTop, lessThan(phoneTop));
    expect(phoneTop, lessThan(warningTop));

    await tester.tap(phoneRow);
    await settle(tester);
    expect(dialed, ['02-0000-1332']);

    await tester.tap(linkRow);
    await settle(tester);
    expect(find.text('이 링크를 열지 않았어요'), findsOneWidget);
    expect(find.text(fakeUrl), findsOneWidget);
  });

  testWidgets('phone number in bubble and preview row are disabled until callback is connected and header call dials sender', (tester) async {
    await pumpSmsSheet(
      tester,
      initialSenderPhone: '02-0000-1332',
      smsMessages: [scamSmsJson()],
    );
    expect(find.byKey(const ValueKey('conversation-call-button')), findsNothing);
    expect(find.byKey(const ValueKey('sms-phone-preview-02-0000-1332')), findsNothing);
    expect(find.text('전화 걸기'), findsNothing);

    final dialed = <String>[];
    await pumpSmsSheet(
      tester,
      initialSenderPhone: '02-0000-1332',
      smsMessages: [scamSmsJson()],
      onTapPhone: dialed.add,
    );

    await tester.tapOnText(
      find.textRange.ofSubstring(
        '02-0000-1332',
        descendentOf: find.byKey(const ValueKey('sms-bubble-text-sms-phishing-1')),
      ),
    );
    await settle(tester);
    expect(dialed, ['02-0000-1332']);

    await tester.tap(find.byKey(const ValueKey('sms-phone-preview-02-0000-1332')));
    await settle(tester);
    expect(dialed, ['02-0000-1332', '02-0000-1332']);

    await tester.tap(find.byKey(const ValueKey('conversation-call-button')));
    await settle(tester);
    expect(dialed, ['02-0000-1332', '02-0000-1332', '02-0000-1332']);
  });

  testWidgets('SmsSheet asScreen mode hides FingerBell greeting and close button in blocked link view', (tester) async {
    await pumpSmsSheet(
      tester,
      asScreen: true,
      initialSenderPhone: '02-0000-1332',
      smsMessages: [scamSmsJson()],
    );

    expect(find.byTooltip('닫기'), findsNothing);
    expect(find.textContaining('사기 문자를 자동으로 살펴봐요'), findsNothing);

    await tester.tapOnText(find.textRange.ofSubstring('http://fss-verify.invalid/case/8821'));
    await settle(tester);
    expect(find.text('이 링크를 열지 않았어요'), findsOneWidget);
    expect(find.byTooltip('닫기'), findsNothing);
  });
}
