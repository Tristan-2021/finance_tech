import '../domain/exchange_rate.dart';

/// Convierte el valor numérico del JSON a una tasa escalada a 6 decimales, sin
/// operar con `double`: se toma su cadena decimal (`1.1723`, `1.17`, `2`) y se
/// separan parte entera y decimales. Más de 6 decimales se truncan.
///
/// Devuelve `null` si no es un número decimal simple y positivo (texto,
/// notación científica, cero, negativo, `null`).
int? parseRateToMicros(Object? value) {
  if (value is! num) return null;
  final match = RegExp(r'^(\d+)(?:\.(\d+))?$').firstMatch(value.toString());
  if (match == null) return null;
  final whole = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(6, '0').substring(0, 6);
  final micros = whole * ExchangeRate.rateScale + int.parse(fraction);
  return micros > 0 ? micros : null;
}
