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

  // Registro: comunes
  static const continueAction = 'Continuar';
  static const backAction = 'Atrás';
  static const createAccountAction = 'Crear cuenta';
  static const haveAccount = 'Ya tengo una cuenta';

  // Registro: paso 1
  static const registerStep1Title = 'Crea tu cuenta';
  static const registerStep1Subtitle =
      'Empecemos con tu correo y una contraseña';
  static const passwordHint = 'Mínimo 8 caracteres';
  static const passwordTooShort =
      'La contraseña debe tener al menos 8 caracteres';

  // Registro: paso 2
  static const registerStep2Title = 'Cuéntanos sobre ti';
  static const registerStep2Subtitle =
      'Necesitamos tu nombre y tu fecha de nacimiento';
  static const fullNameLabel = 'Nombre completo';
  static const fullNameRequired = 'Escribe tu nombre completo';
  static const birthDateLabel = 'Fecha de nacimiento';
  static const birthDatePick = 'elegir';
  static const birthDateHelp = 'Selecciona tu fecha de nacimiento';
  static const birthDateRequired = 'Selecciona tu fecha de nacimiento';
  static const birthDateInvalid = 'Selecciona una fecha válida';
  static const underAge = 'Debes ser mayor de 18 años para crear una cuenta';

  // Registro: paso 3
  static const registerStep3Title = '¿Para qué usarás tu cuenta?';
  static const registerStep3Subtitle = 'Elige la opción que más te represente';
  static const usageRequired = 'Elige para qué usarás tu cuenta';
  static const usageSave = 'Ahorrar';
  static const usageDaily = 'Gastos del día a día';
  static const usageRemittances = 'Recibir remesas';
  static const usageServices = 'Pagar servicios';
  static const usageOptions = [
    usageSave,
    usageDaily,
    usageRemittances,
    usageServices,
  ];

  // Registro: sin sesión inmediata
  static const confirmEmail = 'Revisa tu correo para confirmar tu cuenta';
  static const goToLogin = 'Ir a iniciar sesión';
}
