import 'package:core_errors/core_errors.dart';

/// Mensaje legible para el usuario según el `Failure.code`.
String messageForFailure(Failure failure) {
  return switch (failure.code) {
    'network' => 'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
    'auth' => 'Correo o contraseña incorrectos.',
    'rls_denied' => 'No tienes permiso para ver esta información.',
    'insufficient_funds' => 'Saldo insuficiente.',
    _ => 'Algo salió mal. Inténtalo de nuevo.',
  };
}
