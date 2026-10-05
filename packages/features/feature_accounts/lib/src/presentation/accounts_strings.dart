/// Textos de la pantalla de cuentas. Los mensajes por `Failure` salen de
/// `messageForFailure` (core_ui).
abstract final class AccountsStrings {
  static String greeting(String name) => 'Hola, $name';
  static String segmentLabel(String segment) => 'Segmento: $segment';
  static const menu = 'Menú';
  static const signOut = 'Cerrar sesión';
  static const balanceLabel = 'Saldo disponible';
  static const noAccounts = 'Aún no tienes cuentas';
}
