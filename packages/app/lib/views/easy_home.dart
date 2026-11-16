import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app_links.dart';
import 'member_widgets.dart';

/// 홈 상단에 놓는 쉬운 화면 토글 (메인 화면에서 1터치로 켜고 끕니다: 기획서 7.1 Ⅰ-②, Ⅰ-③).
class EasyModeTopBar extends StatelessWidget {
  const EasyModeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final easyMode = context.select((ShellCubit s) => s.state.prefs.easyMode);
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const ValueKey('easy-mode-top-toggle'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.read<ShellCubit>().setEasyMode(!easyMode),
        child: Container(
          constraints: const BoxConstraints(minHeight: 57),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: c.cardBorder != null ? Border.all(color: c.cardBorder!, width: 2) : null,
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.accessibility_new_rounded,
                  size: 21,
                  color: easyMode ? c.blueStrong : c.ink2,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '쉬운 화면',
                      style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w800, color: c.ink),
                    ),
                    Text(
                      easyMode ? '큰 버튼으로 꼭 필요한 메뉴만 보여요' : '누르면 쉬운 화면으로 바뀌어요',
                      style: FbText.small(c),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FbToggle(
                value: easyMode,
                label: '쉬운 화면',
                onChanged: (v) => context.read<ShellCubit>().setEasyMode(v),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 어르신에게 처음 실행 때 한 번 묻는 쉬운 화면 안내 카드 (기획서 7.1 Ⅰ-③).
class EasyModePromptCard extends StatelessWidget {
  const EasyModePromptCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final shell = context.read<ShellCubit>();
    return Semantics(
      liveRegion: true,
      child: FbCard(
        key: const ValueKey('easy-mode-prompt-card'),
        color: c.blueSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(child: Icon(FbIcons.sparkle, size: 20, color: c.blueStrong)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '쉬운 화면으로 볼까요?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.blueStrong),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '큰 버튼과 꼭 필요한 메뉴만 한눈에 모아 보여 드려요. 위쪽 스위치로 언제든 바꿀 수 있어요.',
              style: TextStyle(fontSize: 13.8, height: 1.5, color: c.ink2),
            ),
            const SizedBox(height: 14),
            FbButtonRow(
              children: [
                FbButton.gray('일반 화면 유지', onPressed: () => shell.answerEasyModePrompt(false)),
                FbButton('쉬운 화면 켜기', onPressed: () => shell.answerEasyModePrompt(true)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 쉬운 화면 홈 (어르신·아이): 스크롤 없이 한눈에 보이는 큰 버튼 중심 구성 (기획서 5.10, 7.1).
/// - 기존 버튼 [송금] [결제] [조회] [SOS]의 위치와 이름을 유지합니다.
/// - 문자와 전화는 홈에서 한 번에 들어갑니다.
/// - 대출은 쉬운 화면 홈에 내놓지 않습니다.
class EasyMemberHome extends StatelessWidget {
  final Member member;
  final FamilySnapshot data;

  const EasyMemberHome({super.key, required this.member, required this.data});

  @override
  Widget build(BuildContext context) {
    final g = data.guardian;
    final shell = context.read<ShellCubit>();
    void callGuardian() => AppLinks.openCall(shell, peer: 'guardian');
    void openSms() => AppLinks.openSms(shell);

    final holds = [
      for (final r in data.pending(member.id))
        if (r.isHold) r,
    ];
    final hasStatus = member.cautionMode || holds.isNotEmpty;

    return FbView(
      children: [
        Greeting(member.isChild ? '안녕, ${member.callName}!' : '안녕하세요, ${member.name}님'),
        if (hasStatus)
          _EasyStatusStrip(
            member: member,
            holds: holds,
            onTap: () => _openEasyStatusSheet(context, member.id),
          ),
        AccountCard(member: member),
        SosSlot(member: member, data: data),
        FbButtonRow(
          children: [
            FbButton.gray('문자', icon: FbIcons.sms, onPressed: openSms),
            FbButton.gray('전화', icon: FbIcons.phone, onPressed: callGuardian),
          ],
        ),
        FraudHelpButton(onCallGuardian: callGuardian, guardianName: g.name),
      ],
    );
  }
}

/// 쉬운 화면 홈의 주의 모드·보류 한 줄 요약. 누르면 상세 시트로 이동합니다 (기획서 7.1 Ⅱ-⑥).
class _EasyStatusStrip extends StatelessWidget {
  final Member member;
  final List<ApprovalRequest> holds;
  final VoidCallback onTap;

  const _EasyStatusStrip({required this.member, required this.holds, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final reconfirms = holds.where((r) => r.isReconfirm && !member.isChild).length;
    final otherHolds = holds.length - reconfirms;
    final parts = <String>[
      if (member.cautionMode) '주의 모드',
      if (reconfirms > 0) reconfirms == 1 ? '본인 재확인 대기' : '본인 재확인 대기 $reconfirms건',
      if (otherHolds > 0) '보류 $otherHolds건',
    ];
    final summary = parts.join(' · ');
    final actionLabel = reconfirms > 0 ? '확인하기' : '상세 보기';
    return Material(
      color: c.redSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const ValueKey('easy-status-summary'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 57),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.redStrong, width: 1.5),
          ),
          child: Row(
            children: [
              ExcludeSemantics(child: Icon(FbIcons.alert, size: 20, color: c.redStrong)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  summary,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.redStrong),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                actionLabel,
                style: TextStyle(fontSize: 13.4, fontWeight: FontWeight.w800, color: c.ink),
              ),
              const SizedBox(width: 2),
              ExcludeSemantics(child: Icon(FbIcons.chevron, size: 18, color: c.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openEasyStatusSheet(BuildContext context, String memberId) => showFbSheet<void>(
  context,
  builder: (_) => BlocBuilder<FamilyCubit, FamilyState>(
    builder: (context, state) {
      if (!state.isReady) {
        return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
      }
      final now = context.read<FamilyCubit>().now;
      final m = state.data.memberOrNull(memberId);
      if (m == null) return const EmptyText('사용자를 찾을 수 없어요');
      final holds = [
        for (final r in state.data.pending(m.id))
          if (r.isHold) r,
      ]..sort((a, b) {
          final ar = (a.isReconfirm && !m.isChild) ? 0 : 1;
          final br = (b.isReconfirm && !m.isChild) ? 0 : 1;
          return ar.compareTo(br);
        });
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHead(title: '보호 상태 확인'),
          if (!m.cautionMode && holds.isEmpty) ...[
            const EmptyText('지금은 주의 모드나 보류된 거래가 없어요'),
            const SizedBox(height: 8),
            FbButton('확인', onPressed: () => Navigator.of(context).maybePop()),
          ] else ...[
            for (final r in holds) ...[
              MemberHoldCard(key: ValueKey('hold-${r.id}'), request: r, member: m, now: now),
              const SizedBox(height: 12),
            ],
            if (m.cautionMode) CautionModeCard(member: m, now: now),
          ],
        ],
      );
    },
  ),
);

/// 쉬운 화면 홈 (보호자): 내 계좌 큰 버튼, 확인할 요청 바로가기, 가족 전화, 사기 신고·도움.
class EasyGuardianHome extends StatelessWidget {
  final FamilySnapshot data;
  final ValueChanged<Member> onCallMember;

  const EasyGuardianHome({super.key, required this.data, required this.onCallMember});

  @override
  Widget build(BuildContext context) {
    final me = data.guardian.banking;
    final pending = data.pending();
    return FbView(
      children: [
        Greeting(
          pending.isEmpty ? '가족 모두 안전해요' : '확인할 요청이 ${pending.length}건 있어요',
          sub: '${data.guardian.name}님',
        ),
        if (me != null) AccountCard(member: me),
        if (pending.isNotEmpty)
          FbButton(
            '확인할 요청 ${pending.length}건 보기',
            icon: FbIcons.alert,
            variant: FbButtonVariant.red,
            onPressed: () => context.read<ShellCubit>().switchTab(AppTab.alerts),
          ),
        if (data.members.isNotEmpty)
          FbButtonRow(
            children: [
              for (final m in data.members)
                FbButton.gray(
                  '${m.relationLabel} 전화',
                  icon: FbIcons.phone,
                  onPressed: () => onCallMember(m),
                ),
            ],
          ),
        const FraudHelpButton(),
      ],
    );
  }
}
