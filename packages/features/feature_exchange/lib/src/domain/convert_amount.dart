import 'exchange_rate.dart';

/// Convierte [cents] (centavos de la moneda base) a centavos de la moneda
/// destino con aritmética entera.
///
/// Redondeo: **a la mitad hacia arriba** sobre el centavo destino
/// (`0.5` centavo sube a `1`). Fórmula: `(cents * rateMicros + 500000) ~/ 1000000`.
/// Rechaza montos negativos. Con enteros de 64 bits el límite supera los
/// 80.000 millones de dólares, muy por encima de cualquier remesa.
class ConvertAmount {
  const ConvertAmount();

  int call(int cents, ExchangeRate rate) {
    if (cents < 0) throw ArgumentError.value(cents, 'cents', 'no puede ser negativo');
    const half = ExchangeRate.rateScale ~/ 2;
    return (cents * rate.rateMicros + half) ~/ ExchangeRate.rateScale;
  }
}
