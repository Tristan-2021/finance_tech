import 'package:core_errors/core_errors.dart';

import 'transaction.dart';

abstract class TransactionRepository {
  /// Movimientos de [accountId], del más reciente al más antiguo.
  /// Paginación por posición: se omiten [offset] filas y se leen hasta [limit].
  Future<({List<Transaction>? transactions, Failure? failure})> getTransactions({
    required String accountId,
    required int offset,
    required int limit,
  });
}
