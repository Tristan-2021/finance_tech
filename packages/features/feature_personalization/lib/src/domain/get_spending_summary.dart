import 'package:core_errors/core_errors.dart';

import 'spending_repository.dart';
import 'spending_summary.dart';

class GetSpendingSummary {
  final SpendingRepository _repository;
  const GetSpendingSummary(this._repository);

  Future<({SpendingSummary? summary, Failure? failure})> call({
    int months = 2,
  }) => _repository.getSpendingSummary(months: months);
}
