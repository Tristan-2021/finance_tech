import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_call/feature_call.dart';
import 'package:feature_payment/feature_payment.dart';
import 'package:feature_sms/feature_sms.dart';
import 'package:feature_sos/feature_sos.dart';
import 'package:feature_transfer/feature_transfer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'banking_sheets.dart';

/// 본인 홈에 보이는 주의 모드 카드 (기획서 5.1: 상태와 남은 시간 표시, 본인은 끌 수 없음).
class CautionModeCard extends StatelessWidget {
  final Member member;
  final DateTime Function() now;

  const CautionModeCard({super.key, required this.member, required this.now});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return FbCard(
      color: c.redSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(FbIcons.alert, size: 19, color: c.redStrong),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '주의 모드 작동 중',
                  style: TextStyle(fontSize: 16.4, fontWeight: FontWeight.w800, color: c.redStrong),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '사기 의심 징후가 감지되어 24시간 동안 금융 행동을 보호해요.',
            style: TextStyle(fontSize: 13.6, height: 1.5, color: c.ink2),
          ),
          if (member.cautionUntil != null) ...[
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('남은 시간 ', style: TextStyle(fontSize: 13.6, color: c.ink2)),
                CountdownText(
                  until: member.cautionUntil!,
                  now: now,
                  style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w800, color: c.ink2),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 본인 홈에 보이는 거래 보류 / 본인 재확인 대기 카드 (기획서 5.7).
class MemberHoldCard extends StatefulWidget {
  final ApprovalRequest request;
  final Member member;
  final DateTime Function() now;

  const MemberHoldCard({super.key, required this.request, required this.member, required this.now});

  @override
  State<MemberHoldCard> createState() => _MemberHoldCardState();
}

class _MemberHoldCardState extends State<MemberHoldCard> {
  String? _busy; // 'cancel' / 'proceed' / 'stop'

  Future<void> _cancel() async {
    setState(() => _busy = 'cancel');
    final shell = context.read<ShellCubit>();
    try {
      await context.read<FamilyCubit>().cancelRequest(widget.request.id, widget.member.id);
      shell.say('보류 중인 거래를 취소했어요');
    } on ApiException catch (e) {
      shell.say(e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _reconfirm(bool confirm) async {
    setState(() => _busy = confirm ? 'proceed' : 'stop');
    final shell = context.read<ShellCubit>();
    try {
      final r = await context.read<FamilyCubit>().reconfirmHold(widget.request.id, widget.member.id, confirm: confirm);
      if (r.status == 'failed') {
        final reason = r.message.isNotEmpty ? r.message : (r.request?.failReason ?? '돈은 나가지 않았어요.');
        shell.say('처리하지 못했어요 · $reason', vibrate: const [80, 40, 80]);
      } else {
        shell.say(confirm ? '재확인 후 거래를 진행했어요' : '거래를 그만두었어요');
      }
    } on ApiException catch (e) {
      shell.say(e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final r = widget.request;
    final reconfirm = r.isReconfirm && !widget.member.isChild;
    return FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(reconfirm ? FbIcons.alert : FbIcons.clock, size: 18, color: c.redStrong),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reconfirm ? '본인 재확인 대기' : '거래 보류 중',
                  style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w800, color: c.redStrong),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${r.title} · ${won(r.amount)}', style: FbText.rowTitle(c)),
          const SizedBox(height: 4),
          Text(r.easyExplanation, style: TextStyle(fontSize: 13.6, height: 1.55, color: c.ink2)),
          if (!reconfirm && r.expiresAt != null) ...[
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('남은 시간 ', style: FbText.small(c)),
                CountdownText(
                  until: r.expiresAt!,
                  now: widget.now,
                  format: formatMinSec,
                  style: FbText.small(c).copyWith(fontWeight: FontWeight.w800, color: c.ink2),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (reconfirm) ...[
            FbButtonRow(
              children: [
                FbButton.gray('그만두기', busy: _busy == 'stop', onPressed: _busy == null ? () => _reconfirm(false) : null),
                FbButton.gray('그래도 진행', busy: _busy == 'proceed', onPressed: _busy == null ? () => _reconfirm(true) : null),
              ],
            ),
            const SizedBox(height: 8),
            FbButton.gray(
              '보호자에게 전화',
              icon: FbIcons.phone,
              onPressed: _busy == null
                  ? () => openCallSheet(
                        context,
                        callerId: widget.member.id,
                        calleeId: 'guardian',
                        peerName: '보호자',
                      )
                  : null,
            ),
            const SizedBox(height: 8),
            FraudHelpButton(
              onCallGuardian: _busy == null
                  ? () => openCallSheet(
                        context,
                        callerId: widget.member.id,
                        calleeId: 'guardian',
                        peerName: '보호자',
                      )
                  : null,
            ),
          ] else ...[
            FbButton.gray('취소', busy: _busy == 'cancel', onPressed: _busy == null ? _cancel : null),
            const SizedBox(height: 8),
            FraudHelpButton(
              onCallGuardian: _busy == null
                  ? () => openCallSheet(
                        context,
                        callerId: widget.member.id,
                        calleeId: 'guardian',
                        peerName: '보호자',
                      )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// 내 계좌: 잔액과 [송금] [결제] [조회]. 어르신·아이·보호자 모두 같은 은행 기능을 씁니다.
/// 아이는 결제를 앞에 두고, [extra](오늘 쓴 돈 등)를 잔액 아래에 붙입니다.
class AccountCard extends StatelessWidget {
  final Member member;
  final String? title;
  final Widget? extra;

  const AccountCard({super.key, required this.member, this.title, this.extra});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final m = member;
    void send() => openTransferSheet(
      context,
      m.id,
      onCallGuardian: () {
        final g = context.read<FamilyCubit>().state.snapshot?.guardian;
        openCallSheet(
          context,
          callerId: m.id,
          calleeId: 'guardian',
          peerName: g != null ? '보호자 ${g.name}' : '보호자',
          peerPhone: g?.phone,
        );
      },
    );
    void pay() => openPaySheet(context, m.id);
    void history() => context.read<ShellCubit>().switchTab(AppTab.history);
    void accounts() => openAccountsSheet(context, m.id);
    final buttons = m.isChild
        ? [FbButton('결제', onPressed: pay), FbButton.gray('보내기', onPressed: send), FbButton.gray('내역', onPressed: history)]
        : [
            FbButton('송금', onPressed: send),
            FbButton.gray('결제', onPressed: pay),
            FbButton.gray(m.isGuardian ? '내역' : '조회', onPressed: m.isGuardian ? history : accounts),
          ];
    return FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title ?? m.account.name, style: FbText.label(c)),
          BalanceLine(m.balance),
          ?extra,
          FbButtonRow(children: buttons),
        ],
      ),
    );
  }
}

/// 거래 내역 한 줄. 보호 조치(동결·차단·거절)는 방패 아이콘과 태그로 보여 줍니다.
class LedgerRow extends StatelessWidget {
  final LedgerEntry entry;
  final DateTime now;

  const LedgerRow({super.key, required this.entry, required this.now});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final t = entry;
    if (t.isProtect) {
      return FbListRow(
        leading: TxLogo(icon: t.tag == '해제' ? FbIcons.unlock : FbIcons.shield),
        title: Text(t.title),
        subtitle: '${formatWhen(t.at, now)} · ${t.desc}',
        trailing: Text(t.tag ?? '보호', style: FbText.note(c).copyWith(color: t.isDanger ? c.redStrong : c.muted)),
      );
    }
    final incoming = t.amount > 0;
    return FbListRow(
      leading: TxLogo.initial(t.title),
      title: Text(t.title),
      subtitle: '${incoming ? '입금' : '출금'} · ${formatWhen(t.at, now)}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              incoming ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 16,
              color: incoming ? c.blueStrong : c.ink2,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${incoming ? '+' : '-'}${won(t.amount.abs())}',
            style: FbText.amount(c).copyWith(color: incoming ? c.blueStrong : c.ink),
          ),
        ],
      ),
    );
  }
}

/// 잔액 + 눈 모양 버튼 (잔액 숨기기). 아이콘만 두지 않고 글자를 함께 붙입니다.
class BalanceLine extends StatelessWidget {
  final int balance;
  const BalanceLine(this.balance, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final hidden = context.select((ShellCubit s) => s.state.prefs.hideBalance);
    void toggleHide() => context.read<ShellCubit>().togglePref(PrefKey.hideBalance);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 7.2, 0, 20),
      child: Row(
        children: [
          Flexible(
            child: Semantics(
              label: hidden ? '잔액 숨김' : '잔액 ${won(balance)}',
              excludeSemantics: true,
              child: Text(wonOrHidden(balance, hidden: hidden), style: FbText.balance(c)),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: hidden ? '잔액 보기' : '잔액 숨기기',
            child: Semantics(
              button: true,
              label: hidden ? '잔액 보기' : '잔액 숨기기',
              onTap: toggleHide,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: toggleHide,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 57, minHeight: 57),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(hidden ? FbIcons.eyeOff : FbIcons.eye, color: c.ink2, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          hidden ? '보기' : '숨김',
                          style: TextStyle(fontSize: 12.6, fontWeight: FontWeight.w700, color: c.ink2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 최근 거래 3건.
class RecentCard extends StatelessWidget {
  final Member member;
  const RecentCard({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final now = context.read<FamilyCubit>().now();
    return FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListHead('최근 거래', action: '전체보기', onAction: () => context.read<ShellCubit>().switchTab(AppTab.history)),
          for (final t in member.ledger.take(3)) LedgerRow(entry: t, now: now),
          if (member.ledger.isEmpty) const EmptyText('아직 거래가 없어요'),
        ],
      ),
    );
  }
}

/// 보호자 카드: 누가 확인하는지와 전화 버튼.
class GuardianCard extends StatelessWidget {
  final Member member;
  final FamilySnapshot data;

  const GuardianCard({super.key, required this.member, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final g = data.guardian;
    void callGuardian() => openCallSheet(
      context,
      callerId: member.id,
      calleeId: 'guardian',
      peerName: '보호자 ${g.name}',
      peerPhone: g.phone,
    );
    return FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle('보호자'),
          FbListRow(
            padding: const EdgeInsets.only(top: 8),
            leading: TxLogo.initial(g.name, blue: true),
            title: Text('${g.name} (${member.guardianRelation})'),
            subtitle: '처음 보내는 계좌나 ${won(member.approvalThreshold)} 이상은 보호자 확인 후 진행돼요',
            trailing: Tooltip(
              message: '보호자에게 전화',
              child: Material(
                color: c.blueSoft,
                borderRadius: BorderRadius.circular(14),
                child: Semantics(
                  button: true,
                  label: '보호자에게 전화',
                  onTap: callGuardian,
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: callGuardian,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 57, minHeight: 57),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FbIcons.phone, color: c.blueStrong, size: 18),
                            const SizedBox(width: 4),
                            Text('전화', style: TextStyle(fontSize: 13.2, fontWeight: FontWeight.w800, color: c.blueStrong)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// SOS 버튼, 또는 동결 중이면 동결 카드.
class SosSlot extends StatelessWidget {
  final Member member;
  final FamilySnapshot data;
  final bool inCard;

  const SosSlot({super.key, required this.member, required this.data, this.inCard = false});

  @override
  Widget build(BuildContext context) {
    if (member.isFrozen) {
      return FrozenCard(
        member: member,
        now: context.read<FamilyCubit>().now,
        waitingForGuardian: data.hasPending(member.id, 'unfreeze'),
        onRequestUnfreeze: () => requestUnfreeze(context, member.id),
      );
    }
    final shell = context.read<ShellCubit>();
    Future<void> confirmTapFreeze() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final c = ctx.fb;
          return AlertDialog(
            icon: ExcludeSemantics(child: Icon(FbIcons.lock, color: c.redStrong, size: 30)),
            title: Text('모든 계좌를 동결할까요?', style: TextStyle(fontWeight: FontWeight.w800, color: c.redStrong)),
            content: Text(
              '확인하시면 모든 계좌 출금이 24시간 멈추고, 보호자께 바로 알립니다.',
              style: TextStyle(height: 1.55, color: c.ink),
            ),
            actions: [
              SizedBox(
                width: double.maxFinite,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FbButton('모든 계좌 동결', variant: FbButtonVariant.red, onPressed: () => Navigator.of(ctx).pop(true)),
                    const SizedBox(height: 8),
                    FbButton.gray('취소', onPressed: () => Navigator.of(ctx).pop(false)),
                  ],
                ),
              ),
            ],
          );
        },
      );
      if (ok == true && context.mounted) {
        await triggerSos(context, member.id, SosTrigger.longPress);
      }
    }

    final button = SosHoldButton(
      onTap: confirmTapFreeze,
      onStart: () => shell.say('', toast: false, vibrate: const [30], speak: false),
      onCancel: (_) => shell.say('조금 더 길게 눌러 주세요 (2초)', speak: false, vibrate: const []),
      onComplete: () => triggerSos(context, member.id, SosTrigger.longPress),
    );
    if (!inCard) return button;
    return FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle('SOS 계좌 동결', desc: 'SOS 계좌 동결 버튼을 누르거나 길게 누르고, 또는 휴대폰을 3초 동안 세게 흔들면 모든 계좌 출금이 24시간 멈추고 보호자에게 바로 알려요.'),
          button,
        ],
      ),
    );
  }
}

/// 어르신 홈에서 한 번에 들어가는 문자 진입점 (기획서 5.2, 7.1).
class SmsEntryCard extends StatelessWidget {
  final Member member;
  const SmsEntryCard({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    final dangerCount = member.dangerSmsCount;
    final total = member.smsMessages.length;
    final sub = dangerCount > 0
        ? '사기 의심 경고 $dangerCount건 · 눌러서 확인하세요'
        : '받은 문자 $total건 · 사기 문자를 자동으로 살펴봐요';
    return FbRowLink(
      leading: TxLogo(icon: dangerCount > 0 ? FbIcons.alert : FbIcons.sms, blue: dangerCount == 0),
      title: '문자',
      subtitle: sub,
      onTap: () {
        final g = context.read<FamilyCubit>().state.snapshot?.guardian;
        openSmsSheet(
          context,
          member.id,
          onTapPhone: (phone) {
            Navigator.of(context).maybePop();
            openCallSheet(
              context,
              callerId: member.id,
              calleeId: 'counterpart',
              peerPhone: phone,
            );
          },
          onCallGuardian: () => openCallSheet(
            context,
            callerId: member.id,
            calleeId: 'guardian',
            peerName: g != null ? '보호자 ${g.name}' : '보호자',
            peerPhone: g?.phone,
          ),
        );
      },
    );
  }
}
