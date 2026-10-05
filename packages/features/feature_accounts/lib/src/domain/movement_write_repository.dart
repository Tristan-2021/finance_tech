import 'package:core_errors/core_errors.dart';

import 'transaction_type.dart';

/// Escritura de movimientos (función de demostración: en un banco real los
/// genera el núcleo bancario). Es una interfaz aparte de [TransactionRepository]
/// para no ampliar la de lectura.
abstract class MovementWriteRepository {
  /// Registra el movimiento. `null` si salió bien. [amountCents] es positivo; el
  /// sentido lo da [type].
  Future<Failure?> addMovement({
    required String accountId,
    required TransactionType type,
    required int amountCents,
    required String category,
    required String description,
  });
}
