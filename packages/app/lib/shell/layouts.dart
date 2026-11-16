import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../views/view_for.dart';
import 'banners.dart';

typedef NavEntry = (AppTab tab, String label, IconData icon);

const _memberNav = <NavEntry>[
  (AppTab.home, '홈', FbIcons.home),
  (AppTab.history, '내역', FbIcons.list),
  (AppTab.safety, '안심', FbIcons.shield),
  (AppTab.settings, '설정', FbIcons.gear),
];

List<NavEntry> navFor(Persona p) => switch (p) {
  Persona.senior => _memberNav,
  Persona.child => const [
    (AppTab.home, '홈', FbIcons.home),
    (AppTab.history, '용돈', FbIcons.list),
    (AppTab.safety, '안심', FbIcons.shield),
    (AppTab.settings, '설정', FbIcons.gear),
  ],
  // 보호자도 내 계좌(홈·내역)는 똑같이 쓰고, 가족 알림·관리가 더 있습니다.
  Persona.guardian => const [
    (AppTab.home, '홈', FbIcons.home),
    (AppTab.history, '내역', FbIcons.list),
    (AppTab.alerts, '알림', FbIcons.bell),
    (AppTab.safety, '관리', FbIcons.users),
    (AppTab.settings, '설정', FbIcons.gear),
  ],
};

/// 상단의 시연 사용자 전환 (어르신 / 아이 / 보호자).
class PersonaSwitch extends StatelessWidget {
  const PersonaSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final persona = context.select((ShellCubit s) => s.state.persona);
    final shell = context.read<ShellCubit>();
    return Semantics(
      label: '시연할 사용자 선택',
      child: FbSegmented<Persona>(
        compact: true,
        options: [for (final p in Persona.values) (p, p.label)],
        value: persona,
        onChanged: (p) => shell.goto(p, shell.state.tab),
      ),
    );
  }
}

/// 알림 종 (확인할 것이 있으면 빨간 점). 아이콘만 두지 않고 글자를 함께 붙입니다.
class BellButton extends StatelessWidget {
  const BellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final shell = context.watch<ShellCubit>().state;
    final data = context.watch<FamilyCubit>().state.snapshot;
    final memberId = shell.memberId;
    final dot = data != null &&
        (memberId == null ? data.pending().isNotEmpty : (data.memberOrNull(memberId)?.notices.isNotEmpty ?? false));
    void openAlerts() => context.read<ShellCubit>().switchTab(memberId == null ? AppTab.alerts : AppTab.history);
    return Tooltip(
      message: dot ? '새 알림 있음' : '알림 확인',
      child: Semantics(
        button: true,
        label: dot ? '새 알림 있음' : '알림 확인',
        onTap: openAlerts,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: openAlerts,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 57, minHeight: 57),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(FbIcons.bell, color: c.ink2, size: 21),
                      if (dot)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: c.red, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('새 알림', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.ink2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 배너 + 지금 탭의 화면.
class ShellBody extends StatelessWidget {
  final String serverAddress;
  const ShellBody({super.key, required this.serverAddress});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellCubit>().state;
    final family = context.watch<FamilyCubit>().state;
    final banner = bannerFor(context, shell, family);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banner != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 2),
            child: banner,
          ),
        KeyedSubtree(
          key: ValueKey('${shell.persona.name}-${shell.tab.name}'),
          child: viewFor(context, shell, family.data, serverAddress: serverAddress),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 모바일 (1단 + 하단 메뉴)
class MobileLayout extends StatefulWidget {
  final String serverAddress;
  const MobileLayout({super.key, required this.serverAddress});

  @override
  State<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<MobileLayout> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final shell = context.watch<ShellCubit>().state;
    final narrow = MediaQuery.sizeOf(context).width < 380;
    return BlocListener<ShellCubit, ShellState>(
      listenWhen: (a, b) => a.tab != b.tab || a.persona != b.persona,
      listener: (_, _) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: Column(
          children: [
            Container(
              color: c.glass,
              padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 8, 8),
              child: Row(
                children: [
                  Brand(showWordmark: !narrow),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        PersonaSwitch(),
                        BellButton(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: ShellBody(serverAddress: widget.serverAddress),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Color(0xF2FFFFFF),
            border: Border(top: BorderSide(color: Color(0xFFEFF1F4))),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Row(
                children: [
                  for (final (tab, label, icon) in navFor(shell.persona))
                    Expanded(
                      child: _BottomNavItem(
                        label: label,
                        icon: icon,
                        selected: shell.tab == tab,
                        onTap: () => context.read<ShellCubit>().switchTab(tab),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.fb;
    final color = selected ? c.ink : c.navIdle;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 23, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
