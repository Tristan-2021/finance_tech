import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:feature_call/feature_call.dart';
import 'package:fingerbell_app/app_links.dart';
import 'package:fingerbell_app/call/call_app.dart';
import 'package:fingerbell_app/call/call_lookup.dart';
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
  double textScale = 1.0,
  Map<String, dynamic>? snapshot,
  Map<String, Object?>? prefs,
  Uri? initialLink,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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

Future<void> _tapDialDigits(WidgetTester tester, String digits) async {
  for (final ch in digits.split('')) {
    final keyId = switch (ch) {
      '*' => 'star',
      '#' => 'hash',
      _ => ch,
    };
    await tester.ensureVisible(find.byKey(ValueKey('dial-key-$keyId')));
    await tester.tap(find.byKey(ValueKey('dial-key-$keyId')));
    await tester.pump();
  }
}

void main() {
  group('resolveCallTargetByPhone pure lookup', () {
    test('resolves guardian phone, sms sender/body phones, and call script phones ignoring hyphens and spaces', () {
      final json = demoSnapshotJson(
        seniorSmsMessages: [
          scamSmsJson(
            id: 'sms-1',
            senderName: '서울중앙지검(사칭)',
            senderPhone: '02-0000-1301',
            body: '문의 02-0000-8899',
          )..['phones'] = ['02-0000-1301', '02-0000-8899'],
        ],
      );
      (json['guardian'] as Map<String, dynamic>)['phone'] = '010-1234-5678';
      final snapshot = FamilySnapshot.fromJson(json);

      final guardianTarget = resolveCallTargetByPhone(snapshot, '010 1234-5678');
      expect(guardianTarget?.peerId, 'guardian');
      expect(guardianTarget?.peerName, '보호자 김사랑');
      expect(guardianTarget?.peerPhone, '010-1234-5678');

      // 보호자 본인 역할에서는 본인 번호를 발신 대상으로 해석하지 않습니다.
      expect(
        resolveCallTargetByPhone(snapshot, '01012345678', localPersona: Persona.guardian),
        isNull,
      );

      final smsSenderTarget = resolveCallTargetByPhone(snapshot, '0200001301');
      expect(smsSenderTarget?.peerId, 'counterpart');
      expect(smsSenderTarget?.peerName, '서울중앙지검(사칭)');
      expect(smsSenderTarget?.peerPhone, '02-0000-1301');

      final smsBodyTarget = resolveCallTargetByPhone(snapshot, '02 0000 8899');
      expect(smsBodyTarget?.peerId, 'counterpart');
      expect(smsBodyTarget?.peerPhone, '02-0000-8899');

      final scriptTarget = resolveCallTargetByPhone(snapshot, '0200001332');
      expect(scriptTarget?.peerId, 'counterpart');
      expect(scriptTarget?.peerName, '금융감독원 민원실(사칭)');
      expect(scriptTarget?.peerPhone, '02-0000-1332');

      expect(resolveCallTargetByPhone(snapshot, '010-9999-9999'), isNull);
      expect(resolveCallTargetByPhone(snapshot, '  - '), isNull);

      // 마스킹된 시연 보호자 번호(010-••••-1024)를 *로 눌러도 보호자로 찾습니다.
      final maskedSnapshot = FamilySnapshot.fromJson(demoSnapshotJson());
      final maskedGuardian = resolveCallTargetByPhone(maskedSnapshot, '010****1024');
      expect(maskedGuardian?.peerId, 'guardian');
      expect(maskedGuardian?.peerPhone, '010-••••-1024');
    });

    test('formatDialPadNumber inserts Korean phone hyphens', () {
      expect(formatDialPadNumber('01012345678'), '010-1234-5678');
      expect(formatDialPadNumber('0200001332'), '02-0000-1332');
      expect(formatDialPadNumber('010****1024'), '010-****-1024');
      expect(formatDialPadNumber('15881234'), '1588-1234');
      expect(formatDialPadNumber('*123#'), '*123#');
    });
  });

  testWidgets('CallApp starts on keypad tab without FingerBell header/role and contacts tab shows role-based contacts', (tester) async {
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    final (repo, _, store) = await _pumpCallApp(tester);

    // 1. 첫 화면은 [키패드] 탭이며 탭 순서는 iOS처럼 [최근 기록] [연락처] [키패드]입니다.
    //    핑거벨 전화 머리글·역할 배지는 띄우지 않고, 번호가 없을 때는 지우기 버튼을 숨깁니다.
    expect(find.text('핑거벨 전화'), findsNothing);
    expect(find.text('어르신'), findsNothing);
    expect(find.text('최근 기록'), findsOneWidget);
    expect(find.text('연락처'), findsOneWidget);
    expect(find.text('키패드'), findsOneWidget);
    final recentX = tester.getTopLeft(find.text('최근 기록')).dx;
    final contactsX = tester.getTopLeft(find.text('연락처')).dx;
    final keypadX = tester.getTopLeft(find.text('키패드')).dx;
    expect(recentX, lessThan(contactsX));
    expect(contactsX, lessThan(keypadX));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('#'), findsOneWidget);
    expect(find.byKey(const ValueKey('dial-backspace-button')), findsNothing);

    // 2. [연락처] 탭으로 이동하면 어르신에게 보호자 연락처만 표시됩니다(핑거벨 안내 문구 없음).
    await tester.tap(find.text('연락처'));
    await _settle(tester);
    expect(find.text('보호자 김사랑 (딸)'), findsOneWidget);
    expect(find.text('010-••••-1024'), findsOneWidget);
    expect(find.textContaining('가족 안심 통화'), findsNothing);
    expect(find.textContaining('앱 안 통화'), findsNothing);

    // 3. 보호자 역할로 전환 뒤 resume 시 연락할 수 있는 가족(어머니, 아들) 목록 표시
    await store.saveString('persona', 'guardian');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);

    expect(find.text('어머니 김순자'), findsOneWidget);
    expect(find.text('아들 이민준'), findsOneWidget);
    expect(find.textContaining('가족 안심 통화'), findsNothing);

    await tester.tap(find.text('어머니 김순자'));
    await _settle(tester);
    expect(repo.calls, contains('startCall:guardian:senior:앱 안 통화'));
    expect(find.text('발신 중…'), findsOneWidget);
    expect(find.text('종료'), findsOneWidget);
  });

  testWidgets('CallApp keypad dials known number to outgoing screen and stays home on unknown number', (tester) async {
    final json = demoSnapshotJson();
    (json['guardian'] as Map<String, dynamic>)['phone'] = '010-1234-5678';
    final (repo, _, _) = await _pumpCallApp(tester, snapshot: json);

    expect(find.byKey(const ValueKey('dial-backspace-button')), findsNothing);

    // 1. 모르는 번호 입력 -> 통화 생성 안 됨 + 안내 문구 표시
    await _tapDialDigits(tester, '01099998888');
    expect(find.text('010-9999-8888'), findsOneWidget);
    expect(find.byKey(const ValueKey('dial-backspace-button')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('dial-call-button')));
    await tester.tap(find.byKey(const ValueKey('dial-call-button')));
    await _settle(tester);

    expect(find.text('지금 거신 번호는 없는 번호입니다'), findsOneWidget);
    expect(find.byType(CallSheet), findsNothing);
    expect(repo.calls.where((c) => c.startsWith('startCall:')), isEmpty);

    // 지우기(길게 누르기)로 입력을 비우면 안내 문구와 지우기 버튼이 사라집니다.
    await tester.longPress(find.byKey(const ValueKey('dial-backspace-button')));
    await tester.pump();
    expect(find.text('지금 거신 번호는 없는 번호입니다'), findsNothing);
    expect(find.byKey(const ValueKey('dial-backspace-button')), findsNothing);

    // 2. 보호자 번호 입력 -> 발신 화면으로 이동 → 끊고 나면 최근 기록에 남음
    await _tapDialDigits(tester, '01012345678');
    expect(find.text('010-1234-5678'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dial-call-button')));
    await _settle(tester);

    expect(repo.calls, contains('startCall:senior:guardian:010-1234-5678'));
    expect(find.byType(CallSheet), findsOneWidget);
    expect(find.text('보호자 김사랑'), findsOneWidget);
    expect(find.text('발신 중…'), findsOneWidget);
    expect(find.text('종료'), findsOneWidget);

    await tester.tap(find.text('종료'));
    await _settle(tester);
    expect(find.text('통화 종료'), findsOneWidget);

    // 잠시 보여 준 뒤 홈으로 돌아오고 최근 기록에 남습니다.
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);
    expect(find.byType(CallSheet), findsNothing);

    await tester.tap(find.text('최근 기록'));
    await _settle(tester);
    expect(find.text('보호자 김사랑'), findsOneWidget);
    expect(find.byIcon(Icons.phone_forwarded_rounded), findsOneWidget);
  });

  testWidgets('CallApp recent tab filters calls by current persona in reverse chronological order and redials on tap', (tester) async {
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
    final now = DateTime.utc(2026, 11, 17, 9, 0);
    final olderSeniorCall = {
      'id': 'call-old',
      'caller_id': 'senior',
      'callee_id': 'counterpart',
      'member_id': 'senior',
      'peer_name': '',
      'peer_phone': '02-0000-1332',
      'status': 'ended',
      'analyzed': true,
      'warning_level': 'low',
      'warning_reasons': <String>[],
      'warning_explanation': '',
      'created_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
      'ended_at': now.subtract(const Duration(hours: 1, minutes: 58)).toIso8601String(),
    };
    final guardianToChildCall = {
      'id': 'call-child',
      'caller_id': 'guardian',
      'callee_id': 'child',
      'member_id': 'child',
      'peer_name': '아들 이민준',
      'peer_phone': '앱 안 통화',
      'status': 'ended',
      'analyzed': false,
      'warning_level': 'low',
      'warning_reasons': <String>[],
      'warning_explanation': '',
      'created_at': now.subtract(const Duration(minutes: 30)).toIso8601String(),
      'answered_at': now.subtract(const Duration(minutes: 29)).toIso8601String(),
      'ended_at': now.subtract(const Duration(minutes: 25)).toIso8601String(),
    };
    final missedSeniorCall = {
      'id': 'call-missed',
      'caller_id': 'guardian',
      'callee_id': 'senior',
      'member_id': 'senior',
      'peer_name': '보호자 김사랑',
      'peer_phone': '010-••••-1024',
      'status': 'ended',
      'analyzed': false,
      'warning_level': 'low',
      'warning_reasons': <String>[],
      'warning_explanation': '',
      'created_at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
      'ended_at': now.subtract(const Duration(minutes: 4)).toIso8601String(),
    };

    final json = demoSnapshotJson(now: now);
    // 일부러 오래된 순으로 넣어 정렬 검증
    json['calls'] = [olderSeniorCall, guardianToChildCall, missedSeniorCall];

    final (repo, _, store) = await _pumpCallApp(tester, snapshot: json);

    await tester.tap(find.text('최근 기록'));
    await _settle(tester);

    // 어르신 역할에서는 본인 통화 2건만 보이고 아이 통화는 숨겨집니다.
    expect(find.text('아들 이민준'), findsNothing);
    expect(find.text('보호자 김사랑'), findsOneWidget);
    expect(find.text('부재중'), findsOneWidget);
    expect(find.text('02-0000-1332'), findsOneWidget);
    expect(find.byIcon(Icons.phone_forwarded_rounded), findsOneWidget);

    // 최신 통화(부재중)가 오래된 통화(02-0000-1332)보다 위에 배치됩니다.
    final newerY = tester.getTopLeft(find.text('보호자 김사랑')).dy;
    final olderY = tester.getTopLeft(find.text('02-0000-1332')).dy;
    expect(newerY, lessThan(olderY));

    // 아이 역할로 바꾸면 아이가 낀 통화(보호자 김사랑)만 보이고 어르신 통화는 숨겨집니다.
    await store.saveString('persona', 'child');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);
    expect(find.text('보호자 김사랑'), findsOneWidget);
    expect(find.text('02-0000-1332'), findsNothing);

    await store.saveString('persona', 'guardian');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);
    expect(find.text('아들 이민준'), findsOneWidget);
    expect(find.text('어머니 김순자'), findsOneWidget);
    expect(find.text('02-0000-1332'), findsNothing);

    // 기록을 누르면 그 상대에게 다시 겁니다.
    await tester.tap(find.text('아들 이민준'));
    await _settle(tester);
    expect(repo.calls, contains('startCall:guardian:child:앱 안 통화'));
    expect(find.text('발신 중…'), findsOneWidget);
  });

  testWidgets('CallApp recent tab shows empty message when persona has no calls', (tester) async {
    await _pumpCallApp(tester, snapshot: demoSnapshotJson());
    await tester.tap(find.text('최근 기록'));
    await _settle(tester);
    expect(find.text('최근 기록이 없어요'), findsOneWidget);
  });

  testWidgets('CallApp ignores invalid dial links and returns to keypad home', (tester) async {
    final (repo, _, _) = await _pumpCallApp(
      tester,
      initialLink: Uri.parse('fingerbell://call/dial?peer=unknown'),
    );

    expect(find.text('1'), findsOneWidget);
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

    expect(find.text('1'), findsOneWidget);
    expect(find.byType(CallSheet), findsNothing);
    expect(repo.calls.where((c) => c.startsWith('startCall:')), isEmpty);
  });

  testWidgets('CallApp dials counterpart from link, shows scam warning, and switches to guardian call full-screen', (tester) async {
    final (repo, family, _) = await _pumpCallApp(
      tester,
      initialLink: Uri.parse('fingerbell://call/dial?peer=counterpart&phone=02-0000-1332'),
    );

    expect(repo.calls, contains('startCall:senior:counterpart:02-0000-1332'));
    expect(find.text('발신 중…'), findsOneWidget);
    expect(find.text('금융감독원 민원실(사칭)'), findsOneWidget);
    expect(find.text('핑거벨 전화'), findsNothing);

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
    expect(find.text('통화 끊기'), findsOneWidget);

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
    expect(find.text('보호자 김사랑'), findsOneWidget);
    expect(find.text('가족 안심 통화 · 통화 내용을 분석하지 않아요'), findsNothing);
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

    // 2. 다시 화면에 뜨면(resume) 수신 화면이 뜨고 [받기]·[거절] 버튼으로 응답할 수 있습니다.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);
    expect(find.text('휴대전화'), findsOneWidget);
    expect(find.text('받기'), findsOneWidget);
    expect(find.text('거절'), findsOneWidget);
    await tester.tap(find.text('받기'));
    await _settle(tester);
    expect(repo.calls, contains('answerCall:${incoming.id}'));
    expect(find.text('00:00'), findsOneWidget);

    await tester.tap(find.text('종료'));
    await _settle(tester);
    expect(find.text('통화 종료'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);
    expect(find.byType(CallSheet), findsNothing);

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

  testWidgets('CallApp renders keypad, recent, contacts, and active call screen without overflow at 2.0x text scale', (tester) async {
    final now = DateTime.utc(2026, 11, 17, 9, 0);
    final json = demoSnapshotJson(now: now);
    json['calls'] = [
      {
        'id': 'call-large-1',
        'caller_id': 'senior',
        'callee_id': 'guardian',
        'member_id': 'senior',
        'peer_name': '보호자 김사랑',
        'peer_phone': '010-••••-1024',
        'status': 'ended',
        'analyzed': false,
        'warning_level': 'low',
        'warning_reasons': <String>[],
        'warning_explanation': '',
        'created_at': now.subtract(const Duration(minutes: 10)).toIso8601String(),
        'answered_at': now.subtract(const Duration(minutes: 9)).toIso8601String(),
        'ended_at': now.subtract(const Duration(minutes: 7)).toIso8601String(),
      },
    ];
    final (_, family, _) = await _pumpCallApp(
      tester,
      size: const Size(360, 780),
      textScale: 2.0,
      prefs: {'largeText': true},
      snapshot: json,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('키패드'), findsOneWidget);
    // 2.0x 큰 글씨에서도 하단 탭·키패드 버튼 최소 터치 영역(57dp)을 지킵니다.
    expect(tester.getSize(find.byKey(const ValueKey('call-tab-keypad'))).height, greaterThanOrEqualTo(57));
    expect(tester.getSize(find.byKey(const ValueKey('dial-key-1'))).height, greaterThanOrEqualTo(57));

    await tester.tap(find.text('최근 기록'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('보호자 김사랑'), findsOneWidget);

    await tester.tap(find.text('연락처'));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('보호자 김사랑 (딸)'));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    final callId = family.state.data.activeCall!.id;
    await family.answerCall(callId);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('스피커'), findsOneWidget);
    expect(find.text('소리 끔'), findsOneWidget);
    expect(find.text('종료'), findsOneWidget);
    expect(tester.getSize(find.text('종료')).height, greaterThan(0));
    expect(find.byType(CallSheet), findsOneWidget);
  });
}
