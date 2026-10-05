/// Resumen de gastos del mes actual. Todo en centavos (`int`), sin `double`.
class SpendingSummary {
  /// Gasto total del mes actual.
  final int totalCents;

  /// Categoría con más gasto este mes (`null` si no hubo gastos este mes).
  final String? topCategory;
  final int topCategoryCents;

  /// Gasto total del mes anterior; `null` si no hay datos de ese mes.
  final int? previousTotalCents;

  const SpendingSummary({
    required this.totalCents,
    required this.topCategory,
    required this.topCategoryCents,
    required this.previousTotalCents,
  });

  /// Diferencia con el mes anterior en centavos (positiva = gastaste más).
  int? get changeCents {
    final previous = previousTotalCents;
    return previous == null ? null : totalCents - previous;
  }

  /// Variación porcentual con aritmética entera (se trunca hacia cero).
  /// `null` si no hay mes anterior o su gasto fue cero.
  int? get changePercent {
    final previous = previousTotalCents;
    final change = changeCents;
    if (previous == null || previous == 0 || change == null) return null;
    return (change * 100) ~/ previous;
  }
}
