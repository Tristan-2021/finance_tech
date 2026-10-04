/// Textos de interfaz del feature. Los mensajes por `Failure` salen de
/// `messageForFailure` (core_ui), no de aquí.
abstract final class OnboardingStrings {
  // Comunes
  static const emailLabel = 'Correo electrónico';
  static const passwordLabel = 'Contraseña';
  static const emailRequired = 'Escribe tu correo';
  static const emailInvalid = 'Escribe un correo válido';
  static const passwordRequired = 'Escribe tu contraseña';

  // Login
  static const loginTitle = 'Inicia sesión';
  static const loginSubtitle = 'Bienvenido de nuevo';
  static const loginAction = 'Iniciar sesión';
  static const goToRegister = 'Crear cuenta';
}
