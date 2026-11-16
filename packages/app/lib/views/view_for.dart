import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_guardian/feature_guardian.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app_links.dart';
import 'easy_home.dart';
import 'member_history.dart';
import 'member_home.dart';
import 'member_safety.dart';
import 'settings_view.dart';

/// 사용자 × 탭 → 화면. 홈·내역(내 계좌)은 누구나 같고, 보호자는 가족 알림·관리 탭이 더 있습니다.
Widget viewFor(BuildContext context, ShellState shell, FamilySnapshot data, {required String serverAddress}) {
  final memberId = shell.memberId;
  if (shell.tab == AppTab.settings) return SettingsView(serverAddress: serverAddress);

  Widget wrapHome(Widget home) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const EasyModeTopBar(),
      const SizedBox(height: 10),
      home,
    ],
  );

  if (memberId == null) {
    final me = data.guardian.banking;
    void callMember(Member m) =>
        AppLinks.openCall(context.read<ShellCubit>(), peer: m.id);
    return switch (shell.tab) {
      AppTab.home => wrapHome(
        shell.prefs.easyMode
            ? EasyGuardianHome(data: data, onCallMember: callMember)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GuardianHomeView(
                    data: data,
                    banking: me == null ? const [] : guardianBanking(me),
                    onCallMember: callMember,
                  ),
                  const SizedBox(height: 12),
                  const FraudHelpButton(),
                ],
              ),
      ),
      AppTab.history when me != null => MemberHistory(member: me),
      AppTab.history || AppTab.alerts => GuardianAlertsView(data: data, onCallMember: callMember),
      _ => GuardianManageView(data: data, onCallMember: callMember),
    };
  }
  final member = data.member(memberId);
  return switch (shell.tab) {
    AppTab.home => wrapHome(
      shell.prefs.easyMode
          ? EasyMemberHome(member: member, data: data)
          : (member.isChild ? ChildHome(member: member, data: data) : SeniorHome(member: member, data: data)),
    ),
    AppTab.history || AppTab.alerts => MemberHistory(member: member),
    _ => MemberSafety(member: member, data: data),
  };
}
