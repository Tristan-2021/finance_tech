import 'package:core_errors/core_errors.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/material.dart';

import 'app_strings.dart';

/// Pantalla PROVISIONAL tras autenticarse: saludo, segmento y cierre de
/// sesión. Se sustituirá por la pantalla de cuentas: mantenerla en un solo
/// archivo para reemplazarla fácilmente.
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
          : messageForFailure(
              result.failure ?? const Failure('', 'unknown'),
            );
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
    setState(() {
      _signingOut = true;
      _signOutError = null;
    });
    final failure = await widget.signOut();
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _signingOut = false;
        _signOutError = messageForFailure(failure);
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
        child: Column(
          children: [
            Expanded(child: _body(theme)),
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

  Widget _body(ThemeData theme) {
    if (_loading) return const LoadingView();

    final profile = _profile;
    if (profile == null) {
      return ErrorView(message: _loadError!, onRetry: _retry);
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.greeting(profile.fullName),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Chip(
                label: Text(AppStrings.segmentLabel(profile.segment)),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppStrings.accountsPlaceholder,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
