import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../onboarding_strings.dart';
import 'register_cubit.dart';
import 'register_state.dart';

/// Flujo de registro en 3 pasos. Recibe el Cubit (no usa GetIt).
class RegisterView extends StatefulWidget {
  final RegisterCubit cubit;
  final VoidCallback onRegistered;
  final VoidCallback onGoToLogin;

  const RegisterView({
    super.key,
    required this.cubit,
    required this.onRegistered,
    required this.onGoToLogin,
  });

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  // Los controladores viven mientras viva la vista: al volver atrás el texto
  // sigue ahí.
  late final _email = TextEditingController(text: widget.cubit.state.email);
  final _password = TextEditingController();
  late final _fullName = TextEditingController(
    text: widget.cubit.state.fullName,
  );
  late DateTime? _birthDate = widget.cubit.state.birthDate;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  DateTime get _defaultPickerDate {
    final t = widget.cubit.today;
    final day = (t.month == 2 && t.day == 29) ? 28 : t.day;
    return DateTime(t.year - 18, t.month, day);
  }

  Future<void> _pickBirthDate() async {
    final today = widget.cubit.today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? _defaultPickerDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: OnboardingStrings.birthDateHelp,
    );
    if (picked == null || !mounted) return;
    setState(() => _birthDate = DateTime(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RegisterCubit, RegisterState>(
      bloc: widget.cubit,
      listener: (context, state) {
        if (state.status == RegisterStatus.registered) widget.onRegistered();
      },
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: state.status == RegisterStatus.confirmEmail
                      ? _ConfirmEmail(onGoToLogin: widget.onGoToLogin)
                      : _Form(
                          state: state,
                          children: _stepChildren(state),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _stepChildren(RegisterState state) {
    return switch (state.step) {
      1 => _step1(state),
      2 => _step2(state),
      _ => _step3(state),
    };
  }

  List<Widget> _step1(RegisterState state) {
    final theme = Theme.of(context);
    return [
      _Header(
        title: OnboardingStrings.registerStep1Title,
        subtitle: OnboardingStrings.registerStep1Subtitle,
      ),
      AppTextField(
        label: OnboardingStrings.emailLabel,
        controller: _email,
        errorText: state.emailError,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.newUsername, AutofillHints.email],
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: AppSpacing.lg),
      AppTextField(
        label: OnboardingStrings.passwordLabel,
        controller: _password,
        errorText: state.passwordError,
        obscure: true,
        autofillHints: const [AutofillHints.newPassword],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _next1(),
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(OnboardingStrings.passwordHint, style: theme.textTheme.bodySmall),
      const SizedBox(height: AppSpacing.xl),
      AppButton(label: OnboardingStrings.continueAction, onPressed: _next1),
      const SizedBox(height: AppSpacing.sm),
      AppButton(
        label: OnboardingStrings.haveAccount,
        variant: AppButtonVariant.text,
        onPressed: widget.onGoToLogin,
      ),
    ];
  }

  void _next1() => widget.cubit.nextFromCredentials(
    email: _email.text,
    password: _password.text,
  );

  List<Widget> _step2(RegisterState state) {
    final date = _birthDate;
    final dateLabel =
        '${OnboardingStrings.birthDateLabel}: '
        '${date == null ? OnboardingStrings.birthDatePick : formatDateEs(date)}';
    return [
      _Header(
        title: OnboardingStrings.registerStep2Title,
        subtitle: OnboardingStrings.registerStep2Subtitle,
      ),
      AppTextField(
        label: OnboardingStrings.fullNameLabel,
        controller: _fullName,
        errorText: state.fullNameError,
        keyboardType: TextInputType.name,
        autofillHints: const [AutofillHints.name],
        textInputAction: TextInputAction.done,
      ),
      const SizedBox(height: AppSpacing.lg),
      AppButton(
        label: dateLabel,
        variant: AppButtonVariant.secondary,
        onPressed: _pickBirthDate,
      ),
      if (state.birthDateError != null) ...[
        const SizedBox(height: AppSpacing.xs),
        _FieldError(message: state.birthDateError!),
      ],
      const SizedBox(height: AppSpacing.xl),
      AppButton(
        label: OnboardingStrings.continueAction,
        onPressed: () => widget.cubit.nextFromProfile(
          fullName: _fullName.text,
          birthDate: _birthDate,
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      AppButton(
        label: OnboardingStrings.backAction,
        variant: AppButtonVariant.text,
        onPressed: widget.cubit.back,
      ),
    ];
  }

  List<Widget> _step3(RegisterState state) {
    final submitting = state.status == RegisterStatus.submitting;
    return [
      _Header(
        title: OnboardingStrings.registerStep3Title,
        subtitle: OnboardingStrings.registerStep3Subtitle,
      ),
      for (final option in OnboardingStrings.usageOptions) ...[
        _UsageOption(
          label: option,
          selected: state.accountUsage == option,
          onTap: submitting ? null : () => widget.cubit.selectUsage(option),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (state.usageError != null) _FieldError(message: state.usageError!),
      if (state.status == RegisterStatus.error && state.message != null) ...[
        const SizedBox(height: AppSpacing.sm),
        _FieldError(message: state.message!),
      ],
      const SizedBox(height: AppSpacing.xl),
      AppButton(
        label: OnboardingStrings.createAccountAction,
        isLoading: submitting,
        onPressed: widget.cubit.submit,
      ),
      const SizedBox(height: AppSpacing.sm),
      AppButton(
        label: OnboardingStrings.backAction,
        variant: AppButtonVariant.text,
        onPressed: submitting ? null : widget.cubit.back,
      ),
    ];
  }
}

class _Form extends StatelessWidget {
  final RegisterState state;
  final List<Widget> children;
  const _Form({required this.state, required this.children});

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppStepIndicator(
            current: state.step,
            total: RegisterState.totalSteps,
          ),
          const SizedBox(height: AppSpacing.xl),
          ...children,
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Opción seleccionable: indica la selección con icono y estado semántico
/// (nunca solo color).
class _UsageOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _UsageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          selected: selected,
          enabled: onTap != null,
          onTap: onTap,
          leading: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          ),
          title: Text(label),
        ),
      ),
    );
  }
}

/// Texto de error con icono, anunciado como región en vivo.
class _FieldError extends StatelessWidget {
  final String message;
  const _FieldError({required this.message});

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

class _ConfirmEmail extends StatelessWidget {
  final VoidCallback onGoToLogin;
  const _ConfirmEmail({required this.onGoToLogin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.mark_email_unread_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          liveRegion: true,
          child: Text(
            OnboardingStrings.confirmEmail,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: OnboardingStrings.goToLogin,
          onPressed: onGoToLogin,
        ),
      ],
    );
  }
}
