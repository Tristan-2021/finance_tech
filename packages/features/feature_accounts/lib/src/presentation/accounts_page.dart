import 'package:core_network/core_network.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'accounts_cubit.dart';
import 'accounts_view.dart';
import 'add_movement_cubit.dart';
import 'movements_cubit.dart';

/// Pantalla de cuentas. El nombre, el segmento y el cierre de sesión los pasa
/// el shell: este feature no depende de feature_onboarding.
///
/// Resuelve su [AccountsCubit] y la fábrica de movimientos desde
/// `GetIt.instance` (registrados por `registerAccountsDependencies`) y cierra
/// el Cubit al salir. Si el shell registró un [NetworkStatusNotifier] y un
/// [ConnectivityMonitor], los usa para mostrar "Reintentando…" y para refrescar
/// al volver la red.
class AccountsPage extends StatefulWidget {
  final String greetingName;
  final String segment;
  final VoidCallback onSignOut;

  /// Contenido que el shell inserta bajo el saldo (p. ej. los bloques
  /// personalizados); este feature no conoce su origen.
  final Widget? extra;

  const AccountsPage({
    super.key,
    required this.greetingName,
    required this.segment,
    required this.onSignOut,
    this.extra,
  });

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final _getIt = GetIt.instance;
  late final AccountsCubit _cubit = _getIt<AccountsCubit>();
  late final MovementsCubitFactory _movementsCubitFactory =
      _getIt<MovementsCubitFactory>();

  T? _optional<T extends Object>() =>
      _getIt.isRegistered<T>() ? _getIt<T>() : null;

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
      movementsCubitFactory: _movementsCubitFactory,
      greetingName: widget.greetingName,
      segment: widget.segment,
      onSignOut: widget.onSignOut,
      extra: widget.extra,
      addMovementCubitFactory: _optional<AddMovementCubitFactory>(),
      networkStatus: _optional<NetworkStatusNotifier>(),
      connectivity: _optional<ConnectivityMonitor>(),
    );
  }
}
