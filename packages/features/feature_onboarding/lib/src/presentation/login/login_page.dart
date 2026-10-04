import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'login_cubit.dart';
import 'login_view.dart';

/// Crea el [LoginCubit] desde GetIt (registrado por
/// `registerOnboardingDependencies`) y lo cierra al salir.
class LoginPage extends StatefulWidget {
  final VoidCallback onAuthenticated;
  final VoidCallback onGoToRegister;

  const LoginPage({
    super.key,
    required this.onAuthenticated,
    required this.onGoToRegister,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final LoginCubit _cubit = GetIt.instance<LoginCubit>();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoginView(
      cubit: _cubit,
      onAuthenticated: widget.onAuthenticated,
      onGoToRegister: widget.onGoToRegister,
    );
  }
}
