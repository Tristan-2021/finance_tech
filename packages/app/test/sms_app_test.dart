import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:fingerbell_app/app_links.dart';
import 'package:fingerbell_app/shell/feedback_service.dart';
import 'package:fingerbell_app/sms/sms_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Map<String, dynamic> _cautionSmsJson({
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

Future<(FakeFamilyRepository, FamilyCubit, MemoryPrefsStore)> _pumpSmsApp(
  WidgetTester tester, {
  Size size = const Size(420, 900),
  double textScale = 1.0,
  Map<String, dynamic>? snapshot,
  Map<String, Object?>? prefs,
  Uri? initialLink,
  List<Uri>? openedLinks,
  FeedbackOutput feedback = const SilentFeedback(),
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
  addTearDown(family.close);
  final store = MemoryPrefsStore(prefs);

  await tester.pumpWidget(
    SmsApp(
      family: family,
      store: store,
      feedback: feedback,
      initialLink: initialLink,
    ),
  );
  await _settle(tester);
  return (repo, family, store);
}

void main() {
  testWidgets('SmsApp shows iOS Messages list newest-first with risk icon and label, without FingerBell header', (tester) async {
    final now = DateTime(2026, 11, 17, 16, 0);
    await _pumpSmsApp(
      tester,
      snapshot: demoSnapshotJson(
        now: now,
        seniorSmsMessages: [
          normalSmsJson(
            id: 'sms-old',
            senderName: '안심택배',
            senderPhone: '02-0000-5880',
            now: now.subtract(const Duration(days: 2)),
          ),
          _cautionSmsJson(
            id: 'sms-caution',
            senderName: '',
            senderPhone: '070-0000-4419',
            now: now.subtract(const Duration(days: 1)),
          ),
          scamSmsJson(
            id: 'sms-new',
            senderName: '금융감독원 민원실(사칭)',
            senderPhone: '02-0000-1332',
            now: now.subtract(const Duration(minutes: 5)),
          ),
        ],
      ),
    );

    expect(find.text('메시지'), findsOneWidget);
    expect(find.text('핑거벨 문자'), findsNothing);
    expect(find.text('어르신'), findsNothing);
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

    // 대화를 누르면 대화 화면이 열리고, 뒤로 가기를 누르면 목록으로 돌아옵니다.
    await tester.tap(find.byKey(const ValueKey('conv-02-0000-1332')));
    await _settle(tester);
    expect(find.text('사기 의심 문자'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('conversation-back-button')));
    await _settle(tester);
    expect(find.text('메시지'), findsOneWidget);
    expect(find.text('사기 의심 문자'), findsNothing);
  });

  testWidgets('SmsApp opens conversation from deep link, blocks links without external open, and opens phone app on number or header call', (tester) async {
    final opened = <Uri>[];
    await _pumpSmsApp(
      tester,
      snapshot: demoSnapshotJson(seniorSmsMessages: [normalSmsJson(), scamSmsJson()]),
      initialLink: Uri.parse('fingerbell://sms/conversation?phone=02-0000-1332'),
      openedLinks: opened,
    );

    expect(find.text('핑거벨 문자'), findsNothing);
    expect(find.text('사기 의심 문자'), findsOneWidget);
    expect(find.text('금융감독원 민원실(사칭)'), findsOneWidget);
    expect(find.text('02-0000-1332'), findsNWidgets(2));

    const link = 'http://fss-verify.invalid/case/8821';
    final bubbleTextKey = const ValueKey('sms-bubble-text-sms-phishing-1');
    final linkRow = find.byKey(const ValueKey('sms-link-preview-$link'));
    final phoneRow = find.byKey(const ValueKey('sms-phone-preview-02-0000-1332'));
    expect(tester.getSize(linkRow).height, greaterThanOrEqualTo(57));
    expect(tester.getSize(phoneRow).height, greaterThanOrEqualTo(57));

    // 1. 말풍선 안의 전화번호 및 번호 미리보기 줄 누름 -> 전화 앱 발신 화면 열기
    await tester.tapOnText(
      find.textRange.ofSubstring('02-0000', descendentOf: find.byKey(bubbleTextKey)),
    );
    await _settle(tester);
    expect(opened.last, Uri.parse('fingerbell://call/dial?peer=counterpart&phone=02-0000-1332'));

    opened.clear();
    await tester.tap(phoneRow);
    await _settle(tester);
    expect(opened, [Uri.parse('fingerbell://call/dial?peer=counterpart&phone=02-0000-1332')]);

    // 2. 대화 화면 위쪽 막대의 전화 버튼 누름 -> 같은 번호로 전화 앱 발신 화면 열기
    opened.clear();
    await tester.tap(find.byKey(const ValueKey('conversation-call-button')));
    await _settle(tester);
    expect(opened, [Uri.parse('fingerbell://call/dial?peer=counterpart&phone=02-0000-1332')]);

    // 3. 링크 미리보기 줄 누름 -> 외부로 열지 않고 전체 화면 차단 안내([닫기] 버튼 없음), 뒤로 돌아가기
    opened.clear();
    await tester.ensureVisible(linkRow);
    await tester.pump();
    await tester.tap(linkRow);
    await _settle(tester);

    expect(opened, isEmpty);
    expect(find.text('이 링크를 열지 않았어요'), findsOneWidget);
    expect(find.byTooltip('닫기'), findsNothing);

    await tester.ensureVisible(find.text('사기 신고·도움'));
    await tester.pump();
    await tester.tap(find.text('사기 신고·도움'));
    await _settle(tester);
    await tester.tap(find.textContaining('보호자에게 전화').last);
    await _settle(tester);
    expect(opened.last, Uri.parse('fingerbell://call/dial?peer=guardian'));

    await tester.ensureVisible(find.text('문자로 돌아가기'));
    await tester.pump();
    await tester.tap(find.text('문자로 돌아가기'));
    await _settle(tester);
    expect(find.text('이 링크를 열지 않았어요'), findsNothing);
    expect(find.text('사기 의심 문자'), findsOneWidget);

    // 말풍선 안 링크를 눌러도 똑같이 차단 화면이 뜹니다.
    opened.clear();
    await tester.tapOnText(
      find.textRange.ofSubstring(link, descendentOf: find.byKey(bubbleTextKey)),
    );
    await _settle(tester);
    expect(opened, isEmpty);
    expect(find.text('이 링크를 열지 않았어요'), findsOneWidget);
  });

  testWidgets('SmsApp ignores unknown or malformed link phone and follows shared role on resume', (tester) async {
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    final (_, _, store) = await _pumpSmsApp(
      tester,
      snapshot: demoSnapshotJson(seniorSmsMessages: [normalSmsJson(), scamSmsJson()]),
      initialLink: Uri.parse('fingerbell://sms/conversation?phone=010-9999-9999'),
    );

    // 모르는 번호 링크이면 대화 목록('메시지')에 머무릅니다.
    expect(find.text('메시지'), findsOneWidget);
    expect(find.text('안심택배'), findsOneWidget);
    expect(find.text('사기 의심 문자'), findsNothing);

    // 형식이 틀린 번호 링크 수신 시에도 대화 목록에 머무릅니다.
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      AppLinks.channel.name,
      AppLinks.channel.codec.encodeMethodCall(
        const MethodCall('onLink', 'fingerbell://sms/conversation?phone=bad-phone'),
      ),
      (_) {},
    );
    await _settle(tester);
    expect(find.text('메시지'), findsOneWidget);
    expect(find.text('사기 의심 문자'), findsNothing);

    // 공유 역할이 아이로 바뀌고 resume 되면 아이의 빈 문자 목록('메시지 없음')으로 전환
    await store.saveString('persona', 'child');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);
    expect(find.text('아이'), findsNothing);
    expect(find.text('메시지 없음'), findsOneWidget);
  });

  testWidgets('SmsApp announces incoming SMS and opens phone app on incoming call only while foreground', (tester) async {
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    final opened = <Uri>[];
    final feedback = _RecordingFeedback();
    final (repo, _, _) = await _pumpSmsApp(
      tester,
      prefs: {'sound': true, 'haptics': true, 'voice': true},
      openedLinks: opened,
      feedback: feedback,
    );

    // 백그라운드(paused) 상태에서는 문자 안내·전화 앱 열기를 하지 않습니다.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    repo.emitEvent(
      const FamilyEvent(
        type: 'sms',
        message: '사기 의심 문자가 도착했어요',
        memberId: 'senior',
        level: 'danger',
      ),
    );
    final call = await repo.startCall(
      callerId: 'guardian',
      calleeId: 'senior',
      peerPhone: '앱 안 통화',
      peerName: '보호자 김사랑',
    );
    repo.emitEvent(FamilyEvent(type: 'call', callId: call.id, memberId: 'senior'));
    await _settle(tester);
    expect(feedback.toneCount, 0);
    expect(opened, isEmpty);

    // 포그라운드(resumed)에서 새 위험 문자는 경고음·진동·음성으로 알리고, 걸려 온 전화는 전화 앱을 엽니다.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);
    expect(opened, [Uri.parse('fingerbell://call/incoming?callId=${call.id}')]);

    repo.emitEvent(
      const FamilyEvent(
        type: 'sms',
        message: '사기 의심 문자가 도착했어요',
        memberId: 'senior',
        level: 'danger',
      ),
    );
    await _settle(tester);
    expect(feedback.toneCount, 1);
    expect(feedback.spoken, contains('사기 의심 문자가 도착했어요'));
  });

  testWidgets('SmsApp renders conversation list, danger thread, and blocked link at 2.0x text scale without overflow', (tester) async {
    await _pumpSmsApp(
      tester,
      size: const Size(360, 780),
      textScale: 2.0,
      prefs: {'largeText': true, 'highContrast': true},
      snapshot: demoSnapshotJson(seniorSmsMessages: [normalSmsJson(), scamSmsJson()]),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('메시지'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('conv-02-0000-1332'))).height,
      greaterThanOrEqualTo(57),
    );

    await tester.tap(find.byKey(const ValueKey('conv-02-0000-1332')));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('사기 의심 문자'), findsOneWidget);
    expect(find.text('사기 신고·도움'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('conversation-back-button'))).width,
      greaterThanOrEqualTo(57),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('conversation-call-button'))).width,
      greaterThanOrEqualTo(57),
    );
    final linkRow = find.byKey(const ValueKey('sms-link-preview-http://fss-verify.invalid/case/8821'));
    final phoneRow = find.byKey(const ValueKey('sms-phone-preview-02-0000-1332'));
    expect(tester.getSize(linkRow).height, greaterThanOrEqualTo(57));
    expect(tester.getSize(phoneRow).height, greaterThanOrEqualTo(57));

    await tester.ensureVisible(linkRow);
    await tester.pump();
    await tester.tap(linkRow);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('이 링크를 열지 않았어요'), findsOneWidget);
  });

  testWidgets('SmsApp reads initialLink from AppLinks platform channel on cold start', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      AppLinks.channel,
      (call) async => call.method == 'initialLink' ? 'fingerbell://sms/conversation?phone=02-0000-1332' : null,
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        AppLinks.channel,
        null,
      );
    });

    final repo = FakeFamilyRepository(demoSnapshotJson(seniorSmsMessages: [normalSmsJson(), scamSmsJson()]));
    final family = FamilyCubit(repo, pollInterval: null);
    await family.start();
    addTearDown(family.close);

    await tester.pumpWidget(
      SmsApp(family: family, store: MemoryPrefsStore(), feedback: const SilentFeedback()),
    );
    await _settle(tester);

    expect(find.text('사기 의심 문자'), findsOneWidget);
  });
}
