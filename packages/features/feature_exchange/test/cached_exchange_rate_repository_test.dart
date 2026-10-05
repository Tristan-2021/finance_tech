import 'package:core_errors/core_errors.dart';
import 'package:core_storage/core_storage.dart';
import 'package:feature_exchange/src/data/cached_exchange_rate_repository.dart';
import 'package:feature_exchange/src/domain/exchange_rate.dart';
import 'package:feature_exchange/src/domain/exchange_rate_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCache implements CacheStore {
  final entries = <String, CacheEntry>{};
  Object? writeError;
  DateTime savedAt = DateTime.utc(2026, 10, 5, 12);

  @override
  Future<CacheEntry?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, String json) async {
    if (writeError != null) throw writeError!;
    entries[key] = CacheEntry(value: json, savedAt: savedAt);
  }

  @override
  Future<void> clear() async => entries.clear();

  @override
  Future<void> bindOwner(String ownerId) async {}
}

class _FakeRemote implements ExchangeRateRepository {
  Failure? failure;
  int micros = 1120400;

  @override
  Future<RateResult> getRate({required String from, required String to}) async {
    final f = failure;
    if (f != null) return (rate: null, cachedAt: null, failure: f);
    return (
      rate: ExchangeRate(
        base: from,
        target: to,
        rateMicros: micros,
        date: DateTime.utc(2026, 10, 5),
      ),
      cachedAt: null,
      failure: null,
    );
  }
}

void main() {
  late _FakeCache cache;
  late _FakeRemote remote;
  late CachedExchangeRateRepository repo;

  setUp(() {
    cache = _FakeCache();
    remote = _FakeRemote();
    repo = CachedExchangeRateRepository(remote, cache);
  });

  Future<RateResult> get() => repo.getRate(from: 'EUR', to: 'USD');

  test('con red devuelve la tasa fresca y la guarda', () async {
    final r = await get();
    expect(r.failure, isNull);
    expect(r.cachedAt, isNull);
    expect(r.rate!.rateMicros, 1120400);
    expect(cache.entries, contains(CachedExchangeRateRepository.cacheKey('EUR', 'USD')));
  });

  test('sin red sirve la última guardada, marcada con su fecha', () async {
    await get();
    remote.failure = const Failure('sin red', 'network');

    final r = await get();

    expect(r.failure, isNull);
    expect(r.rate!.rateMicros, 1120400);
    expect(r.rate!.date, DateTime.utc(2026, 10, 5));
    expect(r.cachedAt, DateTime.utc(2026, 10, 5, 12));
  });

  test('sin caché y sin red devuelve el Failure', () async {
    remote.failure = const Failure('sin red', 'network');
    final r = await get();
    expect(r.rate, isNull);
    expect(r.failure?.code, 'network');
  });

  test('se recupera solo: tras volver la red ya no es obsoleta', () async {
    await get();
    remote.failure = const Failure('sin red', 'network');
    expect((await get()).cachedAt, isNotNull);

    remote.failure = null;
    remote.micros = 1130000;
    final r = await get();

    expect(r.cachedAt, isNull);
    expect(r.rate!.rateMicros, 1130000);
  });

  test('una copia ilegible se trata como si no existiera', () async {
    cache.entries[CachedExchangeRateRepository.cacheKey('EUR', 'USD')] =
        CacheEntry(value: 'no es json', savedAt: cache.savedAt);
    remote.failure = const Failure('sin red', 'network');

    final r = await get();

    expect(r.rate, isNull);
    expect(r.failure?.code, 'network');
  });

  test('un fallo al guardar no rompe la carga', () async {
    cache.writeError = Exception('disco lleno');
    final r = await get();
    expect(r.failure, isNull);
    expect(r.rate, isNotNull);
  });

  test('un error que no es de red no se tapa con la caché', () async {
    await get();
    remote.failure = const Failure('denegado', 'rls_denied');
    final r = await get();
    expect(r.rate, isNull);
    expect(r.failure?.code, 'rls_denied');
  });
}
