import 'package:feature_personalization/feature_personalization.dart';
import 'package:feature_personalization/src/data/spending_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _row(String month, String category, Object total) => {
  'month': month,
  'category': category,
  'total': total,
};

void main() {
  group('parseAmountToCents', () {
    test('enteros, decimales sin ceros finales y texto', () {
      expect(parseAmountToCents(12), 1200);
      expect(parseAmountToCents(12.3), 1230);
      expect(parseAmountToCents(1250.75), 125075);
      expect(parseAmountToCents('0.05'), 5);
      expect(parseAmountToCents('7'), 700);
    });

    test('trunca más de dos decimales y acepta negativos', () {
      expect(parseAmountToCents('1.239'), 123);
      expect(parseAmountToCents('-2.5'), -250);
    });

    test('valores inválidos → null', () {
      expect(parseAmountToCents(null), isNull);
      expect(parseAmountToCents('abc'), isNull);
      expect(parseAmountToCents(''), isNull);
      expect(parseAmountToCents(true), isNull);
    });
  });

  group('computeSpendingSummary', () {
    final now = DateTime(2026, 10, 5);

    test('sin filas → null', () {
      expect(computeSpendingSummary(const [], now), isNull);
    });

    test('suma mes actual, categoría top y compara con el anterior', () {
      final summary = computeSpendingSummary([
        _row('2026-10-01', 'comida', 30.5),
        _row('2026-10-01', 'ocio', 10),
        _row('2026-10-01', 'comida', 9.5),
        _row('2026-09-01', 'comida', 100),
      ], now)!;
      expect(summary.totalCents, 5000);
      expect(summary.topCategory, 'comida');
      expect(summary.topCategoryCents, 4000);
      expect(summary.previousTotalCents, 10000);
      expect(summary.changeCents, -5000);
      expect(summary.changePercent, -50);
    });

    test('enero compara con diciembre del año anterior', () {
      final summary = computeSpendingSummary([
        _row('2026-01-01', 'otros', 20),
        _row('2025-12-01', 'otros', 10),
      ], DateTime(2026, 1, 15))!;
      expect(summary.totalCents, 2000);
      expect(summary.previousTotalCents, 1000);
      expect(summary.changePercent, 100);
    });

    test('sin gasto este mes pero sí el anterior', () {
      final summary = computeSpendingSummary([
        _row('2026-09-01', 'comida', 40),
      ], now)!;
      expect(summary.totalCents, 0);
      expect(summary.topCategory, isNull);
      expect(summary.changePercent, -100);
    });

    test('sin mes anterior no hay variación', () {
      final summary = computeSpendingSummary([
        _row('2026-10-01', 'comida', 5),
      ], now)!;
      expect(summary.previousTotalCents, isNull);
      expect(summary.changeCents, isNull);
      expect(summary.changePercent, isNull);
    });

    test('filas inválidas y meses fuera de rango se ignoran', () {
      final summary = computeSpendingSummary([
        _row('2026-10-01', 'comida', 5),
        {'month': 3, 'category': 'x', 'total': 9},
        _row('2026-10-01', 'ocio', 'no-numero'),
        _row('2026-07-01', 'ocio', 999),
      ], now)!;
      expect(summary.totalCents, 500);
      expect(summary.previousTotalCents, isNull);
    });

    test('mes anterior en cero: porcentaje null (sin dividir por cero)', () {
      const summary = SpendingSummary(
        totalCents: 100,
        topCategory: 'x',
        topCategoryCents: 100,
        previousTotalCents: 0,
      );
      expect(summary.changeCents, 100);
      expect(summary.changePercent, isNull);
    });
  });
}
