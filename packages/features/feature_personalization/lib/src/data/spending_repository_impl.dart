import 'package:core_errors/core_errors.dart';
import 'package:core_network/core_network.dart';

import '../domain/spending_repository.dart';
import '../domain/spending_summary.dart';
import 'spending_calculator.dart';

class SpendingRepositoryImpl implements SpendingRepository {
  final SupabaseClient _client;
  final DateTime Function() _now;

  SpendingRepositoryImpl(this._client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  @override
  Future<({SpendingSummary? summary, Failure? failure})> getSpendingSummary({
    required int months,
  }) async {
    try {
      final response = await _client.rpc(
        'spending_by_category',
        params: {'p_months': months},
      );
      final rows = <Map<String, Object?>>[
        if (response is List<Object?>)
          for (final row in response)
            if (row is Map<String, Object?>) row,
      ];
      return (summary: computeSpendingSummary(rows, _now()), failure: null);
    } catch (e) {
      return (summary: null, failure: mapToFailure(e));
    }
  }
}
