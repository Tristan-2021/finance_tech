import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:feature_call/feature_call.dart';
import 'package:fingerbell_app/app_links.dart';
import 'package:fingerbell_app/call/call_app.dart';
import 'package:fingerbell_app/shell/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<(FakeFamilyRepository, FamilyCubit, MemoryPrefsStore)> _pumpCallApp(
  WidgetTester tester, {
  Size size = const Size(420, 900),
  Map<String, dynamic>? snapshot,
  Map<String, Object?>? prefs,
  Uri? initialLink,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = FakeFamilyRepository(snapshot);
  final family = FamilyCubit(repo, pollInterval: null);
  await family.start();
  addTearDown(family.close);
  final store = MemoryPrefsStore(prefs);

  await tester.pumpWidget(
    CallApp(
      family: family,
      store: store,
      feedback: const SilentFeedback(),
      initialLink: initialLink,
      rtcSessionFactory: NoopRtcPeerSession.new,
      chunkRecorderFactory: NoopChunkRecorder.new,
    ),
  );
  await _settle(tester);
  return (repo, family, store);
}

void main() {
  testWidgets('CallApp launcher home shows only callable family contacts for senior and guardian roles', (tester) async {
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    final (repo, _, store) = await _pumpCallApp(tester);

    // 어르신 첫 화면: 보호자 연락 카드 + 통화 버튼만 표시 (키패드·통화 기록 없음)
    expect(find.text('핑거벨 전화'), findsOneWidget);
    expect(find.text('보호자 김사랑 (딸)'), findsOneWidget);
    expect(find.text('보호자에게 전화하기'), findsOneWidget);
    expect(find.text('최근 통화'), findsNothing);
    expect(find.text('#'), findsNothing);

    // 보호자 역할로 전환 뒤 resume 시 연락할 수 있는 가족(어머니, 아들) 목록 표시
    await store.saveString('persona', 'guardian');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);

    expect(find.text('어머니 김순자에게 전화하기'), findsOneWidget);
    expect(find.text('아들 이민준에게 전화하기'), findsOneWidget);

    await tester.tap(find.text('어머니 김순자에게 전화하기'));
    await _settle(tester);
    expect(repo.calls, contains('startCall:guardian:senior:앱 안 통화'));
    expect(find.text('발신 중...'), findsOneWidget);
  });

  testWidgets('CallApp ignores invalid dial links and shows contacts home', (tester) async {
    final (repo, _, _) = await _pumpCallApp(
      tester,
      initialLink: Uri.parse('fingerbell://call/dial?peer=unknown'),
    );

    expect(find.text('보호자에게 전화하기'), findsOneWidget);
    expect(find.byType(CallSheet), findsNothing);
    expect(repo.calls.where((c) => c.startsWith('startCall:')), isEmpty);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      AppLinks.channel.name,
      AppLinks.channel.codec.encodeMethodCall(
        const MethodCall('onLink', 'fingerbell://call/dial?peer=counterpart&phone=not-a-phone'),
      ),
      (_) {},
    );
    await _settle(tester);

    expect(find.text('보호자에게 전화하기'), findsOneWidget);
    expect(find.byType(CallSheet), findsNothing);
    expect(repo.calls.where((c) => c.startsWith('startCall:')), isEmpty);
  });

  testWidgets('CallApp dials counterpart from link, shows scam warning, and switches to guardian call full-screen', (tester) async {
    final (repo, family, _) = await _pumpCallApp(
      tester,
      initialLink: Uri.parse('fingerbell://call/dial?peer=counterpart&phone=02-0000-1332'),
    );

    expect(repo.calls, contains('startCall:senior:counterpart:02-0000-1332'));
    expect(find.text('발신 중...'), findsOneWidget);
    expect(find.text('금융감독원 민원실(사칭)'), findsOneWidget);

    final scamCallId = family.state.data.activeCall!.id;
    await family.answerCall(scamCallId);
    await _settle(tester);

    repo.emitEvent(
      FamilyEvent(
        type: 'call_warning',
        message: '사기 의심 통화예요.',
        memberId: 'senior',
        callId: scamCallId,
        level: 'danger',
        explanation: '사기 의심 통화예요.',
      ),
    );
    await _settle(tester);
    expect(find.text('보이스피싱 위험 경고'), findsOneWidget);
    expect(find.text('통화 끊기'), findsWidgets);

    // 경고 배너의 사기 신고·도움 -> 보호자에게 전화 시 전체 화면 보호자 통화로 전환
    await tester.ensureVisible(find.byKey(const ValueKey('fraud-help-button')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('fraud-help-button')));
    await _settle(tester);
    await tester.tap(find.textContaining('보호자에게 전화').last);
    await _settle(tester);

    expect(repo.calls, contains('endCall:$scamCallId'));
    expect(repo.calls, contains('startCall:senior:guardian:010-••••-1024'));
    expect(find.byType(CallSheet), findsOneWidget);
    expect(find.text('가족 안심 통화 · 통화 내용을 분석하지 않아요'), findsOneWidget);
  });

  testWidgets('CallApp handles incoming call only while foreground and opens counterpart screen via link without self-hijack', (tester) async {
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    final (repo, family, _) = await _pumpCallApp(tester);

    // 1. 백그라운드(paused)일 때는 수신 화면을 띄우지 않습니다.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final incoming = await repo.startCall(
      callerId: 'guardian',
      calleeId: 'senior',
      peerPhone: '010-••••-1024',
      peerName: '보호자 김사랑',
    );
    repo.emitEvent(FamilyEvent(type: 'call', callId: incoming.id, memberId: 'senior'));
    await _settle(tester);
    expect(find.byType(CallSheet), findsNothing);

    // 2. 다시 화면에 뜨면(resume) 수신 화면이 뜨고 전화를 받을 수 있습니다.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);
    expect(find.text('전화가 걸려 왔어요'), findsOneWidget);
    expect(find.text('전화 받기'), findsOneWidget);
    await tester.tap(find.text('전화 받기'));
    await _settle(tester);
    expect(repo.calls, contains('answerCall:${incoming.id}'));
    expect(find.text('통화 중'), findsOneWidget);

    await tester.tap(find.text('통화 끊기'));
    await _settle(tester);
    await tester.tap(find.byTooltip('닫기'));
    await _settle(tester);

    // 3. 시연 상대 화면 링크 열기 -> 시연 상대 화면에서 어르신에게 전화를 걸어도 시연 상대 화면을 덮어쓰지 않습니다.
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      AppLinks.channel.name,
      AppLinks.channel.codec.encodeMethodCall(
        const MethodCall('onLink', 'fingerbell://call/counterpart'),
      ),
      (_) {},
    );
    await _settle(tester);
    expect(find.text('시연 상대 화면'), findsOneWidget);

    await tester.ensureVisible(find.text('어르신에게 전화 걸기'));
    await tester.pump();
    await tester.tap(find.text('어르신에게 전화 걸기'));
    await _settle(tester);
    expect(repo.calls, contains('startCall:counterpart:senior:02-0000-1332'));
    expect(find.byType(CounterpartSheet), findsOneWidget);
    expect(find.byType(CallSheet), findsNothing);
    expect(family.state.data.activeCall?.callerId, 'counterpart');
  });
}
