import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:feature_call/feature_call.dart';
import 'package:feature_payment/feature_payment.dart';
import 'package:feature_sms/feature_sms.dart';
import 'package:feature_sos/feature_sos.dart';
import 'package:feature_transfer/feature_transfer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app_shell.dart';

/// 발표용 바로 시연 시나리오 (시안의 "바로 시연해 보기", 기획서 8절).
enum Scenario {
  phishingSms('사칭 문자 받기'),
  normalSms('정상 문자 받기'),
  counterpart('시연 상대 화면 열기'),
  shake('흔들어서 SOS 동결'),
  phishing('낯선 계좌로 50만원 송금'),
  game('등교 모드에서 게임 결제');

  final String label;
  const Scenario(this.label);
}

const phishingAccount = NewAccount(bank: '국민', number: '12345678907788', name: '이정민');

void _announceSms(ShellCubit shell, SmsMessage msg) {
  switch (msg.level) {
    case SmsRiskLevel.danger:
      shell.say(
        '위험 의심 문자가 도착했어요 · ${msg.explanation}',
        vibrate: const [80, 40, 80],
      );
    case SmsRiskLevel.caution:
      shell.say(
        '확인이 필요한 문자가 도착했어요 · ${msg.explanation}',
        vibrate: const [60],
      );
    case SmsRiskLevel.low:
      shell.say('${msg.displaySender} 문자가 도착했어요');
  }
}

Future<void> runScenario(BuildContext context, Scenario s) async {
  final shell = context.read<ShellCubit>();
  final family = context.read<FamilyCubit>();
  // 시트는 Navigator 아래의 context로 엽니다.
  BuildContext nav() => AppShell.navigatorKey.currentContext ?? context;

  try {
    switch (s) {
      case Scenario.phishingSms:
      case Scenario.normalSms:
        shell.goto(Persona.senior, AppTab.home);
        final kind = s == Scenario.phishingSms ? 'phishing' : 'normal';
        final res = await family.receiveSms('senior', kind: kind);
        _announceSms(shell, res.message);
        final ctx = nav();
        if (ctx.mounted) {
          await openSmsSheet(
            ctx,
            'senior',
            initialSenderPhone: res.message.senderPhone,
            onTapPhone: (phone) {
              Navigator.of(ctx).maybePop();
              openCallSheet(
                ctx,
                callerId: 'senior',
                calleeId: 'counterpart',
                peerPhone: phone,
              );
            },
          );
        }
      case Scenario.counterpart:
        final ctx = nav();
        if (ctx.mounted) {
          await openCounterpartSheet(ctx);
        }
      case Scenario.shake:
        shell.goto(Persona.senior, AppTab.home);
        if (family.state.data.member('senior').isFrozen) {
          shell.say('이미 동결되어 있어요 · 설정에서 처음 상태로 되돌려 보세요');
          return;
        }
        shell.playShake();
        await Future<void>.delayed(const Duration(milliseconds: 900));
        final ctx = nav();
        if (ctx.mounted) await triggerSos(ctx, 'senior', SosTrigger.shake, intensity: 2.8);
      case Scenario.phishing:
        shell.goto(Persona.senior, AppTab.home);
        const draft = TransferDraft(newAccount: phishingAccount, amount: 500000);
        final preview = await family.assessTransfer('senior', draft);
        final ctx = nav();
        if (ctx.mounted) {
          final g = family.state.snapshot?.guardian;
          await openTransferSheet(
            ctx,
            'senior',
            draft: draft,
            preview: preview,
            onCallGuardian: () => openCallSheet(
              ctx,
              callerId: 'senior',
              calleeId: 'guardian',
              peerName: g != null ? '보호자 ${g.name}' : '보호자',
              peerPhone: g?.phone,
            ),
          );
        }
      case Scenario.game:
        shell.goto(Persona.child, AppTab.home);
        if (family.state.data.member('child').mode != 'school') {
          await family.setMode('child', 'school', byGuardian: true);
        }
        final result = await family.pay('child', 'c-game');
        final ctx = nav();
        if (ctx.mounted) await openPaySheet(ctx, 'child', result: result);
    }
  } on ApiException catch (e) {
    shell.say(e.message);
  }
}
