import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'register_cubit.dart';
import 'register_view.dart';

/// Crea el [RegisterCubit] desde GetIt (registrado por
/// `registerOnboardingDependencies`) y lo cierra al salir.
class RegisterPage extends StatefulWidget {
  final VoidCallback onRegistered;
  final VoidCallback onGoToLogin;

  const RegisterPage({
    super.key,
    required this.onRegistered,
    required this.onGoToLogin,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  late final RegisterCubit _cubit = GetIt.instance<RegisterCubit>();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RegisterView(
      cubit: _cubit,
      onRegistered: widget.onRegistered,
      onGoToLogin: widget.onGoToLogin,
    );
  }
}
