import 'package:core_errors/core_errors.dart';
import 'package:core_network/core_network.dart';

import '../domain/movement_amount.dart';
import '../domain/movement_write_repository.dart';
import '../domain/transaction_type.dart';
import 'movement_write_remote_data_source.dart';

class MovementWriteRepositoryImpl implements MovementWriteRepository {
  final MovementWriteRemoteDataSource _remote;
  const MovementWriteRepositoryImpl(this._remote);

  @override
  Future<Failure?> addMovement({
    required String accountId,
    required TransactionType type,
    required int amountCents,
    required String category,
    required String description,
  }) async {
    if (amountCents <= 0) {
      return const Failure('Monto inválido', 'invalid_input');
    }
    try {
      await _remote.addMovement(
        accountId: accountId,
        type: type == TransactionType.credit ? 'credit' : 'debit',
        amount: centsToDecimalString(amountCents),
        category: category,
        description: description,
      );
      return null;
    } catch (e) {
      return mapToFailure(e);
    }
  }
}
