/// Textos del shell. Los mensajes por `Failure` salen de `messageForFailure`.
abstract final class AppStrings {
  static const appTitle = 'Banco Digital';

  // Pantalla provisional
  static String greeting(String name) => 'Hola, $name';
  static String segmentLabel(String segment) => 'Segmento: $segment';
  static const accountsPlaceholder = 'Tus cuentas aparecerán aquí';
  static const signOutAction = 'Cerrar sesión';

  // Configuración faltante
  static const configErrorTitle = 'Falta configurar la app';
}
