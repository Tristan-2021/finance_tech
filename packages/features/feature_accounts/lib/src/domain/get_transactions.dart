import 'package:core_errors/core_errors.dart';

import 'transaction.dart';
import 'transaction_repository.dart';

class GetTransactions {
  final TransactionRepository _repository;
  const GetTransactions(this._repository);

  Future<({List<Transaction>? transactions, Failure? failure})> call(
    String accountId, {
    int offset = 0,
    int limit = 20,
  }) {
    return _repository.getTransactions(
      accountId: accountId,
      offset: offset,
      limit: limit,
    );
  }
}
