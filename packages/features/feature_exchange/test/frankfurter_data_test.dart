import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:feature_exchange/src/data/exchange_rate_remote_data_source.dart';
import 'package:feature_exchange/src/data/exchange_rate_repository_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

const _ok =
    '{"amount":1.0,"base":"EUR","date":"2026-10-05","rates":{"USD":1.1204}}';

ExchangeRateRepositoryImpl _repo(http.Client client) =>
    ExchangeRateRepositoryImpl(FrankfurterDataSource(client));

void main() {
  test('pide la URL correcta y lee tasa y fecha', () async {
    late Uri requested;
    final client = MockClient((request) async {
      requested = request.url;
      return http.Response(_ok, 200);
    });

    final result = await _repo(client).getRate(from: 'EUR', to: 'USD');

    expect(requested.path, '/v1/latest');
    expect(requested.queryParameters, {'base': 'EUR', 'symbols': 'USD'});
    expect(result.failure, isNull);
    expect(result.cachedAt, isNull);
    expect(result.rate!.rateMicros, 1120400);
    expect(result.rate!.date, DateTime.parse('2026-10-05'));
  });

  group('respuestas inválidas devuelven Failure', () {
    Future<String?> codeFor(String body, [int status = 200]) async {
      final client = MockClient((_) async => http.Response(body, status));
      return (await _repo(client).getRate(from: 'EUR', to: 'USD')).failure?.code;
    }

    test('JSON corrupto', () async => expect(await codeFor('<html>'), 'unknown'));

    test('tasa ausente', () async {
      expect(
        await codeFor('{"base":"EUR","date":"2026-10-05","rates":{}}'),
        'unknown',
      );
    });

    test('tasa no numérica o cero', () async {
      expect(
        await codeFor('{"base":"EUR","date":"2026-10-05","rates":{"USD":"x"}}'),
        'unknown',
      );
      expect(
        await codeFor('{"base":"EUR","date":"2026-10-05","rates":{"USD":0}}'),
        'unknown',
      );
    });

    test('fecha ausente o base distinta', () async {
      expect(await codeFor('{"base":"EUR","rates":{"USD":1.1}}'), 'unknown');
      expect(
        await codeFor('{"base":"GBP","date":"2026-10-05","rates":{"USD":1.1}}'),
        'unknown',
      );
    });

    test('error HTTP 404', () async => expect(await codeFor('{}', 404), 'network'));
  });

  test('sin red devuelve Failure de red', () async {
    final client = MockClient((_) async => throw const SocketException('sin red'));
    final result = await _repo(client).getRate(from: 'EUR', to: 'USD');
    expect(result.rate, isNull);
    expect(result.failure?.code, 'network');
  });

  test('se recupera por los reintentos: 503 y luego 200', () async {
    var calls = 0;
    final inner = MockClient((_) async {
      calls++;
      return calls == 1 ? http.Response('', 503) : http.Response(_ok, 200);
    });
    final retrying = buildRetryClient(inner, (_) => Duration.zero);

    final result = await _repo(retrying).getRate(from: 'EUR', to: 'USD');

    expect(calls, 2);
    expect(result.failure, isNull);
    expect(result.rate!.rateMicros, 1120400);
  });
}
