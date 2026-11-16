import 'package:core_family/core_family.dart';
import 'package:core_family/testing.dart';
import 'package:core_shell/core_shell.dart';
import 'package:fingerbell_app/app.dart';
import 'package:fingerbell_app/app_links.dart';
import 'package:fingerbell_app/shell/feedback_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('AppLinks link argument validation', () {
    final snapshot = FamilySnapshot.fromJson(demoSnapshotJson());

    test('parsePhoneArg accepts valid phone numbers and rejects malformed values', () {
      expect(AppLinks.parsePhoneArg('02-0000-1332'), '02-0000-1332');
      expect(AppLinks.parsePhoneArg(' 010-0000-1024 '), '010-0000-1024');
      expect(AppLinks.parsePhoneArg('010-••••-1024'), '010-••••-1024');
      expect(AppLinks.parsePhoneArg('1588-1234'), '1588-1234');
      expect(AppLinks.parsePhoneArg('01012345678'), '01012345678');

      expect(AppLinks.parsePhoneArg(''), isNull);
      expect(AppLinks.parsePhoneArg('abc'), isNull);
      expect(AppLinks.parsePhoneArg('12345'), isNull);
      expect(AppLinks.parsePhoneArg('02-12-34'), isNull);
      expect(AppLinks.parsePhoneArg('02-0000-1332;evil'), isNull);
      expect(AppLinks.parsePhoneArg('tel:02-0000-1332'), isNull);
    });

    test('parseSmsLink ignores malformed phones and unknown paths', () {
      expect(AppLinks.parseSmsLink(Uri.parse('https://example.com/sms')), isNull);
      expect(AppLinks.parseSmsLink(Uri.parse('fingerbell://call/dial?peer=guardian')), isNull);

      final home = AppLinks.parseSmsLink(Uri.parse('fingerbell://sms'));
      expect(home?.kind, SmsLinkKind.home);

      final badPhone = AppLinks.parseSmsLink(Uri.parse('fingerbell://sms/conversation?phone=not-a-phone'));
      expect(badPhone?.kind, SmsLinkKind.home);

      final badPath = AppLinks.parseSmsLink(Uri.parse('fingerbell://sms/unknown?phone=02-0000-1332'));
      expect(badPath?.kind, SmsLinkKind.home);

      final valid = AppLinks.parseSmsLink(Uri.parse('fingerbell://sms/conversation?phone=02-0000-1332'));
      expect(valid?.kind, SmsLinkKind.conversation);
      expect(valid?.senderPhone, '02-0000-1332');
    });

    test('parseCallLink rejects unknown peers, self-calls, malformed phones, and bad call ids', () {
      expect(AppLinks.parseCallLink(Uri.parse('fingerbell://sms'), localPersona: Persona.senior), isNull);

      // 모르는 상대 id
      expect(
        AppLinks.parseCallLink(Uri.parse('fingerbell://call/dial?peer=stranger'), localPersona: Persona.senior, snapshot: snapshot)?.kind,
        CallLinkKind.home,
      );
      // 자기 자신 호출 금지
      expect(
        AppLinks.parseCallLink(Uri.parse('fingerbell://call/dial?peer=senior'), localPersona: Persona.senior, snapshot: snapshot)?.kind,
        CallLinkKind.home,
      );
      expect(
        AppLinks.parseCallLink(Uri.parse('fingerbell://call/dial?peer=guardian'), localPersona: Persona.guardian, snapshot: snapshot)?.kind,
        CallLinkKind.home,
      );
      // 어르신/아이 역할에서 보호자 외 가족 직접 호출 금지
      expect(
        AppLinks.parseCallLink(Uri.parse('fingerbell://call/dial?peer=child'), localPersona: Persona.senior, snapshot: snapshot)?.kind,
        CallLinkKind.home,
      );
      // 시연 상대 발신에 번호 누락 또는 잘못된 번호 형식
      expect(
        AppLinks.parseCallLink(Uri.parse('fingerbell://call/dial?peer=counterpart'), localPersona: Persona.senior, snapshot: snapshot)?.kind,
        CallLinkKind.home,
      );
      expect(
        AppLinks.parseCallLink(Uri.parse('fingerbell://call/dial?peer=counterpart&phone=bad'), localPersona: Persona.senior, snapshot: snapshot)?.kind,
        CallLinkKind.home,
      );
      // 보호자 발신에 잘못된 번호·이름 인자 포함 시 무시
      expect(
        AppLinks.parseCallLink(Uri.parse('fingerbell://call/dial?peer=guardian&phone=abc'), localPersona: Persona.senior, snapshot: snapshot)?.kind,
        CallLinkKind.home,
      );
      expect(
        AppLinks.parseCallLink(Uri.parse('fingerbell://call/dial?peer=guardian&name=%3Cscript%3E'), localPersona: Persona.senior, snapshot: snapshot)?.kind,
        CallLinkKind.home,
      );
      // 잘못된 incoming callId
      expect(
        AppLinks.parseCallLink(Uri.parse('fingerbell://call/incoming?callId=bad%20id!'), localPersona: Persona.senior, snapshot: snapshot)?.kind,
        CallLinkKind.home,
      );

      // 정상 링크들
      final toGuardian = AppLinks.parseCallLink(
        Uri.parse('fingerbell://call/dial?peer=guardian'),
        localPersona: Persona.senior,
        snapshot: snapshot,
      );
      expect(toGuardian?.kind, CallLinkKind.dial);
      expect(toGuardian?.peerId, 'guardian');

      final toSenior = AppLinks.parseCallLink(
        Uri.parse('fingerbell://call/dial?peer=senior'),
        localPersona: Persona.guardian,
        snapshot: snapshot,
      );
      expect(toSenior?.kind, CallLinkKind.dial);
      expect(toSenior?.peerId, 'senior');

      final toCounterpart = AppLinks.parseCallLink(
        Uri.parse('fingerbell://call/dial?peer=counterpart&phone=02-0000-1332'),
        localPersona: Persona.senior,
        snapshot: snapshot,
      );
      expect(toCounterpart?.kind, CallLinkKind.dial);
      expect(toCounterpart?.peerId, 'counterpart');
      expect(toCounterpart?.phone, '02-0000-1332');

      final counterpartScreen = AppLinks.parseCallLink(
        Uri.parse('fingerbell://call/counterpart'),
        localPersona: Persona.senior,
        snapshot: snapshot,
      );
      expect(counterpartScreen?.kind, CallLinkKind.counterpart);

      // 잘못된 UTF-8 퍼센트 인코딩(%FF 등)이 들어와도 예외 없이 홈으로 떨어져야 합니다.
      for (final raw in [
        'fingerbell://call/dial?peer=%FF',
        'fingerbell://call/dial?peer=guardian&phone=%FF',
        'fingerbell://call/dial?peer=guardian&name=%FF',
        'fingerbell://call/incoming?callId=%FF',
        'fingerbell://call/home?q=%ZZ',
      ]) {
        final link = AppLinks.parseCallLink(Uri.parse(raw), localPersona: Persona.senior, snapshot: snapshot);
        expect(link?.kind, CallLinkKind.home, reason: raw);
      }
      for (final raw in [
        'fingerbell://sms/conversation?phone=%FF',
        'fingerbell://sms?q=%FF',
      ]) {
        final link = AppLinks.parseSmsLink(Uri.parse(raw));
        expect(link?.kind, SmsLinkKind.home, reason: raw);
      }

      // 키가 있는데 빈 값 또는 공백만 있는 경우 검증 실패로 홈을 반환해야 합니다.
      for (final raw in [
        'fingerbell://call/dial?peer=guardian&phone=',
        'fingerbell://call/dial?peer=guardian&name=',
        'fingerbell://call/dial?peer=guardian&phone=%20%20',
        'fingerbell://call/dial?peer=guardian&name=%20%20',
        'fingerbell://call/dial?peer=counterpart&phone=',
        'fingerbell://call/dial?peer=counterpart&phone=%20%20',
        'fingerbell://call/incoming?callId=',
        'fingerbell://call/incoming?callId=%20%20',
      ]) {
        final link = AppLinks.parseCallLink(Uri.parse(raw), localPersona: Persona.senior, snapshot: snapshot);
        expect(link?.kind, CallLinkKind.home, reason: raw);
      }
      for (final raw in [
        'fingerbell://sms/conversation?phone=',
        'fingerbell://sms/conversation?phone=%20%20',
      ]) {
        final link = AppLinks.parseSmsLink(Uri.parse(raw));
        expect(link?.kind, SmsLinkKind.home, reason: raw);
      }
    });
  });

  testWidgets('FingerBell entry points open expected app links and show friendly message when target app is missing', (tester) async {
    tester.view.physicalSize = const Size(420, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final opened = <Uri>[];
    var missingApp = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      AppLinks.channel,
      (call) async {
        if (call.method == 'open') {
          if (missingApp) {
            throw PlatformException(code: 'app_missing', message: '앱을 함께 설치해 주세요');
          }
          final raw = (call.arguments as Map?)?['uri'] as String?;
          if (raw != null) opened.add(Uri.parse(raw));
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

    final repo = FakeFamilyRepository(demoSnapshotJson(seniorFrozen: true));
    final family = FamilyCubit(repo, pollInterval: null);
    await family.start();
    final shell = ShellCubit();
    addTearDown(family.close);
    addTearDown(shell.close);

    final messages = <String>[];
    final sub = shell.feedback.listen((f) => messages.add(f.message));
    addTearDown(sub.cancel);

    await tester.pumpWidget(
      FingerBellApp(
        family: family,
        shell: shell,
        feedback: const SilentFeedback(),
        serverAddress: 'http://127.0.0.1:8765',
      ),
    );
    await _settle(tester);

    // 1. 일반 홈의 [문자] 카드
    await tester.ensureVisible(find.text('문자'));
    await tester.pump();
    await tester.tap(find.text('문자'));
    await _settle(tester);
    expect(opened.last, Uri.parse('fingerbell://sms'));

    // 2. 안심 탭의 보호자 카드 [전화]
    shell.switchTab(AppTab.safety);
    await _settle(tester);
    await tester.ensureVisible(find.text('전화'));
    await tester.pump();
    await tester.tap(find.text('전화'));
    await _settle(tester);
    expect(opened.last, Uri.parse('fingerbell://call/dial?peer=guardian'));
    shell.switchTab(AppTab.home);
    await _settle(tester);

    // 3. 계좌 조회 -> 적금 만기 전 해지 -> [보호자에게 물어보기]
    await tester.ensureVisible(find.text('조회'));
    await tester.pump();
    await tester.tap(find.text('조회'));
    await _settle(tester);
    await tester.ensureVisible(find.text('만기 전 해지'));
    await tester.pump();
    await tester.tap(find.text('만기 전 해지'));
    await _settle(tester);
    await tester.ensureVisible(find.text('보호자에게 물어보기'));
    await tester.pump();
    await tester.tap(find.text('보호자에게 물어보기'));
    await _settle(tester);
    expect(opened.last, Uri.parse('fingerbell://call/dial?peer=guardian'));
    await tester.tap(find.byTooltip('닫기').last);
    await _settle(tester);

    // 4. SOS 완료 화면 -> [보호자에게 전화하기]
    shell.showSos('senior');
    await _settle(tester);
    await tester.ensureVisible(find.text('보호자에게 전화하기'));
    await tester.pump();
    await tester.tap(find.text('보호자에게 전화하기'));
    await _settle(tester);
    expect(opened.last, Uri.parse('fingerbell://call/dial?peer=guardian'));

    // 5. 대상 앱이 설치되어 있지 않아 열기에 실패하면 쉬운 말 한 줄 안내를 보여 줍니다.
    missingApp = true;
    await tester.ensureVisible(find.text('문자'));
    await tester.pump();
    await tester.tap(find.text('문자'));
    await _settle(tester);
    expect(messages.last, '핑거벨 문자 앱이 설치되어 있지 않아 열 수 없어요');

    shell.switchTab(AppTab.safety);
    await _settle(tester);
    await tester.ensureVisible(find.text('전화'));
    await tester.pump();
    await tester.tap(find.text('전화'));
    await _settle(tester);
    expect(messages.last, '핑거벨 전화 앱이 설치되어 있지 않아 열 수 없어요');
  });
}
