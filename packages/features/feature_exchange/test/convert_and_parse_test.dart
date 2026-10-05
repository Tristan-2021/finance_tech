import 'package:feature_exchange/src/data/rate_parsing.dart';
import 'package:feature_exchange/src/domain/convert_amount.dart';
import 'package:feature_exchange/src/domain/exchange_rate.dart';
import 'package:flutter_test/flutter_test.dart';

ExchangeRate _rate(int micros) => ExchangeRate(
  base: 'EUR',
  target: 'USD',
  rateMicros: micros,
  date: DateTime(2026, 10, 5),
);

void main() {
  group('parseRateToMicros', () {
    test('decimales, enteros y pocos decimales', () {
      expect(parseRateToMicros(1.1723), 1172300);
      expect(parseRateToMicros(1.17), 1170000);
      expect(parseRateToMicros(1.1204), 1120400);
      expect(parseRateToMicros(2), 2000000);
      expect(parseRateToMicros(0.5), 500000);
    });

    test('más de 6 decimales se truncan', () {
      expect(parseRateToMicros(1.12345678), 1123456);
    });

    test('valores inválidos devuelven null', () {
      expect(parseRateToMicros(null), isNull);
      expect(parseRateToMicros('1.17'), isNull);
      expect(parseRateToMicros(0), isNull);
      expect(parseRateToMicros(-1.5), isNull);
      expect(parseRateToMicros(1e-7), isNull); // notación científica
    });
  });

  group('ConvertAmount (mitad hacia arriba, solo enteros)', () {
    const convert = ConvertAmount();

    test('conversión normal: 100.00 EUR a 1.1204', () {
      expect(convert(10000, _rate(1120400)), 11204);
    });

    test('un centavo', () {
      expect(convert(1, _rate(1120400)), 1); // 1.12 -> 1
      expect(convert(1, _rate(400000)), 0); // 0.4 -> 0
      expect(convert(1, _rate(500000)), 1); // 0.5 sube a 1
    });

    test('la mitad exacta sube', () {
      // 3 centavos * 0.5 = 1.5 -> 2
      expect(convert(3, _rate(500000)), 2);
      // 5 centavos * 0.3 = 1.5 -> 2
      expect(convert(5, _rate(300000)), 2);
    });

    test('justo debajo de la mitad baja', () {
      // 1 centavo * 0.499999 = 0.499999 -> 0
      expect(convert(1, _rate(499999)), 0);
    });

    test('cero y valores grandes', () {
      expect(convert(0, _rate(1120400)), 0);
      // 1.000.000.000,00 EUR (10^11 centavos) sin pérdida de precisión
      expect(convert(100000000000, _rate(1120400)), 112040000000);
    });

    test('un monto negativo se rechaza', () {
      expect(() => convert(-1, _rate(1120400)), throwsArgumentError);
    });
  });

  test('rateText muestra la tasa con enteros', () {
    expect(_rate(1120400).rateText, '1.120400');
    expect(_rate(2000000).rateText, '2.000000');
  });

  test('shortRateText quita ceros finales pero deja dos decimales', () {
    expect(_rate(1120400).shortRateText, '1.1204');
    expect(_rate(1170000).shortRateText, '1.17');
    expect(_rate(2000000).shortRateText, '2.00');
    expect(_rate(1123456).shortRateText, '1.123456');
  });
}
