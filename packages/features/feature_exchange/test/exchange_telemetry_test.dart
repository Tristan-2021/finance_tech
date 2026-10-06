import 'dart:io';

import 'package:core_storage/core_storage.dart';
import 'package:core_telemetry/core_telemetry.dart';
import 'package:feature_exchange/src/data/cached_exchange_rate_repository.dart';
import 'package:feature_exchange/src/data/exchange_rate_remote_data_source.dart';
import 'package:feature_exchange/src/data/exchange_rate_repository_impl.dart';
import 'package:feature_exchange/src/domain/exchange_rate.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTelemetry implements Telemetry {
  final events = <({String name, Map<String, Object?> params})>[];
  final traces = <String>[];

  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) =>
      events.add((name: name, params: params));

  @override
  void recordError(Object error, StackTrace stack, {bool fatal = false, String? reason}) {}

  @override
  void setSegment(String? segment) {}

  @override
  Future<T> trace<T>(String name, Future<T> Function() action) {
    traces.add(name);
    return action();
  }

  List<String> get names => events.map((e) => e.name).toList();
}

class _FakeCache implements CacheStore {
  final entries = <String, CacheEntry>{};

  @override
  Future<CacheEntry?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, String json) async =>
      entries[key] = CacheEntry(value: json, savedAt: DateTime.utc(2026, 10, 5, 12));

  @override
  Future<void> clear() async => entries.clear();

  @override
  Future<void> bindOwner(String ownerId) async {}
}

class _FakeRemote implements ExchangeRateRemoteDataSource {
  Object? error;

  @override
  Future<ExchangeRate> fetchRate({required String from, required String to}) async {
    if (error != null) throw error!;
    return ExchangeRate(
      base: from,
      target: to,
      rateMicros: 1120400,
      date: DateTime.utc(2026, 10, 5),
    );
  }
}

void main() {
  late _FakeTelemetry telemetry;
  late _FakeRemote remote;
  late CachedExchangeRateRepository repo;

  setUp(() {
    telemetry = _FakeTelemetry();
    remote = _FakeRemote();
    repo = CachedExchangeRateRepository(
      ExchangeRateRepositoryImpl(remote, telemetry: telemetry),
      _FakeCache(),
      telemetry: telemetry,
    );
  });

  Future<void> load() => repo.getRate(from: 'EUR', to: 'USD');

  test('con red: mide la carga y no emite eventos de degradación', () async {
    await load();
    expect(telemetry.traces, ['load_exchange_rate']);
    expect(telemetry.events, isEmpty);
  });

  test('sin red y con caché: retry_exhausted y cache_served', () async {
    await load(); // guarda la copia
    remote.error = const SocketException('sin conexión');

    await load();

    expect(telemetry.names, ['retry_exhausted', 'cache_served']);
    expect(telemetry.events.first.params, {'source': 'exchange', 'code': 'network'});
    expect(telemetry.events.last.params, {'source': 'exchange'});
  });

  test('sin red y sin caché: solo retry_exhausted', () async {
    remote.error = const SocketException('sin conexión');
    await load();
    expect(telemetry.names, ['retry_exhausted']);
  });

  test('una respuesta inválida no es un fallo de red: no emite retry_exhausted', () async {
    remote.error = const FormatException('respuesta rara');
    await load();
    expect(telemetry.names, isNot(contains('retry_exhausted')));
  });

  test('solo se usan claves permitidas y valores fijos', () async {
    await load();
    remote.error = const SocketException('sin conexión');
    await load();

    for (final event in telemetry.events) {
      expect(TelemetrySanitizer.allowedKeys, containsAll(event.params.keys));
      final values = event.params.values.join(' ');
      for (final secret in ['1.12', '1120400', 'EUR', 'USD', '@']) {
        expect(values, isNot(contains(secret)), reason: event.name);
      }
    }
  });
}
