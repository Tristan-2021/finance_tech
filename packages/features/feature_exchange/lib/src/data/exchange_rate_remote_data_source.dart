import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/exchange_rate.dart';
import 'rate_parsing.dart';

/// Origen de las tasas. La app depende de esta interfaz (patrón *Adapter*):
/// cambiar de proveedor es escribir otra implementación.
abstract interface class ExchangeRateRemoteDataSource {
  /// Lanza si no hay red, el servicio falla o la respuesta es inválida.
  Future<ExchangeRate> fetchRate({required String from, required String to});
}

/// Frankfurter: tasas de referencia del Banco Central Europeo, sin clave.
/// `GET {baseUrl}/v1/latest?base=EUR&symbols=USD` responde
/// `{"amount":1.0,"base":"EUR","date":"2026-10-05","rates":{"USD":1.1204}}`.
/// Las tasas son diarias, no en tiempo real.
class FrankfurterDataSource implements ExchangeRateRemoteDataSource {
  static const defaultBaseUrl = 'https://api.frankfurter.dev';

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  FrankfurterDataSource(
    this._client, {
    this.baseUrl = defaultBaseUrl,
    this.timeout = const Duration(seconds: 10),
  });

  @override
  Future<ExchangeRate> fetchRate({
    required String from,
    required String to,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/v1/latest',
    ).replace(queryParameters: {'base': from, 'symbols': to});
    final response = await _client.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      throw http.ClientException('HTTP ${response.statusCode}', uri);
    }
    return _parse(response.body, from, to);
  }

  ExchangeRate _parse(String body, String from, String to) {
    final Object? json = jsonDecode(body);
    if (json is! Map<String, Object?>) {
      throw const FormatException('respuesta inesperada');
    }
    final rates = json['rates'];
    final date = json['date'];
    final micros = rates is Map<String, Object?>
        ? parseRateToMicros(rates[to])
        : null;
    final parsedDate = date is String ? DateTime.tryParse(date) : null;
    if (json['base'] != from || micros == null || parsedDate == null) {
      throw const FormatException('tasa ausente o inválida');
    }
    return ExchangeRate(
      base: from,
      target: to,
      rateMicros: micros,
      date: parsedDate,
    );
  }
}
