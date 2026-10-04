import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../onboarding_strings.dart';
import 'login_cubit.dart';
import 'login_state.dart';

/// Pantalla de login. Recibe el Cubit (no usa GetIt) para poder probarse sola.
class LoginView extends StatefulWidget {
  final LoginCubit cubit;
  final VoidCallback onAuthenticated;
  final VoidCallback onGoToRegister;

  const LoginView({
    super.key,
    required this.cubit,
    required this.onAuthenticated,
    required this.onGoToRegister,
  });

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    widget.cubit.submit(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<LoginCubit, LoginState>(
      bloc: widget.cubit,
      listener: (context, state) {
        if (state is LoginSuccess) widget.onAuthenticated();
      },
      builder: (context, state) {
        final loading = state is LoginLoading;
        final invalid = state is LoginInvalid ? state : null;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          OnboardingStrings.loginTitle,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          OnboardingStrings.loginSubtitle,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppTextField(
                          label: OnboardingStrings.emailLabel,
                          controller: _email,
                          errorText: invalid?.emailError,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          enabled: !loading,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppTextField(
                          label: OnboardingStrings.passwordLabel,
                          controller: _password,
                          errorText: invalid?.passwordError,
                          obscure: true,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          enabled: !loading,
                        ),
                        if (state is LoginError) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _ErrorMessage(message: state.message),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: OnboardingStrings.loginAction,
                          isLoading: loading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppButton(
                          label: OnboardingStrings.goToRegister,
                          variant: AppButtonVariant.text,
                          onPressed: loading ? null : widget.onGoToRegister,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Icono y texto (nunca solo color), anunciado como región en vivo.
class _ErrorMessage extends StatelessWidget {
  final String message;
  const _ErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(Icons.error_outline, color: theme.colorScheme.error),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
