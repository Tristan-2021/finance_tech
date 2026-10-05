/// Textos del shell. Los mensajes por `Failure` salen de `messageForFailure`.
abstract final class AppStrings {
  static const appTitle = 'Banco Digital';

  // Navegación
  static const tabHome = 'Inicio';
  static const tabAccount = 'Cuenta';
  static String greeting(String name) => 'Hola, $name';

  // Puerta de perfil (mientras llega el nombre y el segmento)
  static const signOutAction = 'Cerrar sesión';

  // Configuración faltante
  static const configErrorTitle = 'Falta configurar la app';
}
