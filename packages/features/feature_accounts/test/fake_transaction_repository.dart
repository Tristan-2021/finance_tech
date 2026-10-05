import 'package:core_errors/core_errors.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/domain/transaction_repository.dart';

/// Movimiento de prueba `i`: pares son ingresos, impares egresos; el monto
/// crece con `i` y la fecha retrocede un minuto por posición.
Transaction makeTx(int i, {String accountId = 'a1'}) => Transaction(
  id: 't$i',
  accountId: accountId,
  type: i.isEven ? TransactionType.credit : TransactionType.debit,
  amountCents: 100 * (i + 1),
  balanceAfterCents: 50000,
  createdAt: DateTime.utc(2026, 10, 4, 12).subtract(Duration(minutes: i)),
  category: 'comida',
  description: 'Mov $i',
);

/// Repositorio falso que pagina [all] con offset/limit y registra las llamadas.
class FakeTransactionRepository implements TransactionRepository {
  List<Transaction> all = [];
  Failure? failure;
  final calls = <({String accountId, int offset, int limit})>[];

  @override
  Future<({List<Transaction>? transactions, Failure? failure})> getTransactions({
    required String accountId,
    required int offset,
    required int limit,
  }) async {
    calls.add((accountId: accountId, offset: offset, limit: limit));
    if (failure != null) return (transactions: null, failure: failure);
    return (
      transactions: all.skip(offset).take(limit).toList(),
      failure: null,
    );
  }
}
