import 'package:core_network/core_network.dart';

import '../domain/exchange_rate_repository.dart';
import 'exchange_rate_remote_data_source.dart';

class ExchangeRateRepositoryImpl implements ExchangeRateRepository {
  final ExchangeRateRemoteDataSource _remote;
  const ExchangeRateRepositoryImpl(this._remote);

  @override
  Future<RateResult> getRate({
    required String from,
    required String to,
  }) async {
    try {
      final rate = await _remote.fetchRate(from: from, to: to);
      return (rate: rate, cachedAt: null, failure: null);
    } catch (e) {
      return (rate: null, cachedAt: null, failure: mapToFailure(e));
    }
  }
}
