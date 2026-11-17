import 'dart:async';
import 'dart:io';

import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_call/feature_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

class _FakeAudioRecorder implements AudioRecorder {
  String? _currentPath;
  int startCount = 0;
  bool disposed = false;

  @override
  Future<bool> hasPermission({bool request = true}) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    startCount += 1;
    _currentPath = path;
    await File(path).writeAsBytes(const <int>[1, 2, 3, 4]);
  }

  @override
  Future<String?> stop() async {
    final p = _currentPath;
    _currentPath = null;
    return p;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(FakeFamilyRepository, FamilyCubit, ShellCubit)> pumpCallWidget(
  WidgetTester tester,
  Widget child, {
  Map<String, dynamic>? snapshot,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = FakeFamilyRepository(snapshot ?? demoSnapshotJson());
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
          body: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );
  await tester.pump();
  return (repo, family, shell);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('dialing transitions from outgoing ringing to active call screen, ticks elapsed timer, toggles mute/speaker, and starts chunk recorder', (tester) async {
    final rtc = NoopRtcPeerSession();
    final recorder = NoopChunkRecorder();
    final (repo, family, _) = await pumpCallWidget(
      tester,
      CallSheet(
        localParticipantId: 'senior',
        callerId: 'senior',
        calleeId: 'counterpart',
        peerPhone: '02-0000-1332',
        peerName: '금융감독원 민원실(사칭)',
        rtcSession: rtc,
        chunkRecorder: recorder,
      ),
    );
    await settle(tester);

    expect(repo.calls, contains('startCall:senior:counterpart:02-0000-1332'));
    expect(find.text('발신 중…'), findsOneWidget);
    expect(find.text('금융감독원 민원실(사칭)'), findsOneWidget);
    expect(find.text('02-0000-1332'), findsOneWidget);
    expect(find.text('AI 실시간 보이스피싱 감지 작동 중'), findsNothing);
    expect(rtc.startedAsCaller, isTrue);
    expect(recorder.started, isFalse);

    final callId = family.state.data.activeCall!.id;
    await family.answerCall(callId);
    await settle(tester);

    expect(find.text('00:00'), findsOneWidget);
    expect(recorder.started, isTrue);

    // answeredAt 기준 경과 시간(예: 03:12)을 표시합니다.
    final serverNow = DateTime.now().toUtc();
    repo.snapshotJson['server_time'] = serverNow.toIso8601String();
    final activeMap = repo.snapshotJson['active_call'] as Map<String, dynamic>;
    activeMap['answered_at'] = serverNow
        .subtract(const Duration(minutes: 3, seconds: 12, milliseconds: 500))
        .toIso8601String();
    await family.refresh();
    await settle(tester);
    expect(find.text('03:12'), findsOneWidget);

    await tester.tap(find.text('소리 끔'));
    await tester.pump();
    expect(rtc.muted, isTrue);

    await tester.tap(find.text('스피커'));
    await tester.pump();
    expect(rtc.speakerphoneEnabled, isTrue);

    await tester.tap(find.text('소리 끔'));
    await tester.pump();
    expect(rtc.muted, isFalse);
  });

  testWidgets('recording failure shows voice analysis unavailable text without dropping the call', (tester) async {
    final rtc = NoopRtcPeerSession();
    final recorder = NoopChunkRecorder(simulateFailure: true);
    final (_, family, _) = await pumpCallWidget(
      tester,
      CallSheet(
        localParticipantId: 'senior',
        callerId: 'senior',
        calleeId: 'counterpart',
        peerPhone: '02-0000-1332',
        rtcSession: rtc,
        chunkRecorder: recorder,
      ),
    );
    await settle(tester);

    final callId = family.state.data.activeCall!.id;
    await family.answerCall(callId);
    await settle(tester);

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text('음성 분석을 쓸 수 없어요'), findsOneWidget);
    expect(rtc.closed, isFalse);
  });

  testWidgets('call warning event displays big warning banner, easy explanation, and hangup button', (tester) async {
    final rtc = NoopRtcPeerSession();
    final recorder = NoopChunkRecorder();
    final (repo, family, shell) = await pumpCallWidget(
      tester,
      CallSheet(
        localParticipantId: 'senior',
        callerId: 'senior',
        calleeId: 'counterpart',
        peerPhone: '02-0000-1332',
        rtcSession: rtc,
        chunkRecorder: recorder,
      ),
    );
    final feedbacks = <FeedbackRequest>[];
    final sub = shell.feedback.listen(feedbacks.add);
    addTearDown(sub.cancel);
    await settle(tester);

    final callId = family.state.data.activeCall!.id;
    await family.answerCall(callId);
    await settle(tester);

    const explanation = '기관을 사칭하거나 적금 해지·안전계좌 이체를 요구하는 보이스피싱 의심 통화예요. 지금 바로 통화를 끊으세요.';
    repo.emitEvent(
      FamilyEvent(
        type: 'call_warning',
        message: explanation,
        memberId: 'senior',
        callId: callId,
        level: 'danger',
        explanation: explanation,
        reasons: const ['공공·금융기관 사칭 의심 표현(금융감독원)이 나왔어요'],
      ),
    );
    await settle(tester);

    expect(find.text('보이스피싱 위험 경고'), findsOneWidget);
    expect(find.text(explanation), findsOneWidget);
    expect(find.text('통화 끊기'), findsWidgets);
    expect(feedbacks, isNotEmpty);
    expect(feedbacks.last.message, contains(explanation));
    expect(feedbacks.last.vibrate, callWarningVibration);

    await tester.tap(find.text('통화 끊기').first);
    await settle(tester);
    expect(repo.calls, contains('endCall:$callId'));
  });

  testWidgets('counterpart screen displays notice and sends scam and normal script sentences', (tester) async {
    final (repo, family, _) = await pumpCallWidget(
      tester,
      CounterpartSheet(
        rtcSession: NoopRtcPeerSession(),
        chunkRecorder: NoopChunkRecorder(),
      ),
    );
    await settle(tester);

    expect(find.text('시연 상대 화면'), findsOneWidget);
    expect(find.text('음성인식 없이 문장을 보냅니다'), findsOneWidget);

    // 걸려 온 전화가 있을 때 전화 받기 버튼 표시 및 수신
    final call = await family.startCall(
      callerId: 'senior',
      calleeId: 'counterpart',
      peerPhone: '02-0000-1332',
    );
    await settle(tester);
    expect(find.text('전화 받기'), findsOneWidget);
    await tester.tap(find.text('전화 받기'));
    await settle(tester);
    expect(repo.calls, contains('answerCall:${call.id}'));

    // 정상 대본 문장 보내기 → 경고 없음, 주의 모드 꺼짐 유지
    await tester.ensureVisible(find.byKey(const ValueKey('script-normal-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('script-normal-0')));
    await settle(tester);
    expect(repo.calls, contains('sendCallTranscript:${call.id}:low'));
    expect(family.state.data.member('senior').cautionMode, isFalse);

    // 사기 대본 문장 보내기 → 위험 판정, 주의 모드 시작, 보호자 알림 추가
    await tester.ensureVisible(find.byKey(const ValueKey('script-phishing-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('script-phishing-0')));
    await settle(tester);
    expect(repo.calls, contains('sendCallTranscript:${call.id}:danger'));
    expect(family.state.data.member('senior').cautionMode, isTrue);
    expect(family.state.data.activeCall?.isDanger, isTrue);
    expect(family.state.data.alerts.any((a) => a.status == 'danger'), isTrue);
  });

  testWidgets('signaling order waits for ready before offer, queues early ICE, and shows connection status', (tester) async {
    final callerRtc = NoopRtcPeerSession();
    final calleeRtc = NoopRtcPeerSession();
    final (repo, family, _) = await pumpCallWidget(
      tester,
      CallSheet(
        localParticipantId: 'senior',
        callerId: 'senior',
        calleeId: 'counterpart',
        peerPhone: '02-0000-1332',
        rtcSession: callerRtc,
        chunkRecorder: NoopChunkRecorder(),
      ),
    );
    await settle(tester);

    final callId = family.state.data.activeCall!.id;
    // 발신 직후에는 offer를 바로 보내지 않고 '음성 연결 중' 상태를 표시합니다.
    expect(find.text(rtcConnectingText), findsOneWidget);
    expect(repo.sentSignals.where((s) => s['signal_type'] == 'offer'), isEmpty);

    // 원격 설명(setRemoteDescription) 설정 전에 도착한 ICE 후보는 대기열에 모입니다.
    repo.emitRtcSignal({
      'type': 'rtc_signal',
      'call_id': callId,
      'signal_type': 'ice',
      'from': 'counterpart',
      'data': const {'candidate': 'early-ice-1', 'sdpMid': '0', 'sdpMLineIndex': 0},
    });
    await tester.pump();
    expect(callerRtc.pendingIceCandidates, hasLength(1));
    expect(callerRtc.appliedIceCandidates, isEmpty);

    // 받는 쪽이 [전화 받기]로 연결 준비를 마치면 ready 신호를 보내고, 발신 쪽이 offer → 수신 쪽이 answer로 응답합니다.
    final calleeSub = family.rtcSignals.listen(calleeRtc.onSignal);
    addTearDown(calleeSub.cancel);
    await calleeRtc.startAsCallee(
      callId: callId,
      localId: 'counterpart',
      sendSignal: family.sendRtcSignal,
    );
    await settle(tester);

    final signalTypes = repo.sentSignals.map((s) => s['signal_type']).toList();
    expect(signalTypes, containsAllInOrder(['ready', 'offer', 'answer']));
    expect(callerRtc.pendingIceCandidates, isEmpty);
    expect(callerRtc.appliedIceCandidates, hasLength(1));
    expect(find.text(rtcConnectedText), findsOneWidget);
  });

  testWidgets('rtc connection failure shows failure status while keeping call UI functional', (tester) async {
    final rtc = NoopRtcPeerSession(simulateFailure: true);
    final (repo, family, _) = await pumpCallWidget(
      tester,
      CallSheet(
        localParticipantId: 'senior',
        callerId: 'senior',
        calleeId: 'counterpart',
        peerPhone: '02-0000-1332',
        rtcSession: rtc,
        chunkRecorder: NoopChunkRecorder(),
      ),
    );
    await settle(tester);

    expect(find.text(rtcFailedText), findsOneWidget);
    final callId = family.state.data.activeCall!.id;
    await family.answerCall(callId);
    await settle(tester);

    expect(find.text('00:00'), findsOneWidget);
    expect(find.text(rtcFailedText), findsOneWidget);
    await tester.tap(find.text('종료'));
    await settle(tester);
    expect(repo.calls, contains('endCall:$callId'));
    expect(find.text('통화 종료'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('ending, popping, or dismissing call sheet terminates server call session on all paths', (tester) async {
    final (repo, family, _) = await pumpCallWidget(
      tester,
      CallSheet(
        localParticipantId: 'senior',
        callerId: 'senior',
        calleeId: 'counterpart',
        peerPhone: '02-0000-1332',
        rtcSession: NoopRtcPeerSession(),
        chunkRecorder: NoopChunkRecorder(),
      ),
    );
    await settle(tester);
    final firstCallId = family.state.data.activeCall!.id;

    // 1. 종료 버튼을 누르면 서버 통화 세션을 종료하고 "통화 종료"를 표시합니다.
    await tester.tap(find.text('종료'));
    await settle(tester);
    expect(repo.calls, contains('endCall:$firstCallId'));
    expect(find.text('통화 종료'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    // 2. 라우트 뒤로가기(pop) · 위젯 제거(dispose) 시에도 서버 통화 세션을 종료합니다.
    await tester.pumpWidget(const SizedBox.shrink());
    final (_, family2, _) = await pumpCallWidget(
      tester,
      CallSheet(
        localParticipantId: 'senior',
        callerId: 'senior',
        calleeId: 'counterpart',
        peerPhone: '02-0000-1332',
        rtcSession: NoopRtcPeerSession(),
        chunkRecorder: NoopChunkRecorder(),
      ),
    );
    await settle(tester);
    final secondCallId = family2.state.data.activeCall!.id;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(family2.isCallEnding(secondCallId), isTrue);
  });

  testWidgets('counterpart sheet cleans up recorder and rtc on remote hangup and connects a second call with a new rtc session', (tester) async {
    final sessions = <NoopRtcPeerSession>[];
    final recorder = NoopChunkRecorder();
    final (repo, family, _) = await pumpCallWidget(
      tester,
      CounterpartSheet(
        rtcSessionFactory: () {
          final s = NoopRtcPeerSession();
          sessions.add(s);
          return s;
        },
        chunkRecorder: recorder,
      ),
    );
    await settle(tester);

    // 첫 번째 통화 수신
    final call1 = await family.startCall(
      callerId: 'senior',
      calleeId: 'counterpart',
      peerPhone: '02-0000-1332',
    );
    await settle(tester);
    await tester.tap(find.text('전화 받기'));
    await settle(tester);
    expect(sessions, hasLength(1));
    expect(sessions.first.startedAsCallee, isTrue);
    expect(recorder.started, isTrue);

    // 상대(어르신)가 통화를 끊으면 녹음기와 WebRTC를 즉시 정리합니다.
    await family.endCall(call1.id);
    await settle(tester);
    expect(sessions.first.closed, isTrue);
    expect(recorder.stopped, isTrue);

    // 같은 시연 상대 화면에서 두 번째 통화가 걸려 오면 새 WebRTC 세션을 만들어 연결합니다.
    final call2 = await family.startCall(
      callerId: 'senior',
      calleeId: 'counterpart',
      peerPhone: '02-0000-1332',
    );
    await settle(tester);
    await tester.tap(find.text('전화 받기'));
    await settle(tester);
    expect(sessions, hasLength(2));
    expect(sessions[1].startedAsCallee, isTrue);
    expect(sessions[1].closed, isFalse);
    expect(
      repo.sentSignals.where((s) => s['call_id'] == call2.id && s['signal_type'] == 'ready'),
      isNotEmpty,
    );
  });

  test('RecordChunkRecorder rotates next chunk on schedule without waiting for slow upload', () async {
    final fakeRecorder = _FakeAudioRecorder();
    final recorder = RecordChunkRecorder(
      chunkDuration: const Duration(milliseconds: 45),
      createRecorder: () => fakeRecorder,
    );
    final uploadBlocker = Completer<void>();
    var chunkCalls = 0;
    addTearDown(() async {
      if (!uploadBlocker.isCompleted) uploadBlocker.complete();
      await recorder.stop();
    });

    await recorder.start(
      onChunk: (_, _) async {
        chunkCalls += 1;
        await uploadBlocker.future;
      },
      onFailure: (_) => fail('recorder should not fail'),
    );

    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (fakeRecorder.startCount < 3 || chunkCalls < 2) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for chunk rotation (startCount=${fakeRecorder.startCount}, chunkCalls=$chunkCalls)');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    // 첫 업로드가 아직 끝나지 않았어도 녹음 회전은 타이머 주기에 맞춰 계속 일어납니다.
    expect(uploadBlocker.isCompleted, isFalse);
    expect(fakeRecorder.startCount, greaterThanOrEqualTo(3));
    expect(chunkCalls, greaterThanOrEqualTo(2));

    uploadBlocker.complete();
    await recorder.stop();
    expect(fakeRecorder.disposed, isTrue);
  });

  testWidgets('switching from scam warning to guardian call closes previous CallSheet completely', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = FakeFamilyRepository(demoSnapshotJson());
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
            body: Builder(
              builder: (context) => FbButton(
                '통화 시작',
                onPressed: () => openCallSheet(
                  context,
                  localParticipantId: 'senior',
                  callerId: 'senior',
                  calleeId: 'counterpart',
                  peerPhone: '02-0000-1332',
                  peerName: '금융감독원 민원실(사칭)',
                  rtcSession: NoopRtcPeerSession(),
                  chunkRecorder: NoopChunkRecorder(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('통화 시작'));
    await settle(tester);
    final scamCallId = family.state.data.activeCall!.id;
    await family.answerCall(scamCallId);
    await settle(tester);

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
    await settle(tester);
    expect(find.text('보이스피싱 위험 경고'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('fraud-help-button')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('fraud-help-button')));
    await settle(tester);

    await tester.ensureVisible(find.textContaining('보호자에게 전화'));
    await settle(tester);
    await tester.tap(find.textContaining('보호자에게 전화'));
    await settle(tester);

    expect(repo.calls, contains('endCall:$scamCallId'));
    expect(repo.calls, contains('startCall:senior:guardian:010-••••-1024'));
    // 기존 사기 통화 시트가 아래에 남지 않고 보호자 통화 시트 하나만 남아 있어야 합니다.
    expect(find.byType(CallSheet), findsOneWidget);
    expect(find.text('보이스피싱 위험 경고'), findsNothing);
    expect(find.text('보호자 김사랑'), findsOneWidget);
    expect(find.text('가족 안심 통화 · 통화 내용을 분석하지 않아요'), findsNothing);
  });

  testWidgets('CallSheet uses onSwitchCall callback when provided', (tester) async {
    String? switchedTarget;
    final (_, family, _) = await pumpCallWidget(
      tester,
      CallSheet(
        localParticipantId: 'senior',
        callerId: 'senior',
        calleeId: 'counterpart',
        peerPhone: '02-0000-1332',
        rtcSession: NoopRtcPeerSession(),
        chunkRecorder: NoopChunkRecorder(),
        onSwitchCall: ({required callerId, required calleeId, peerName, peerPhone}) async {
          switchedTarget = '$callerId->$calleeId';
        },
      ),
    );
    await settle(tester);

    final callId = family.state.data.activeCall!.id;
    await family.answerCall(callId);
    await settle(tester);

    await family.sendCallTranscript(callId, text: '금융감독원 적금 해지');
    await settle(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('fraud-help-button')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('fraud-help-button')));
    await settle(tester);
    await tester.tap(find.textContaining('보호자에게 전화'));
    await settle(tester);

    expect(switchedTarget, 'senior->guardian');
  });

  testWidgets('CallSheet shows 통화 종료 briefly and pops back when call ends', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = FakeFamilyRepository(demoSnapshotJson());
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
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => openCallSheet(
                  context,
                  localParticipantId: 'senior',
                  callerId: 'senior',
                  calleeId: 'counterpart',
                  peerPhone: '02-0000-1332',
                  peerName: '금융감독원 민원실(사칭)',
                  rtcSession: NoopRtcPeerSession(),
                  chunkRecorder: NoopChunkRecorder(),
                  endedAutoCloseDelay: const Duration(milliseconds: 500),
                ),
                child: const Text('통화 열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('통화 열기'));
    await settle(tester);
    expect(find.byType(CallSheet), findsOneWidget);

    await tester.tap(find.text('종료'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('통화 종료'), findsOneWidget);
    expect(find.byType(CallSheet), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    expect(find.byType(CallSheet), findsNothing);
    expect(find.text('통화 열기'), findsOneWidget);
  });
}
