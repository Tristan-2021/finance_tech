/// La contraseña nunca forma parte del estado.
sealed class LoginState {
  const LoginState();
}

class LoginInitial extends LoginState {
  const LoginInitial();
}

/// Validación de campos fallida (no se llamó al backend).
class LoginInvalid extends LoginState {
  final String? emailError;
  final String? passwordError;
  const LoginInvalid({this.emailError, this.passwordError});
}

class LoginLoading extends LoginState {
  const LoginLoading();
}

/// El backend rechazó el inicio de sesión; [message] viene de
/// `messageForFailure`.
class LoginError extends LoginState {
  final String message;
  const LoginError(this.message);
}

class LoginSuccess extends LoginState {
  const LoginSuccess();
}
