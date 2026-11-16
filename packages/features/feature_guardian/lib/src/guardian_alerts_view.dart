import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'alert_row.dart';
import 'incident_summary_sheet.dart';

/// 가족 알림 전체 목록 및 지난 위험 기록 (기획서 5.8).
class GuardianAlertsView extends StatelessWidget {
  final FamilySnapshot data;
  final ValueChanged<Member>? onCallMember;

  const GuardianAlertsView({super.key, required this.data, this.onCallMember});

  @override
  Widget build(BuildContext context) {
    final filter = context.select((ShellCubit s) => s.state.alertFilter);
    final family = context.read<FamilyCubit>();
    final now = family.now();
    final alerts = data.alerts
        .where((a) => filter == 'all' || a.status == 'pending' || a.status == 'reconfirm')
        .toList();
    final incidents = data.closedIncidents;
    return FbView(
      children: [
        const Greeting('가족 알림'),
        FbFilterChips(
          items: const [('all', '전체'), ('pending', '확인 필요'), ('incidents', '위험 기록')],
          active: filter,
          onSelected: context.read<ShellCubit>().setAlertFilter,
        ),
        FbCard.list(
          child: filter == 'incidents'
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: incidents.isEmpty
                      ? const [EmptyText('지난 위험 기록이 없어요')]
                      : [
                          for (final inc in incidents)
                            IncidentHistoryRow(
                              incident: inc,
                              data: data,
                              now: now,
                              onTap: () => openIncidentSummarySheet(
                                context,
                                incidentId: inc.id,
                                initialIncident: inc,
                                member: data.memberOrNull(inc.memberId),
                                now: family.now,
                                onCallMember: onCallMember,
                              ),
                            ),
                        ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: alerts.isEmpty
                      ? const [EmptyText('확인할 알림이 없어요')]
                      : [for (final a in alerts) AlertRow(alert: a, data: data, now: now)],
                ),
        ),
      ],
    );
  }
}
