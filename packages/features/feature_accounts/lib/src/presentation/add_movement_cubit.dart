import 'package:core_telemetry/core_telemetry.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/add_movement.dart';
import '../domain/movement_amount.dart';
import '../domain/transaction_type.dart';
import 'accounts_strings.dart';
import 'add_movement_state.dart';

/// Crea el Cubit del formulario para una cuenta. Se registra en GetIt para que
/// la vista no dependa del contenedor.
typedef AddMovementCubitFactory = AddMovementCubit Function(String accountId);

/// Valida el formulario y registra el movimiento. Sin conexión falla con un
/// mensaje claro: no hay cola de envíos pendientes.
///
/// Telemetría: `movement_added` con `result` (y `code` si falla); nunca importes.
class AddMovementCubit extends Cubit<AddMovementState> {
  static const maxDescriptionLength = 80;

  final AddMovement _addMovement;
  final String accountId;
  final Telemetry _telemetry;

  AddMovementCubit(this._addMovement, this.accountId, {Telemetry? telemetry})
    : _telemetry = telemetry ?? const NoopTelemetry(),
      super(const AddMovementState());

  static String amountErrorText(AmountError error) => switch (error) {
    AmountError.empty => 'Escribe un monto.',
    AmountError.invalid => 'Escribe un monto válido, por ejemplo 12,50.',
    AmountError.tooManyDecimals => 'Usa como máximo dos decimales.',
    AmountError.notPositive => 'El monto debe ser mayor que cero.',
    AmountError.tooLarge =>
      'El monto máximo es ${formatCents(maxMovementCents)}.',
  };

  Future<void> submit({
    required String amountText,
    required TransactionType type,
    required String category,
    required String description,
  }) async {
    if (state.isSubmitting) return;

    final amount = validateAmount(amountText);
    final text = description.trim();
    final amountError = amount.error == null
        ? null
        : amountErrorText(amount.error!);
    final descriptionError = text.length > maxDescriptionLength
        ? AccountsStrings.descriptionTooLong
        : null;
    if (amountError != null || descriptionError != null) {
      emit(
        AddMovementState(
          amountError: amountError,
          descriptionError: descriptionError,
        ),
      );
      return;
    }

    emit(const AddMovementState(status: AddMovementStatus.submitting));
    final failure = await _addMovement(
      accountId: accountId,
      type: type,
      amountCents: amount.cents!,
      category: category,
      description: text.isEmpty
          ? (type == TransactionType.debit
                ? AccountsStrings.manualExpenseDefault
                : AccountsStrings.manualIncomeDefault)
          : text,
    );
    if (isClosed) return;

    if (failure != null) {
      _telemetry.logEvent('movement_added', {
        'result': 'error',
        'code': failure.code,
      });
      emit(
        AddMovementState(
          status: AddMovementStatus.error,
          message: messageForFailure(failure),
        ),
      );
      return;
    }
    _telemetry.logEvent('movement_added', {'result': 'success'});
    emit(const AddMovementState(status: AddMovementStatus.success));
  }
}
