import 'package:core_errors/core_errors.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/material.dart';

/// Puerta de sesión: consulta [GetCurrentUser] y avisa a dónde ir mediante
/// [onResolved] (`true` si hay usuario). Muestra [LoadingView] mientras tanto y
/// [ErrorView] con reintento si la consulta falla.
class SessionGate extends StatefulWidget {
  final GetCurrentUser getCurrentUser;
  final ValueChanged<bool> onResolved;

  const SessionGate({
    super.key,
    required this.getCurrentUser,
    required this.onResolved,
  });

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Navegar durante initState/build no está permitido: se espera a que
    // termine el primer frame (sin temporizadores).
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  void _resolve() {
    if (!mounted) return;
    try {
      final user = widget.getCurrentUser();
      widget.onResolved(user != null);
    } catch (_) {
      setState(() => _failed = true);
    }
  }

  void _retry() {
    setState(() => _failed = false);
    _resolve();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _failed
          ? ErrorView(
              message: messageForFailure(const Failure('', 'unknown')),
              onRetry: _retry,
            )
          : const LoadingView(),
    );
  }
}
