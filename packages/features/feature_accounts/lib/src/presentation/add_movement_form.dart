import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/movement_categories.dart';
import '../domain/transaction_type.dart';
import 'accounts_strings.dart';
import 'add_movement_cubit.dart';
import 'add_movement_state.dart';

/// Abre el formulario en una hoja inferior. Devuelve `true` si se registró el
/// movimiento. El llamador es dueño de [cubit] y lo cierra después.
Future<bool> showAddMovementSheet(
  BuildContext context,
  AddMovementCubit cubit,
) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => AddMovementForm(cubit: cubit),
  );
  return saved ?? false;
}

/// Formulario de movimiento manual (demostración). Al guardar con éxito cierra
/// su ruta devolviendo `true`.
class AddMovementForm extends StatefulWidget {
  final AddMovementCubit cubit;
  const AddMovementForm({super.key, required this.cubit});

  @override
  State<AddMovementForm> createState() => _AddMovementFormState();
}

class _AddMovementFormState extends State<AddMovementForm> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  TransactionType _type = TransactionType.debit;
  String _category = expenseCategories.first;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  void _setType(TransactionType type) {
    setState(() {
      _type = type;
      _category = categoriesFor(type).first;
    });
  }

  void _submit() => widget.cubit.submit(
    amountText: _amount.text,
    type: _type,
    category: _category,
    description: _description.text,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<AddMovementCubit, AddMovementState>(
      bloc: widget.cubit,
      listenWhen: (previous, current) =>
          current.status == AddMovementStatus.success,
      listener: (context, _) => Navigator.of(context).pop(true),
      builder: (context, state) {
        final busy = state.isSubmitting;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _type == TransactionType.debit
                    ? AccountsStrings.manualExpenseTitle
                    : AccountsStrings.manualIncomeTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(AccountsStrings.demoNote, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.debit,
                    label: Text(AccountsStrings.expenseLabel),
                  ),
                  ButtonSegment(
                    value: TransactionType.credit,
                    label: Text(AccountsStrings.incomeLabel),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: busy ? null : (s) => _setType(s.first),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: AccountsStrings.amountLabel,
                controller: _amount,
                errorText: state.amountError,
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(AccountsStrings.categoryLabel, style: theme.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final category in categoriesFor(_type))
                    ChoiceChip(
                      label: Text(AccountsStrings.category(category)),
                      selected: category == _category,
                      onSelected: busy
                          ? null
                          : (_) => setState(() => _category = category),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: AccountsStrings.descriptionLabel,
                controller: _description,
                errorText: state.descriptionError,
                enabled: !busy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => busy ? null : _submit(),
              ),
              if (state.message != null) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    state.message!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: AccountsStrings.addMovementSubmit,
                isLoading: busy,
                onPressed: _submit,
              ),
            ],
          ),
        );
      },
    );
  }
}
