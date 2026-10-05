import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'accounts_cubit.dart';
import 'accounts_view.dart';

/// Pantalla de cuentas. El nombre, el segmento y el cierre de sesión los pasa
/// el shell: este feature no depende de feature_onboarding.
///
/// Resuelve su [AccountsCubit] desde `GetIt.instance` (registrado por
/// `registerAccountsDependencies`) y lo cierra al salir.
class AccountsPage extends StatefulWidget {
  final String greetingName;
  final String segment;
  final VoidCallback onSignOut;

  const AccountsPage({
    super.key,
    required this.greetingName,
    required this.segment,
    required this.onSignOut,
  });

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  late final AccountsCubit _cubit = GetIt.instance<AccountsCubit>();

  @override
  void initState() {
    super.initState();
    _cubit.load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AccountsView(
      cubit: _cubit,
      greetingName: widget.greetingName,
      segment: widget.segment,
      onSignOut: widget.onSignOut,
    );
  }
}
