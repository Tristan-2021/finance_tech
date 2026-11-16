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
  testWidgets('SmsApp opens conversation from deep link, blocks links, and opens phone app on number or guardian call', (tester) async {
    final opened = <Uri>[];
    await _pumpSmsApp(
      tester,
      snapshot: demoSnapshotJson(seniorSmsMessages: [normalSmsJson(), scamSmsJson()]),
      initialLink: Uri.parse('fingerbell://sms/conversation?phone=02-0000-1332'),
      openedLinks: opened,
    );

    expect(find.text('핑거벨 문자'), findsOneWidget);
    expect(find.text('위험 문자 경고'), findsOneWidget);
    expect(find.text('02-0000-1332'), findsOneWidget);

    // 문자 속 전화번호 누름 -> 전화 앱 열기
    await tester.ensureVisible(find.text('02-0000-1332'));
    await tester.pump();
    await tester.tap(find.text('02-0000-1332'));
    await _settle(tester);
    expect(opened.last, Uri.parse('fingerbell://call/dial?peer=counterpart&phone=02-0000-1332'));

    // 위험 문자의 링크 누름 -> 전체 화면 차단 안내([닫기] 버튼 없음), 뒤로 돌아가기
    const link = 'http://fss-verify.invalid/case/8821';
    await tester.ensureVisible(find.text(link));
    await tester.pump();
    await tester.tap(find.text(link));
    await _settle(tester);

    expect(find.text('이 링크를 열지 않았어요'), findsOneWidget);
    expect(find.byTooltip('닫기'), findsNothing);

    await tester.ensureVisible(find.text('사기 신고·도움'));
    await tester.pump();
    await tester.tap(find.text('사기 신고·도움'));
    await _settle(tester);
    await tester.tap(find.textContaining('보호자에게 전화').last);
    await _settle(tester);
    expect(opened.last, Uri.parse('fingerbell://call/dial?peer=guardian'));

    await tester.tap(find.text('문자로 돌아가기'));
    await _settle(tester);
    expect(find.text('이 링크를 열지 않았어요'), findsNothing);
    expect(find.text('위험 문자 경고'), findsOneWidget);
  });

  testWidgets('SmsApp ignores unknown or malformed link phone and follows shared role on resume', (tester) async {
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    final (_, _, store) = await _pumpSmsApp(
      tester,
      snapshot: demoSnapshotJson(seniorSmsMessages: [normalSmsJson(), scamSmsJson()]),
      initialLink: Uri.parse('fingerbell://sms/conversation?phone=010-9999-9999'),
    );

    // 첫 번째 대화(안심택배)가 기본으로 보임
    expect(find.text('안심택배 (02-0000-5880)'), findsOneWidget);
    expect(find.text('위험 문자 경고'), findsNothing);

    // 형식이 틀린 번호 링크 수신 시에도 무시
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      AppLinks.channel.name,
      AppLinks.channel.codec.encodeMethodCall(
        const MethodCall('onLink', 'fingerbell://sms/conversation?phone=bad-phone'),
      ),
      (_) {},
    );
    await _settle(tester);
    expect(find.text('안심택배 (02-0000-5880)'), findsOneWidget);

    // 공유 역할이 아이로 바뀌고 resume 되면 아이의 문자 목록으로 전환
    await store.saveString('persona', 'child');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);
    expect(find.text('아이'), findsOneWidget);
    expect(find.text('아직 받은 문자가 없어요'), findsOneWidget);
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

  testWidgets('SmsApp renders danger sms at 2.0x text scale without overflow', (tester) async {
    await _pumpSmsApp(
      tester,
      size: const Size(360, 780),
      textScale: 2.0,
      prefs: {'largeText': true},
      snapshot: demoSnapshotJson(seniorSmsMessages: [scamSmsJson()]),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('위험 문자 경고'), findsOneWidget);
    expect(find.text('사기 신고·도움'), findsOneWidget);
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

    expect(find.text('위험 문자 경고'), findsOneWidget);
  });
}
