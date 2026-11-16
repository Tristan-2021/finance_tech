import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fingerbell_app/app.dart';
import 'package:fingerbell_app/app_links.dart';
import 'package:fingerbell_app/shell/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<(FakeFamilyRepository, ShellCubit)> pumpApp(
  WidgetTester tester, {
  required Size size,
  Map<String, dynamic>? snapshot,
  List<Uri>? openedLinks,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
  final shell = ShellCubit();
  addTearDown(family.close);
  addTearDown(shell.close);
  await tester.pumpWidget(
    FingerBellApp(family: family, shell: shell, feedback: const SilentFeedback(), serverAddress: 'http://127.0.0.1:8765'),
  );
  await settle(tester);
  return (repo, shell);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('mobile layout shows the senior home with bottom navigation', (tester) async {
    await pumpApp(tester, size: const Size(400, 860));
    expect(find.text('안녕하세요, 김순자님'), findsOneWidget);
    expect(find.text('2,350,000원'), findsOneWidget);
    expect(find.text('계좌 동결'), findsOneWidget);
    expect(find.text('안심'), findsOneWidget); // 하단 메뉴
    // 어르신도 송금·결제·조회를 모두 씁니다
    expect(find.text('송금'), findsOneWidget);
    expect(find.text('결제'), findsOneWidget);
    expect(find.text('조회'), findsOneWidget);
    expect(find.text('바로 시연해 보기'), findsNothing); // 설정 탭 전용
  });

  testWidgets('switching to the guardian shows the approval request', (tester) async {
    final (_, shell) = await pumpApp(
      tester,
      size: const Size(400, 860),
      snapshot: demoSnapshotJson(requests: [pendingTransferJson()]),
    );
    expect(find.textContaining('보호자 확인 대기 중', findRichText: true), findsOneWidget); // 어르신 화면 배너
    expect(find.text('거래 보류 중'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    await tester.tap(find.text('보호자').first);
    await settle(tester);
    expect(shell.state.persona, Persona.guardian);
    expect(find.text('확인할 요청이 1건 있어요'), findsOneWidget);
    expect(find.text('AI 위험도 79점 · 위험'), findsOneWidget);
    expect(find.text('해제'), findsOneWidget);
    expect(find.text('연장'), findsOneWidget);
  });

  testWidgets('senior home hold card cancels the hold when cancel is tapped', (tester) async {
    final (repo, shell) = await pumpApp(
      tester,
      size: const Size(400, 860),
      snapshot: demoSnapshotJson(requests: [pendingTransferJson()]),
    );
    final messages = <String>[];
    final sub = shell.feedback.listen((f) => messages.add(f.message));
    addTearDown(sub.cancel);

    expect(find.text('거래 보류 중'), findsOneWidget);
    await tester.ensureVisible(find.text('취소'));
    await tester.pump();
    await tester.tap(find.text('취소'));
    await settle(tester);
    expect(repo.calls, contains('cancel:req-1:senior'));
    expect(find.text('거래 보류 중'), findsNothing);
    expect(messages, contains('보류 중인 거래를 취소했어요'));
  });

  testWidgets('senior home shows caution mode and reconfirm hold buttons (proceed, stop, failure)', (tester) async {
    final (repo, shell) = await pumpApp(
      tester,
      size: const Size(400, 860),
      snapshot: demoSnapshotJson(
        seniorCautionMode: true,
        requests: [pendingTransferJson(status: 'reconfirm')],
      ),
    );
    final messages = <String>[];
    final sub = shell.feedback.listen((f) => messages.add(f.message));
    addTearDown(sub.cancel);

    expect(find.text('주의 모드 작동 중'), findsOneWidget);
    expect(find.text('본인 재확인 대기'), findsOneWidget);
    expect(find.text('그래도 진행'), findsOneWidget);
    expect(find.text('그만두기'), findsOneWidget);

    await tester.ensureVisible(find.text('그래도 진행'));
    await tester.pump();
    await tester.tap(find.text('그래도 진행'));
    await settle(tester);
    expect(repo.calls, contains('reconfirm:req-1:senior:true'));
    expect(find.text('본인 재확인 대기'), findsNothing);
    expect(find.text('1,850,000원'), findsOneWidget);
    expect(messages.last, '재확인 후 거래를 진행했어요');
  });

  testWidgets('senior home reconfirm stop cancels and failure reports reason', (tester) async {
    final (repo, shell) = await pumpApp(
      tester,
      size: const Size(400, 860),
      snapshot: demoSnapshotJson(
        requests: [pendingTransferJson(status: 'reconfirm')],
      ),
    );
    final messages = <String>[];
    final sub = shell.feedback.listen((f) => messages.add(f.message));
    addTearDown(sub.cancel);

    await tester.ensureVisible(find.text('그만두기'));
    await tester.pump();
    await tester.tap(find.text('그만두기'));
    await settle(tester);
    expect(repo.calls, contains('reconfirm:req-1:senior:false'));
    expect(find.text('본인 재확인 대기'), findsNothing);
    expect(find.text('2,350,000원'), findsOneWidget);
    expect(messages.last, '거래를 그만두었어요');

    repo.snapshotJson = demoSnapshotJson(requests: [pendingTransferJson(id: 'req-2', status: 'reconfirm')]);
    repo.failDecisionReason = '계좌가 동결되어 보내지 못했어요.';
    repo.emitEvent(const FamilyEvent(type: 'reconfirm', memberId: 'senior'));
    await settle(tester);
    expect(find.text('본인 재확인 대기'), findsOneWidget);

    await tester.ensureVisible(find.text('그래도 진행'));
    await tester.pump();
    await tester.tap(find.text('그래도 진행'));
    await settle(tester);
    expect(repo.calls, contains('reconfirm:req-2:senior:true'));
    expect(messages.last, '처리하지 못했어요 · 계좌가 동결되어 보내지 못했어요.');
  });

  testWidgets('guardian banks from their own account like everyone else', (tester) async {
    final (_, shell) = await pumpApp(tester, size: const Size(400, 860));
    shell.goto(Persona.guardian, AppTab.home);
    await settle(tester);
    expect(find.text('핑거벨 주거래 통장'), findsOneWidget);
    expect(find.text('3,480,000원'), findsOneWidget);
    expect(find.text('송금'), findsOneWidget);
    expect(find.text('결제'), findsOneWidget);
    expect(find.text('가족 모두 안전해요'), findsOneWidget); // 가족 보호 기능은 그대로
    expect(find.text('알림'), findsOneWidget); // 하단 메뉴: 홈 · 내역 · 알림 · 관리 · 설정

    shell.switchTab(AppTab.history);
    await settle(tester);
    expect(find.text('거래 내역'), findsOneWidget);
    expect(find.text('김순자님께 송금'), findsOneWidget);

    shell.switchTab(AppTab.alerts);
    await settle(tester);
    expect(find.text('가족 알림'), findsOneWidget);
  });

  testWidgets('child home shows the school mode and spending rail', (tester) async {
    final (_, shell) = await pumpApp(tester, size: const Size(400, 860));
    shell.goto(Persona.child, AppTab.home);
    await settle(tester);
    expect(find.text('안녕, 민준!'), findsOneWidget);
    expect(find.text('등교 모드'), findsOneWidget);
    expect(find.text('8,500 / 20,000원'), findsOneWidget);
    expect(find.text('결제'), findsOneWidget);
    expect(find.text('보내기'), findsOneWidget);
  });

  testWidgets('frozen senior sees the frozen card instead of the SOS button', (tester) async {
    await pumpApp(tester, size: const Size(400, 860), snapshot: demoSnapshotJson(seniorFrozen: true));
    expect(find.text('모든 계좌 출금이 멈춰 있어요'), findsOneWidget);
    expect(find.text('보호자에게 해제 요청'), findsOneWidget);
  });

  testWidgets('settings toggles high contrast and large text', (tester) async {
    final (_, shell) = await pumpApp(tester, size: const Size(400, 860));
    shell.switchTab(AppTab.settings);
    await settle(tester);
    expect(find.text('고대비 모드'), findsOneWidget);
    await tester.tap(find.byWidgetPredicate((w) => w is FbToggle && w.label == '고대비 모드'));
    await settle(tester);
    expect(shell.state.prefs.highContrast, isTrue);
    expect(find.text('바로 시연해 보기'), findsOneWidget);
    expect(find.text('사칭 문자 받기'), findsOneWidget);
    expect(find.text('정상 문자 받기'), findsOneWidget);
    expect(find.text('시연 상대 화면 열기'), findsOneWidget);
    expect(find.text('흔들어서 SOS 동결'), findsOneWidget);
    expect(find.text('낯선 계좌로 50만원 송금'), findsOneWidget);
    expect(find.text('등교 모드에서 게임 결제'), findsOneWidget);
    expect(find.text('처음 상태로 되돌리기'), findsOneWidget);
  });

  testWidgets('counterpart scenario opens phone app counterpart route', (tester) async {
    final opened = <Uri>[];
    final (_, shell) = await pumpApp(tester, size: const Size(400, 860), openedLinks: opened);
    shell.switchTab(AppTab.settings);
    await settle(tester);

    await tester.ensureVisible(find.text('시연 상대 화면 열기'));
    await tester.pump();
    await tester.tap(find.text('시연 상대 화면 열기'));
    await settle(tester);

    expect(opened, [Uri.parse('fingerbell://call/counterpart')]);
  });

  testWidgets('reconfirm hold call guardian button and guardian call family button open phone app', (tester) async {
    final opened = <Uri>[];
    final (_, shell) = await pumpApp(
      tester,
      size: const Size(400, 860),
      snapshot: demoSnapshotJson(requests: [pendingTransferJson(status: 'reconfirm')]),
      openedLinks: opened,
    );
    expect(find.text('보호자에게 전화'), findsOneWidget);
    await tester.ensureVisible(find.text('보호자에게 전화'));
    await tester.pump();
    await tester.tap(find.text('보호자에게 전화'));
    await settle(tester);
    expect(opened.last, Uri.parse('fingerbell://call/dial?peer=guardian'));

    shell.goto(Persona.guardian, AppTab.safety);
    await settle(tester);
    expect(find.text('어머니에게 전화하기'), findsOneWidget);
    await tester.tap(find.text('어머니에게 전화하기'));
    await settle(tester);
    expect(opened.last, Uri.parse('fingerbell://call/dial?peer=senior'));
  });

  testWidgets('phishing sms scenario starts caution mode and opens sms app to sender conversation', (tester) async {
    final opened = <Uri>[];
    final (repo, shell) = await pumpApp(tester, size: const Size(400, 860), openedLinks: opened);
    shell.switchTab(AppTab.settings);
    await settle(tester);

    await tester.ensureVisible(find.text('사칭 문자 받기'));
    await tester.pump();
    await tester.tap(find.text('사칭 문자 받기'));
    await settle(tester);

    expect(repo.calls, contains('receiveSms:senior:phishing'));
    expect(opened.last, Uri.parse('fingerbell://sms/conversation?phone=02-0000-1332'));
    expect(repo.snapshotJson['members'][0]['caution_mode'], isTrue);

    shell.goto(Persona.guardian, AppTab.safety);
    await settle(tester);
    expect(find.textContaining('주의 모드'), findsWidgets);
  });

  testWidgets('normal sms scenario keeps caution mode off and opens sms app to sender conversation', (tester) async {
    final opened = <Uri>[];
    final (repo, shell) = await pumpApp(tester, size: const Size(400, 860), openedLinks: opened);
    shell.switchTab(AppTab.settings);
    await settle(tester);

    await tester.ensureVisible(find.text('정상 문자 받기'));
    await tester.pump();
    await tester.tap(find.text('정상 문자 받기'));
    await settle(tester);

    expect(repo.calls, contains('receiveSms:senior:normal'));
    expect(opened.last, Uri.parse('fingerbell://sms/conversation?phone=02-0000-5880'));
    expect(repo.snapshotJson['members'][0]['caution_mode'], isFalse);
  });

  testWidgets('sms scenario notification and vibration follow server verdict level', (tester) async {
    final (repo, shell) = await pumpApp(tester, size: const Size(400, 860));
    final feedbacks = <FeedbackRequest>[];
    final sub = shell.feedback.listen(feedbacks.add);
    addTearDown(sub.cancel);

    // 서버가 '사칭 문자 받기' 요청에 대해 낮음(low) 단계를 돌려주면 위험 문구·위험 진동을 띄우지 않습니다.
    repo.forceSmsLevel = SmsRiskLevel.low;
    shell.switchTab(AppTab.settings);
    await settle(tester);

    await tester.ensureVisible(find.text('사칭 문자 받기'));

    await tester.pump();

    await tester.tap(find.text('사칭 문자 받기'));
    await settle(tester);

    expect(repo.calls, contains('receiveSms:senior:phishing'));
    expect(feedbacks, isNotEmpty);
    expect(feedbacks.last.message, '금융감독원 민원실(사칭) 문자가 도착했어요');
    expect(feedbacks.last.vibrate, const [40]);
    expect(find.text('위험 문자 경고'), findsNothing);
  });

  testWidgets('connection error screen offers a retry', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeFamilyRepository()..failNetwork = true;
    final family = FamilyCubit(repo, pollInterval: null);
    await family.start();
    await tester.pumpWidget(
      FingerBellApp(family: family, shell: ShellCubit(), feedback: const SilentFeedback(), serverAddress: 'http://10.0.0.9:8000'),
    );
    await settle(tester);
    expect(find.text('서버에 연결할 수 없어요'), findsOneWidget);
    expect(find.text('http://10.0.0.9:8000'), findsOneWidget);
    repo.failNetwork = false;
    await tester.tap(find.text('다시 시도'));
    await settle(tester);
    expect(find.text('안녕하세요, 김순자님'), findsOneWidget);
  });

  testWidgets('foreground AppShell opens phone app on incoming call and stays quiet when paused', (tester) async {
    final opened = <Uri>[];
    final (repo, shell) = await pumpApp(tester, size: const Size(400, 860), openedLinks: opened);
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));

    // 1. 백그라운드(paused)일 때는 걸려 온 전화가 와도 전화 앱을 열지 않습니다.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final pausedCall = await repo.startCall(
      callerId: 'guardian',
      calleeId: 'senior',
      peerPhone: '앱 안 통화',
      peerName: '어머니 김순자',
    );
    repo.emitEvent(FamilyEvent(type: 'call', callId: pausedCall.id, memberId: 'senior'));
    await settle(tester);
    expect(opened, isEmpty);

    // 2. 다시 화면에 뜨면(resume) 서버 상태를 다시 읽어 전화 앱을 엽니다(한 번만).
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(opened, [Uri.parse('fingerbell://call/incoming?callId=${pausedCall.id}')]);

    // 3. 종료 뒤 보호자 역할에 걸려 온 새 전화는 엽니다.
    await repo.endCall(pausedCall.id);
    await settle(tester);
    opened.clear();

    shell.goto(Persona.guardian, AppTab.home);
    await settle(tester);
    final callToGuardian = await repo.startCall(
      callerId: 'senior',
      calleeId: 'guardian',
      peerPhone: '010-••••-1024',
      peerName: '보호자 김사랑',
    );
    repo.emitEvent(FamilyEvent(type: 'call', callId: callToGuardian.id, memberId: 'senior'));
    await settle(tester);

    expect(opened, [Uri.parse('fingerbell://call/incoming?callId=${callToGuardian.id}')]);
  });

  testWidgets('call warning feedback runs only once per call id across AppShell and repeated chunks', (tester) async {
    final (repo, shell) = await pumpApp(tester, size: const Size(400, 860));
    final warningFeedbacks = <FeedbackRequest>[];
    final sub = shell.feedback.listen((f) {
      if (f.vibrate == callWarningVibration) warningFeedbacks.add(f);
    });
    addTearDown(sub.cancel);

    const callId = 'call-warn-1';
    const exp = '기관을 사칭하거나 적금 해지·안전계좌 이체를 요구하는 보이스피싱 의심 통화예요. 지금 바로 통화를 끊으세요.';

    repo.emitEvent(
      const FamilyEvent(
        type: 'call_warning',
        message: exp,
        memberId: 'senior',
        callId: callId,
        level: 'danger',
        explanation: exp,
      ),
    );
    await settle(tester);
    repo.emitEvent(
      const FamilyEvent(
        type: 'call_warning',
        message: exp,
        memberId: 'senior',
        callId: callId,
        level: 'danger',
        explanation: exp,
      ),
    );
    await settle(tester);

    expect(warningFeedbacks, hasLength(1));
  });

  testWidgets('DeviceFeedback invokes Android alert tone channel once and respects sound setting', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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

    final repo = FakeFamilyRepository();
    final family = FamilyCubit(repo, pollInterval: null);
    await family.start();
    final shell = ShellCubit();
    addTearDown(family.close);
    addTearDown(shell.close);

    await tester.pumpWidget(
      FingerBellApp(
        family: family,
        shell: shell,
        feedback: DeviceFeedback(),
        serverAddress: 'http://127.0.0.1:8765',
      ),
    );
    await settle(tester);

    shell.say('경고음 테스트', toast: false, vibrate: callWarningVibration, speak: false, alertSound: true);
    await settle(tester);
    expect(toneCalls, hasLength(1));
    expect(toneCalls.single.method, 'playAlertTone');
    final duration = (toneCalls.single.arguments as Map)['durationMs'] as int;
    expect(duration, lessThan(3000));

    // 진동이 짧아도(80ms) 위험 경고(alertSound: true)면 경고음을 냅니다.
    shell.say('짧은 진동 위험 경고', toast: false, vibrate: const [80, 40, 80], speak: false, alertSound: true);
    await settle(tester);
    expect(toneCalls, hasLength(2));

    // alertSound가 false이면 진동이 길어도 경고음을 내지 않습니다.
    shell.say('진동만', toast: false, vibrate: callWarningVibration, speak: false, alertSound: false);
    await settle(tester);
    expect(toneCalls, hasLength(2));

    // 소리 설정을 끄면 경고음을 내지 않습니다.
    shell.setPref(PrefKey.sound, false);
    await tester.pump();
    shell.say('무음 테스트', toast: false, vibrate: callWarningVibration, speak: false, alertSound: true);
    await settle(tester);
    expect(toneCalls, hasLength(2));
  });

  testWidgets('phishing transfer scenario reconfirm screen opens phone app to call guardian', (tester) async {
    final opened = <Uri>[];
    final (repo, shell) = await pumpApp(tester, size: const Size(400, 860), openedLinks: opened);
    shell.switchTab(AppTab.settings);
    await settle(tester);

    await tester.ensureVisible(find.text('낯선 계좌로 50만원 송금'));
    await tester.pump();
    await tester.tap(find.text('낯선 계좌로 50만원 송금'));
    await settle(tester);

    repo.snapshotJson = demoSnapshotJson(requests: [pendingTransferJson(status: 'reconfirm')]);
    await tester.tap(find.text('보호자에게 확인 요청'));
    await settle(tester);

    expect(find.text('본인 재확인 대기'), findsWidgets);
    await tester.tap(find.text('보호자에게 전화').last);
    await settle(tester);
    expect(opened.last, Uri.parse('fingerbell://call/dial?peer=guardian'));
  });

  testWidgets('AppShell suppresses tone, vibration, speech, and toast while paused while syncing reset state', (tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));

    final repo = FakeFamilyRepository();
    final family = FamilyCubit(repo, pollInterval: null);
    await family.start();
    final shell = ShellCubit();
    addTearDown(family.close);
    addTearDown(shell.close);

    final feedback = _RecordingFeedback();
    await tester.pumpWidget(
      FingerBellApp(
        family: family,
        shell: shell,
        feedback: feedback,
        serverAddress: 'http://127.0.0.1:8765',
      ),
    );
    await settle(tester);

    shell.goto(Persona.guardian);
    shell.setPref(PrefKey.sound, true);
    shell.setPref(PrefKey.haptics, true);
    shell.setPref(PrefKey.voice, true);
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    // 보호자 화면이 paused일 때 위험 문자와 통화 경고가 와도 사용자 출력은 0회여야 합니다.
    repo.emitEvent(
      const FamilyEvent(
        type: 'sms',
        level: 'danger',
        memberId: 'senior',
        message: '백그라운드 위험 문자',
      ),
    );
    repo.emitEvent(
      const FamilyEvent(
        type: 'call_warning',
        level: 'danger',
        memberId: 'senior',
        callId: 'paused-call-1',
        message: '보이스피싱 의심 경고',
        explanation: '기관 사칭 의심',
      ),
    );
    await settle(tester);

    expect(feedback.toneCount, 0);
    expect(feedback.vibrated, isEmpty);
    expect(feedback.spoken, isEmpty);
    expect(find.text('백그라운드 위험 문자'), findsNothing);
    expect(find.text('보이스피싱 의심 경고'), findsNothing);

    // paused 상태에서도 reset 이벤트의 상태 초기화 동기화는 수행되고 출력은 내지 않아야 합니다.
    repo.emitEvent(const FamilyEvent(type: 'reset', message: '초기화됨'));
    await settle(tester);
    expect(shell.state.persona, Persona.senior);
    expect(feedback.toneCount, 0);
    expect(feedback.vibrated, isEmpty);
    expect(feedback.spoken, isEmpty);
    expect(find.text('초기화됨'), findsNothing);
  });
}

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
