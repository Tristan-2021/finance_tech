import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'debug_network_config.dart';

/// Cliente que envuelve a otro e inyecta fallos según [DebugNetworkConfig]:
/// sin conexión, latencia artificial y 503 forzados. Va **dentro** del
/// `RetryClient`, así los reintentos se ejercitan de verdad.
class FaultInjectingClient extends http.BaseClient {
  final http.Client _inner;
  final DebugNetworkConfig _config;
  final Random _random;
  final Future<void> Function(Duration) _wait;

  FaultInjectingClient(
    this._inner,
    this._config, {
    Random? random,
    Future<void> Function(Duration)? wait,
  }) : _random = random ?? Random(),
       _wait = wait ?? ((duration) => Future<void>.delayed(duration));

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_config.offline) {
      throw const SocketException('Sin conexión (modo depuración)');
    }

    final latency = _config.latency;
    if (latency > Duration.zero) await _wait(latency);

    final percent = _config.failurePercent;
    if (percent > 0 && _random.nextInt(100) < percent) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('Fallo inyectado (modo depuración)')),
        503,
        request: request,
        reasonPhrase: 'Service Unavailable',
      );
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
