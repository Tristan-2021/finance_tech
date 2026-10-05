import 'dart:io';
import 'dart:math';

import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Devuelve los números en el orden dado (para decidir qué peticiones fallan).
class ScriptedRandom implements Random {
  final List<int> values;
  ScriptedRandom(this.values);

  @override
  int nextInt(int max) => values.removeAt(0);

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  bool nextBool() => throw UnimplementedError();
}

Duration noDelay(int _) => Duration.zero;

/// Anota el número de reintentos cada vez que el notificador avisa.
List<int> trackRetries(NetworkStatusNotifier status) {
  final seen = <int>[];
  status.addListener(() => seen.add(status.retryCount));
  return seen;
}

void main() {
  late DebugNetworkConfig config;
  late int innerCalls;
  late MockClient inner;

  setUp(() {
    config = DebugNetworkConfig();
    innerCalls = 0;
    inner = MockClient((_) async {
      innerCalls++;
      return http.Response('ok', 200);
    });
  });

  group('FaultInjectingClient', () {
    test('sin fallos activos deja pasar la petición', () async {
      final client = FaultInjectingClient(inner, config);
      final r = await client.get(Uri.parse('http://x'));
      expect(r.statusCode, 200);
      expect(innerCalls, 1);
    });

    test('sin conexión lanza SocketException y no llega al servidor', () async {
      config.offline = true;
      final client = FaultInjectingClient(inner, config);

      await expectLater(
        client.get(Uri.parse('http://x')),
        throwsA(isA<SocketException>()),
      );
      expect(innerCalls, 0);
    });

    test('aplica la latencia configurada antes de la petición', () async {
      final waits = <Duration>[];
      config.latency = const Duration(seconds: 3);
      final client = FaultInjectingClient(
        inner,
        config,
        wait: (d) async {
          waits.add(d);
        },
      );

      await client.get(Uri.parse('http://x'));
      expect(waits, [const Duration(seconds: 3)]);
      expect(innerCalls, 1);
    });

    test('sin latencia no espera, y sin conexión tampoco', () async {
      final waits = <Duration>[];
      final client = FaultInjectingClient(
        inner,
        config,
        wait: (d) async {
          waits.add(d);
        },
      );
      await client.get(Uri.parse('http://x'));

      config
        ..latency = const Duration(seconds: 8)
        ..offline = true;
      await expectLater(
        client.get(Uri.parse('http://x')),
        throwsA(isA<SocketException>()),
      );
      expect(waits, isEmpty);
    });

    test('con 100 % responde 503 sin llegar al servidor', () async {
      config.failurePercent = 100;
      final client = FaultInjectingClient(inner, config);
      final r = await client.get(Uri.parse('http://x'));
      expect(r.statusCode, 503);
      expect(innerCalls, 0);
    });

    test('con 0 % nunca falla y ni siquiera sortea', () async {
      final client = FaultInjectingClient(
        inner,
        config,
        random: ScriptedRandom([]), // si sortea, falla el test
      );
      expect((await client.get(Uri.parse('http://x'))).statusCode, 200);
    });

    test('con 50 % falla según el sorteo', () async {
      config.failurePercent = 50;
      final client = FaultInjectingClient(
        inner,
        config,
        random: ScriptedRandom([10, 90]),
      );
      expect((await client.get(Uri.parse('http://x'))).statusCode, 503);
      expect((await client.get(Uri.parse('http://x'))).statusCode, 200);
    });
  });

  group('con reintentos (la inyección queda dentro del RetryClient)', () {
    test('sin conexión: reintenta 3 veces y se rinde con SocketException', () async {
      config.offline = true;
      final status = NetworkStatusNotifier();
      final seen = trackRetries(status);
      final client = buildRetryClient(
        FaultInjectingClient(inner, config),
        noDelay,
        status,
      );

      await expectLater(
        client.get(Uri.parse('http://x')),
        throwsA(isA<SocketException>()),
      );
      expect(seen, [1, 2, 3, 0]);
      expect(status.isRetrying, isFalse);
      expect(innerCalls, 0);
    });

    test('un 503 forzado una vez y luego éxito se recupera', () async {
      config.failurePercent = 50;
      final status = NetworkStatusNotifier();
      final seen = trackRetries(status);
      final client = buildRetryClient(
        FaultInjectingClient(inner, config, random: ScriptedRandom([10, 90])),
        noDelay,
        status,
      );

      final r = await client.get(Uri.parse('http://x'));
      expect(r.statusCode, 200);
      expect(innerCalls, 1);
      expect(seen, [1, 0]);
    });

    test('503 siempre: se rinde tras el máximo de reintentos', () async {
      config.failurePercent = 100;
      final status = NetworkStatusNotifier();
      final seen = trackRetries(status);
      final client = buildRetryClient(
        FaultInjectingClient(inner, config),
        noDelay,
        status,
      );

      final r = await client.get(Uri.parse('http://x'));
      expect(r.statusCode, 503);
      expect(seen, [1, 2, 3, 0]);
    });

    test('al restablecer la configuración la red vuelve a la normalidad', () async {
      config.offline = true;
      final client = buildRetryClient(
        FaultInjectingClient(inner, config),
        noDelay,
      );
      await expectLater(
        client.get(Uri.parse('http://x')),
        throwsA(isA<SocketException>()),
      );

      config.reset();
      expect((await client.get(Uri.parse('http://x'))).statusCode, 200);
    });
  });

  group('DebugNetworkConfig', () {
    test('avisa solo cuando algo cambia', () {
      var notified = 0;
      config.addListener(() => notified++);

      config.offline = true;
      config.offline = true; // sin cambio
      config.latency = const Duration(seconds: 1);
      config.failurePercent = 30;

      expect(notified, 3);
    });

    test('el porcentaje se limita entre 0 y 100', () {
      config.failurePercent = 250;
      expect(config.failurePercent, 100);
      config.failurePercent = -5;
      expect(config.failurePercent, 0);
    });

    test('reset vuelve a los valores por defecto', () {
      config
        ..offline = true
        ..latency = const Duration(seconds: 8)
        ..failurePercent = 40;
      expect(config.isDefault, isFalse);

      config.reset();

      expect(config.isDefault, isTrue);
      expect(config.offline, isFalse);
      expect(config.latency, Duration.zero);
      expect(config.failurePercent, 0);
    });
  });

  group('NetworkStatusNotifier', () {
    test('con varias peticiones, sigue reintentando hasta que terminan todas', () {
      final status = NetworkStatusNotifier();
      status
        ..requestStarted()
        ..requestStarted()
        ..retryStarted();
      expect(status.isRetrying, isTrue);

      status.requestFinished();
      expect(status.isRetrying, isTrue);

      status.requestFinished();
      expect(status.isRetrying, isFalse);
      expect(status.retryCount, 0);
    });
  });
}
