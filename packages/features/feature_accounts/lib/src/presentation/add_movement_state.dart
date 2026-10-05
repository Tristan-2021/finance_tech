enum AddMovementStatus { idle, submitting, success, error }

class AddMovementState {
  final AddMovementStatus status;

  /// Errores de validación de cada campo (nada se envía mientras haya alguno).
  final String? amountError;
  final String? descriptionError;

  /// Mensaje de un fallo del servidor o de la red.
  final String? message;

  const AddMovementState({
    this.status = AddMovementStatus.idle,
    this.amountError,
    this.descriptionError,
    this.message,
  });

  bool get isSubmitting => status == AddMovementStatus.submitting;
}
