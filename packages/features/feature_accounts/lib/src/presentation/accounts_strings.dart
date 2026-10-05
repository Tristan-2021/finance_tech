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

  // Registrar movimiento (función de demostración)
  static const addMovement = 'Registrar movimiento';
  static const addMovementSubmit = 'Registrar';
  static const manualExpenseTitle = 'Gasto manual (demostración)';
  static const manualIncomeTitle = 'Ingreso manual (demostración)';
  static const manualExpenseDefault = 'Gasto manual';
  static const manualIncomeDefault = 'Ingreso manual';
  static const expenseLabel = 'Gasto';
  static const incomeLabel = 'Ingreso';
  static const amountLabel = 'Monto';
  static const categoryLabel = 'Categoría';
  static const descriptionLabel = 'Descripción (opcional)';
  static const descriptionTooLong = 'Máximo 80 caracteres.';
  static const demoNote =
      'Función de demostración: en un banco real los movimientos los genera '
      'el banco y no se pueden editar ni borrar.';

  static String category(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  // Conectividad
  static String staleNotice(String when) => 'Mostrando datos guardados el $when';
  static const retrying = 'Reintentando…';
}
