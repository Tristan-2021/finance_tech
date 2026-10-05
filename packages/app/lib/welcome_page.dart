import 'package:core_ui/core_ui.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/material.dart';

import 'app_strings.dart';

/// Pantalla PROVISIONAL tras autenticarse. Se sustituirá por la pantalla de
/// cuentas: mantenerla en un solo archivo para reemplazarla fácilmente.
class WelcomePage extends StatefulWidget {
  final SignOut signOut;
  final VoidCallback onSignedOut;

  const WelcomePage({
    super.key,
    required this.signOut,
    required this.onSignedOut,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _signingOut = false;
  String? _error;

  Future<void> _signOut() async {
    setState(() {
      _signingOut = true;
      _error = null;
    });
    final failure = await widget.signOut();
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _signingOut = false;
        _error = messageForFailure(failure);
      });
      return;
    }
    widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppStrings.welcomeTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    AppStrings.accountsPlaceholder,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: AppStrings.signOutAction,
                    variant: AppButtonVariant.secondary,
                    isLoading: _signingOut,
                    onPressed: _signOut,
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
