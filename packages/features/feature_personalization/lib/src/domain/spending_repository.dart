import 'package:core_errors/core_errors.dart';

import 'spending_summary.dart';

abstract interface class SpendingRepository {
  /// Resumen de los últimos [months] meses. Éxito con `summary` nulo = no hay
  /// movimientos (estado vacío).
  Future<({SpendingSummary? summary, Failure? failure})> getSpendingSummary({
    required int months,
  });
}
