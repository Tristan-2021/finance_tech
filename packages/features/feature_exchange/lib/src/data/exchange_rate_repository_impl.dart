import 'package:core_network/core_network.dart';
import 'package:core_telemetry/core_telemetry.dart';

import '../domain/exchange_rate_repository.dart';
import 'exchange_rate_remote_data_source.dart';

/// Mide la llamada remota con la traza `load_exchange_rate` y, si falla por red
/// (reintentos agotados), emite `retry_exhausted` con `source: exchange`.
class ExchangeRateRepositoryImpl implements ExchangeRateRepository {
  final ExchangeRateRemoteDataSource _remote;
  final Telemetry _telemetry;
  const ExchangeRateRepositoryImpl(
    this._remote, {
    this._telemetry = const NoopTelemetry(),
  });

  @override
  Future<RateResult> getRate({
    required String from,
    required String to,
  }) async {
    try {
      final rate = await _telemetry.trace(
        'load_exchange_rate',
        () => _remote.fetchRate(from: from, to: to),
      );
      return (rate: rate, cachedAt: null, failure: null);
    } catch (e) {
      final failure = mapToFailure(e);
      if (failure.code == 'network') {
        _telemetry.logEvent('retry_exhausted', {
          'source': 'exchange',
          'code': failure.code,
        });
      }
      return (rate: null, cachedAt: null, failure: failure);
    }
  }
}
