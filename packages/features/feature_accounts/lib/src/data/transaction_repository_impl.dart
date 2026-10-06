import 'package:core_errors/core_errors.dart';
import 'package:core_network/core_network.dart';
import 'package:core_telemetry/core_telemetry.dart';

import '../domain/transaction.dart';
import '../domain/transaction_repository.dart';
import '../domain/transaction_type.dart';
import 'money_parser.dart';
import 'transactions_remote_data_source.dart';

/// Mide la llamada remota con la traza `load_movements` y, si falla por red
/// (reintentos agotados), emite `retry_exhausted` con `source: movements`.
class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionsRemoteDataSource _remote;
  final Telemetry _telemetry;
  const TransactionRepositoryImpl(
    this._remote, {
    this._telemetry = const NoopTelemetry(),
  });

  @override
  Future<({List<Transaction>? transactions, Failure? failure})> getTransactions({
    required String accountId,
    required int offset,
    required int limit,
  }) async {
    if (offset < 0 || limit <= 0) {
      return (
        transactions: null,
        failure: const Failure('Paginación inválida', 'invalid_input'),
      );
    }
    try {
      final rows = await _telemetry.trace(
        'load_movements',
        () => _remote.fetchTransactions(
          accountId: accountId,
          offset: offset,
          limit: limit,
        ),
      );
      final transactions = rows.map(_toTransaction).toList();
      return (transactions: transactions, failure: null);
    } catch (e) {
      final failure = mapToFailure(e);
      if (failure.code == 'network') {
        _telemetry.logEvent('retry_exhausted', {
          'source': 'movements',
          'code': failure.code,
        });
      }
      return (transactions: null, failure: failure);
    }
  }

  Transaction _toTransaction(Map<String, dynamic> row) => Transaction(
    id: row['id'] as String,
    accountId: row['account_id'] as String,
    type: _parseType(row['type']),
    category: row['category'] as String?,
    description: row['description'] as String?,
    amountCents: parseCents(row['amount']),
    balanceAfterCents: parseCents(row['balance_after']),
    createdAt: DateTime.parse(row['created_at'] as String),
  );

  TransactionType _parseType(Object? value) => switch (value) {
    'credit' => TransactionType.credit,
    'debit' => TransactionType.debit,
    _ => throw FormatException('Tipo de movimiento desconocido: $value'),
  };
}
