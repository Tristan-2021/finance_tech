/// Textos de la pantalla de inicio personalizada.
abstract final class PersonalizationStrings {
  static const spendingTitle = 'Tus gastos del mes';
  static const spendingEmpty = 'Aún no tienes gastos este mes.';
  static const spendingRetry = 'Reintentar';
  static const rateTitle = 'Tipo de cambio de referencia';
  static const rateNote = 'Valor de referencia, no es una cotización en vivo.';

  static String topCategory(String category, String amount) =>
      'Categoría con más gasto: $category ($amount)';

  static String change(int percent) {
    if (percent == 0) return 'Igual que el mes anterior';
    return percent > 0
        ? '$percent% más que el mes anterior'
        : '${-percent}% menos que el mes anterior';
  }
}
