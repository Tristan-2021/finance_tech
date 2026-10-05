import 'package:core_errors/core_errors.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/material.dart';

import 'app_strings.dart';

/// Ruta de entrada tras autenticarse. Lee el perfil (feature_onboarding) y,
/// con el nombre y el segmento, muestra la pantalla de cuentas
/// (feature_accounts): el shell es el único que conoce a los dos features.
///
/// Mientras llega el perfil, o si falla, ofrece carga, reintento y cierre de
/// sesión.
class WelcomePage extends StatefulWidget {
  final GetUserProfile getUserProfile;
  final SignOut signOut;
  final VoidCallback onSignedOut;

  const WelcomePage({
    super.key,
    required this.getUserProfile,
    required this.signOut,
    required this.onSignedOut,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _loading = true;
  UserProfile? _profile;
  String? _loadError;

  bool _signingOut = false;
  String? _signOutError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await widget.getUserProfile();
    if (!mounted) return;
    final profile = result.profile;
    setState(() {
      _loading = false;
      _profile = profile;
      _loadError = profile != null
          ? null
          : messageForFailure(result.failure ?? const Failure('', 'unknown'));
    });
  }

  void _retry() {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _load();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() {
      _signingOut = true;
      _signOutError = null;
    });
    final failure = await widget.signOut();
    if (!mounted) return;
    if (failure != null) {
      final message = messageForFailure(failure);
      setState(() {
        _signingOut = false;
        _signOutError = message;
      });
      if (_profile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return;
    }
    widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile != null) {
      return AccountsPage(
        greetingName: profile.fullName,
        segment: profile.segment,
        onSignOut: _signOut,
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : ErrorView(message: _loadError!, onRetry: _retry),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_signOutError != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _signOutError!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
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
          ],
        ),
      ),
    );
  }
}
