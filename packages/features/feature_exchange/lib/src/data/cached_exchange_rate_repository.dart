import 'dart:convert';

import 'package:core_storage/core_storage.dart';
import 'package:core_telemetry/core_telemetry.dart';

import '../domain/exchange_rate.dart';
import '../domain/exchange_rate_repository.dart';

/// *Cache-then-network*: con red guarda la tasa; si el servicio no responde
/// (`network` o `unknown`), sirve la última guardada marcada con `cachedAt`.
/// Sin copia y sin red devuelve el fallo. Un fallo de la propia caché nunca
/// rompe la carga.
class CachedExchangeRateRepository implements ExchangeRateRepository {
  final ExchangeRateRepository _remote;
  final CacheStore _cache;
  final Telemetry _telemetry;

  /// Emite `cache_served` (`source: exchange`) cuando sirve la copia guardada.
  const CachedExchangeRateRepository(
    this._remote,
    this._cache, {
    this._telemetry = const NoopTelemetry(),
  });

  static String cacheKey(String from, String to) => 'exchange_rate_${from}_$to';

  @override
  Future<RateResult> getRate({
    required String from,
    required String to,
  }) async {
    final result = await _remote.getRate(from: from, to: to);

    final rate = result.rate;
    if (rate != null) {
      await _save(rate);
      return result;
    }

    final code = result.failure?.code;
    if (code == 'network' || code == 'unknown') {
      final cached = await _load(from, to);
      if (cached != null) {
        _telemetry.logEvent('cache_served', {'source': 'exchange'});
        return cached;
      }
    }
    return result;
  }

  Future<void> _save(ExchangeRate rate) async {
    try {
      await _cache.write(
        cacheKey(rate.base, rate.target),
        jsonEncode({
          'base': rate.base,
          'target': rate.target,
          'rateMicros': rate.rateMicros,
          'date': rate.date.toIso8601String(),
        }),
      );
    } catch (_) {
      // Sin caché la app sigue funcionando.
    }
  }

  Future<RateResult?> _load(String from, String to) async {
    try {
      final entry = await _cache.read(cacheKey(from, to));
      if (entry == null) return null;
      final json = jsonDecode(entry.value) as Map<String, Object?>;
      final rate = ExchangeRate(
        base: json['base']! as String,
        target: json['target']! as String,
        rateMicros: json['rateMicros']! as int,
        date: DateTime.parse(json['date']! as String),
      );
      return (rate: rate, cachedAt: entry.savedAt, failure: null);
    } catch (_) {
      return null; // copia ilegible: se trata como si no existiera
    }
  }
}
