/// Textos de la pantalla de cuentas. Los mensajes por `Failure` salen de
/// `messageForFailure` (core_ui).
abstract final class AccountsStrings {
  static String greeting(String name) => 'Hola, $name';
  static String segmentLabel(String segment) => 'Segmento: $segment';
  static const menu = 'Menú';
  static const signOut = 'Cerrar sesión';
  static const balanceLabel = 'Saldo disponible';
  static const noAccounts = 'Aún no tienes cuentas';

  // Movimientos
  static const movementsTitle = 'Movimientos';
  static const noMovements = 'Aún no tienes movimientos';
  static const uncategorized = 'Sin categoría';
  static const movementFallback = 'Movimiento';
  static const loadingMore = 'Cargando más movimientos';
  static const retry = 'Reintentar';
  static String balanceAfter(String amount) => 'Saldo: $amount';

  // Conectividad
  static String staleNotice(String when) => 'Mostrando datos guardados el $when';
  static const retrying = 'Reintentando…';
}
