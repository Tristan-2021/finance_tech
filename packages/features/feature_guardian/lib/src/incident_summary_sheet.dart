import 'package:core_family/core_family.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 사건의 위험 근거 요약 시트를 엽니다 (기획서 5.8).
Future<void> openIncidentSummarySheet(
  BuildContext context, {
  required String incidentId,
  Incident? initialIncident,
  Member? member,
  required DateTime Function() now,
  ValueChanged<Member>? onCallMember,
}) => showFbSheet<void>(
  context,
  builder: (_) => IncidentSummarySheet(
    incidentId: incidentId,
    initialIncident: initialIncident,
    member: member,
    now: now,
    onCallMember: onCallMember,
  ),
);

/// 사건 항목 종류의 한국어 라벨 (기획서 5.8).
String incidentKindLabel(String kind) => switch (kind) {
  'sms' => '문자',
  'call' => '통화 징후',
  'action' => '금융 행동',
  'answer' => '확인 질문 답',
  'judgment' => '판정',
  'hold' => '보류',
  'guardian' => '보호자 조치',
  _ => '주의 모드',
};

bool _isDangerKind(String kind) => kind == 'sms' || kind == 'call' || kind == 'hold' || kind == 'judgment';

/// 사건의 시간순 근거 요약 목록. 원문이 아니라 서버가 사건에 남긴 요약만 보여 줍니다 (기획서 5.8).
class IncidentTimeline extends StatelessWidget {
  final Incident incident;
  final DateTime now;
  final bool compact;

  const IncidentTimeline({
    super.key,
    required this.incident,
    required this.now,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final items = [...incident.items]..sort((a, b) => a.at.compareTo(b.at));
    if (items.isEmpty) {
      return const EmptyText('기록된 근거 요약이 없어요');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: compact ? 8 : 10),
          _TimelineItemRow(
            key: ValueKey('incident-item-${items[i].id}'),
            item: items[i],
            now: now,
            compact: compact,
            colors: c,
          ),
        ],
      ],
    );
  }
}

class _TimelineItemRow extends StatelessWidget {
  final IncidentItem item;
  final DateTime now;
  final bool compact;
  final FbColors colors;

  const _TimelineItemRow({
    super.key,
    required this.item,
    required this.now,
    required this.compact,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final danger = _isDangerKind(item.kind);
    final isGuardian = item.kind == 'guardian';
    final badgeBg = danger ? colors.redSoft : (isGuardian ? colors.blueSoft : colors.soft);
    final badgeFg = danger ? colors.redStrong : (isGuardian ? colors.blueStrong : colors.ink2);
    final kindText = incidentKindLabel(item.kind);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: compact ? colors.card : colors.soft,
        borderRadius: BorderRadius.circular(12),
        border: colors.cardBorder != null ? Border.all(color: colors.cardBorder!) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(99)),
                child: Text(
                  kindText,
                  style: TextStyle(fontSize: 11.6, fontWeight: FontWeight.w800, color: badgeFg),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatWhen(item.at, now),
                  style: FbText.small(colors),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            item.summary,
            style: TextStyle(
              fontSize: compact ? 13.2 : 13.8,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// 위험 기록 목록의 사건 한 줄. 누르면 시간순 근거 요약을 엽니다 (기획서 5.8).
class IncidentHistoryRow extends StatelessWidget {
  final Incident incident;
  final FamilySnapshot data;
  final DateTime now;
  final VoidCallback onTap;

  const IncidentHistoryRow({
    super.key,
    required this.incident,
    required this.data,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final m = data.memberOrNull(incident.memberId);
    final items = [...incident.items]..sort((a, b) => a.at.compareTo(b.at));
    final firstSummary = items.isNotEmpty ? items.first.summary : '주의 모드 사건';
    final endLabel = incident.isOpen
        ? '진행 중'
        : (incident.endedBy == 'guardian' ? '보호자 해제' : '종료됨');
    return FbListRow(
      leading: TxLogo(icon: incident.isOpen ? FbIcons.alert : FbIcons.shield, blue: !incident.isOpen),
      title: Text('${m?.label ?? incident.memberId} · $firstSummary'),
      subtitle: '${formatWhen(incident.startedAt, now)} · 항목 ${items.length}건',
      trailing: Text(
        endLabel,
        style: FbText.note(c).copyWith(color: incident.isOpen ? c.redStrong : c.muted),
      ),
      chevron: true,
      onTap: onTap,
    );
  }
}

/// 사건의 시간순 근거 요약 시트 (기획서 5.8).
class IncidentSummarySheet extends StatelessWidget {
  final String incidentId;
  final Incident? initialIncident;
  final Member? member;
  final DateTime Function() now;
  final ValueChanged<Member>? onCallMember;

  const IncidentSummarySheet({
    super.key,
    required this.incidentId,
    required this.now,
    this.initialIncident,
    this.member,
    this.onCallMember,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    return BlocBuilder<FamilyCubit, FamilyState>(
      builder: (context, state) {
        final data = state.isReady ? state.data : null;
        final incident = data?.incidentOrNull(incidentId) ?? initialIncident;
        if (incident == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHead(title: '위험 근거 요약', onClose: () => Navigator.of(context).maybePop()),
              const EmptyText('사건 기록을 찾을 수 없어요'),
              const SizedBox(height: 16),
              FbButton.gray('닫기', onPressed: () => Navigator.of(context).maybePop()),
            ],
          );
        }
        final resolvedMember = data?.memberOrNull(incident.memberId) ?? member;
        final current = now();
        final who = resolvedMember?.label ?? incident.memberId;
        final statusText = incident.isOpen
            ? '진행 중인 사건'
            : (incident.endedBy == 'guardian' ? '종료됨 (보호자 해제)' : '종료됨 (시간 경과)');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHead(title: '위험 근거 요약', onClose: () => Navigator.of(context).maybePop()),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: incident.isOpen ? c.redSoft : c.soft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$who · $statusText',
                    style: TextStyle(
                      fontSize: 15.2,
                      fontWeight: FontWeight.w800,
                      color: incident.isOpen ? c.redStrong : c.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '시작 ${formatWhen(incident.startedAt, current)}'
                    '${incident.endedAt != null ? ' · 종료 ${formatWhen(incident.endedAt!, current)}' : ''}',
                    style: FbText.small(c).copyWith(color: c.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '문자·통화 원문은 저장하지 않고, 위험 판정에 쓰인 요약만 시간순으로 보여줘요.',
              style: FbText.small(c),
            ),
            const SizedBox(height: 12),
            IncidentTimeline(incident: incident, now: current),
            const SizedBox(height: 16),
            if (incident.isOpen && resolvedMember != null && onCallMember != null) ...[
              FbButton(
                '${resolvedMember.relationLabel}에게 전화하기',
                icon: FbIcons.phone,
                onPressed: () {
                  Navigator.of(context).pop();
                  onCallMember!(resolvedMember);
                },
              ),
              const SizedBox(height: 8),
            ],
            FbButton.gray('닫기', onPressed: () => Navigator.of(context).maybePop()),
          ],
        );
      },
    );
  }
}
