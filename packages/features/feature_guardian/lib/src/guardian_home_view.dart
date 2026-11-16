import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'alert_row.dart';
import 'guardian_actions.dart';
import 'incident_summary_sheet.dart';
import 'request_card.dart';

/// 보호자 홈: 기다리는 보류·승인 요청, 주의 모드 상태와 근거 요약, 내 계좌, 최근 알림, 위험 기록, 가족 상태.
class GuardianHomeView extends StatelessWidget {
  final FamilySnapshot data;

  /// 보호자 본인 계좌 카드들 (잔액·송금·결제·최근 거래). 송금·결제 기능은 앱이 연결합니다.
  final List<Widget> banking;

  /// 앱 안 통화로 가족에게 전화하기 콜백 (기획서 5.3, 5.8).
  final ValueChanged<Member>? onCallMember;

  const GuardianHomeView({super.key, required this.data, this.banking = const [], this.onCallMember});

  @override
  Widget build(BuildContext context) {
    final family = context.read<FamilyCubit>();
    final pending = data.pending();
    final now = family.now();

    final cautionCards = [
      for (final m in data.members)
        if (m.cautionMode)
          _GuardianCautionCard(
            key: ValueKey('caution-${m.id}'),
            member: m,
            incident: data.openIncidentFor(m.id),
            now: family.now,
            onCallMember: onCallMember,
          ),
    ];
    final requests = [
      for (final r in pending)
        RequestCard(key: ValueKey(r.id), request: r, data: data, now: family.now, onCallMember: onCallMember),
    ];
    final alerts = FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListHead(
            '최근 알림',
            action: '전체보기',
            onAction: () => context.read<ShellCubit>().switchTab(AppTab.alerts),
          ),
          for (final a in data.alerts.take(5)) AlertRow(alert: a, data: data, now: now),
          if (data.alerts.isEmpty) const EmptyText('아직 알림이 없어요'),
        ],
      ),
    );
    final historyCard = _IncidentHistoryCard(data: data, now: family.now, onCallMember: onCallMember);
    final familyCard = FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ListHead('가족'),
          Text('오늘 차단 ${data.blockedToday}건 · AI 위험 판정 ${data.riskyTransfers}건', style: FbText.small(context.fb)),
          for (final m in data.members) _FamilyRow(member: m, data: data, onCallMember: onCallMember),
        ],
      ),
    );

    return FbView(
      wide: true,
      children: [
        Greeting(
          pending.isEmpty ? '가족 모두 안전해요' : '확인할 요청이 ${pending.length}건 있어요',
          sub: '${data.guardian.name}님',
        ),
        // 웹: 왼쪽은 요청과 내 계좌, 오른쪽은 가족 (내 계좌가 없으면 알림을 왼쪽에)
        FbSplit(
          main: [...cautionCards, ...requests, ...banking, if (banking.isEmpty) alerts],
          side: [familyCard, if (banking.isNotEmpty) alerts, historyCard],
          mobile: [...cautionCards, ...requests, ...banking, familyCard, alerts, historyCard],
        ),
      ],
    );
  }
}

class _GuardianCautionCard extends StatelessWidget {
  final Member member;
  final Incident? incident;
  final DateTime Function() now;
  final ValueChanged<Member>? onCallMember;

  const _GuardianCautionCard({
    super.key,
    required this.member,
    this.incident,
    required this.now,
    this.onCallMember,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final inc = incident;
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
                  '${member.label} · 주의 모드 작동 중',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.redStrong),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('주의 모드 남은 시간 ', style: TextStyle(fontSize: 13.6, color: c.ink2)),
              if (member.cautionUntil != null)
                CountdownText(
                  until: member.cautionUntil!,
                  now: now,
                  style: TextStyle(fontSize: 13.6, fontWeight: FontWeight.w800, color: c.ink2),
                ),
            ],
          ),
          if (inc != null && inc.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '위험 근거 요약',
                    style: TextStyle(fontSize: 13.8, fontWeight: FontWeight.w800, color: c.ink),
                  ),
                ),
                FbTextButton(
                  '자세히 보기',
                  color: c.redStrong,
                  onPressed: () => openIncidentSummarySheet(
                    context,
                    incidentId: inc.id,
                    initialIncident: inc,
                    member: member,
                    now: now,
                    onCallMember: onCallMember,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            IncidentTimeline(incident: inc, now: now(), compact: true),
          ],
          const SizedBox(height: 12.8),
          if (onCallMember != null) ...[
            FbButton(
              '${member.relationLabel}에게 전화하기',
              icon: FbIcons.phone,
              onPressed: () => onCallMember!(member),
            ),
            const SizedBox(height: 8),
          ],
          FbButton(
            '주의 모드 해제',
            variant: FbButtonVariant.white,
            onPressed: () => guardianRun(context, (f) => f.releaseCautionMode(member.id), '${member.relationLabel} 주의 모드를 해제했어요'),
          ),
        ],
      ),
    );
  }
}

class _IncidentHistoryCard extends StatelessWidget {
  final FamilySnapshot data;
  final DateTime Function() now;
  final ValueChanged<Member>? onCallMember;

  const _IncidentHistoryCard({required this.data, required this.now, this.onCallMember});

  @override
  Widget build(BuildContext context) {
    final closed = data.closedIncidents;
    final current = now();
    final shell = context.read<ShellCubit>();
    return FbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListHead(
            '위험 기록',
            action: '전체보기',
            onAction: () {
              shell.setAlertFilter('incidents');
              shell.switchTab(AppTab.alerts);
            },
          ),
          if (closed.isEmpty)
            const EmptyText('지난 위험 기록이 없어요')
          else
            for (final inc in closed.take(3))
              IncidentHistoryRow(
                incident: inc,
                data: data,
                now: current,
                onTap: () => openIncidentSummarySheet(
                  context,
                  incidentId: inc.id,
                  initialIncident: inc,
                  member: data.memberOrNull(inc.memberId),
                  now: now,
                  onCallMember: onCallMember,
                ),
              ),
        ],
      ),
    );
  }
}

class _FamilyRow extends StatelessWidget {
  final Member member;
  final FamilySnapshot data;
  final ValueChanged<Member>? onCallMember;

  const _FamilyRow({required this.member, required this.data, this.onCallMember});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final hidden = context.select((ShellCubit s) => s.state.prefs.hideBalance);
    final m = member;
    final detail = m.isChild ? '오늘 ${won(m.spentToday)} 사용' : '잔액 ${wonOrHidden(m.balance, hidden: hidden)}';
    final statusLabel = m.isFrozen
        ? '동결 중'
        : m.cautionMode
        ? '주의 모드'
        : '정상';
    final danger = m.isFrozen || m.cautionMode;
    return FbListRow(
      leading: TxLogo.initial(m.name),
      title: Text(m.label),
      subtitle: '${data.mode(m.mode).label} · $detail',
      trailing: Text(
        statusLabel,
        style: FbText.note(c).copyWith(color: danger ? c.redStrong : c.muted),
      ),
      chevron: true,
      onTap: () => context.read<ShellCubit>().switchTab(AppTab.safety),
    );
  }
}
