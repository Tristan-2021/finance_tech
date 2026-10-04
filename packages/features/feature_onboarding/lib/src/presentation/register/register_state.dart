enum RegisterStatus { editing, submitting, registered, confirmEmail, error }

/// Estado del registro. La contraseña NO está aquí: la guarda el Cubit en un
/// campo privado para que no pueda registrarse ni persistirse por accidente.
class RegisterState {
  static const totalSteps = 3;

  final int step;
  final String email;
  final String fullName;
  final DateTime? birthDate;
  final String? accountUsage;

  final String? emailError;
  final String? passwordError;
  final String? fullNameError;
  final String? birthDateError;
  final String? usageError;

  final RegisterStatus status;

  /// Mensaje del backend (de `messageForFailure`) cuando [status] es error.
  final String? message;

  const RegisterState({
    this.step = 1,
    this.email = '',
    this.fullName = '',
    this.birthDate,
    this.accountUsage,
    this.emailError,
    this.passwordError,
    this.fullNameError,
    this.birthDateError,
    this.usageError,
    this.status = RegisterStatus.editing,
    this.message,
  });

  /// Los datos (`step`, `email`, `fullName`, `birthDate`, `accountUsage`,
  /// `status`) se conservan si no se pasan. Los errores y el mensaje se
  /// reemplazan siempre: sin argumento quedan en `null`.
  RegisterState copyWith({
    int? step,
    String? email,
    String? fullName,
    DateTime? birthDate,
    String? accountUsage,
    String? emailError,
    String? passwordError,
    String? fullNameError,
    String? birthDateError,
    String? usageError,
    RegisterStatus? status,
    String? message,
  }) {
    return RegisterState(
      step: step ?? this.step,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      accountUsage: accountUsage ?? this.accountUsage,
      emailError: emailError,
      passwordError: passwordError,
      fullNameError: fullNameError,
      birthDateError: birthDateError,
      usageError: usageError,
      status: status ?? this.status,
      message: message,
    );
  }
}
