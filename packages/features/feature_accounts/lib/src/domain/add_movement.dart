import 'package:core_errors/core_errors.dart';

import 'movement_write_repository.dart';
import 'transaction_type.dart';

class AddMovement {
  final MovementWriteRepository _repository;
  const AddMovement(this._repository);

  Future<Failure?> call({
    required String accountId,
    required TransactionType type,
    required int amountCents,
    required String category,
    required String description,
  }) {
    return _repository.addMovement(
      accountId: accountId,
      type: type,
      amountCents: amountCents,
      category: category,
      description: description,
    );
  }
}
