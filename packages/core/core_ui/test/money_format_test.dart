import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child, {ThemeData? theme, double textScale = 1}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('formatCents', () {
    test('cero', () => expect(formatCents(0), '\$0.00'));
    test('1 centavo', () => expect(formatCents(1), '\$0.01'));
    test('menos de un dólar', () {
      expect(formatCents(5), '\$0.05');
      expect(formatCents(99), '\$0.99');
    });
    test('un dólar exacto', () => expect(formatCents(100), '\$1.00'));
    test('dos decimales siempre', () => expect(formatCents(1230), '\$12.30'));
    test('separador de miles', () {
      expect(formatCents(123456), '\$1,234.56');
      expect(formatCents(100000), '\$1,000.00');
      expect(formatCents(99900), '\$999.00');
    });
    test('millones', () {
      expect(formatCents(100000000), '\$1,000,000.00');
    });
    test('máximo de numeric(14,2)', () {
      expect(formatCents(99999999999999), '\$999,999,999,999.99');
    });
    test('negativos', () {
      expect(formatCents(-100), '-\$1.00');
      expect(formatCents(-5), '-\$0.05');
      expect(formatCents(-123456), '-\$1,234.56');
    });
    test('otra moneda usa su código', () {
      expect(formatCents(100, currency: 'EUR'), 'EUR 1.00');
    });
  });

  group('formatDateEs / formatDateTimeEs', () {
    test('ejemplo del contrato', () {
      expect(formatDateEs(DateTime(2026, 5, 14)), '14 may 2026');
      expect(formatDateTimeEs(DateTime(2026, 5, 14, 9, 30)), '14 may 2026, 09:30');
    });

    test('el día no lleva cero a la izquierda', () {
      expect(formatDateEs(DateTime(2026, 3, 5)), '5 mar 2026');
    });

    test('todos los meses abreviados', () {
      const expected = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
      ];
      for (var m = 1; m <= 12; m++) {
        expect(formatDateEs(DateTime(2026, m, 10)), '10 ${expected[m - 1]} 2026');
      }
    });

    test('hora de 24 h con ceros', () {
      expect(formatDateTimeEs(DateTime(2026, 1, 2, 0, 0)), '2 ene 2026, 00:00');
      expect(formatDateTimeEs(DateTime(2026, 1, 2, 23, 59)), '2 ene 2026, 23:59');
      expect(formatDateTimeEs(DateTime(2026, 1, 2, 7, 5)), '2 ene 2026, 07:05');
    });

    test('convierte UTC a hora local', () {
      final utc = DateTime.utc(2026, 5, 14, 12, 30);
      final local = utc.toLocal();
      expect(formatDateEs(utc), formatDateEs(local));
      expect(formatDateTimeEs(utc), formatDateTimeEs(local));
    });
  });

  group('spokenAmountEs', () {
    test('plural', () {
      expect(spokenAmountEs(5000), '50 dólares con 00 centavos');
      expect(spokenAmountEs(1230), '12 dólares con 30 centavos');
      expect(spokenAmountEs(0), '0 dólares con 00 centavos');
    });
    test('singular de dólar', () {
      expect(spokenAmountEs(100), '1 dólar con 00 centavos');
      expect(spokenAmountEs(150), '1 dólar con 50 centavos');
    });
    test('singular de centavo', () {
      expect(spokenAmountEs(1), '0 dólares con 01 centavo');
      expect(spokenAmountEs(101), '1 dólar con 01 centavo');
    });
    test('sin separador de miles', () {
      expect(spokenAmountEs(123456), '1234 dólares con 56 centavos');
    });
    test('negativo', () {
      expect(spokenAmountEs(-100), 'menos 1 dólar con 00 centavos');
    });
  });

  group('AmountText', () {
    testWidgets('ingreso: signo +, color de ingreso', (tester) async {
      await tester.pumpWidget(wrap(const AmountText(cents: 5000, isCredit: true)));
      final text = tester.widget<Text>(find.text('+\$50.00'));
      expect(
        text.style?.color,
        AppTheme.light().extension<AppSemanticColors>()!.credit,
      );
    });

    testWidgets('egreso: signo −, color de egreso', (tester) async {
      await tester.pumpWidget(wrap(const AmountText(cents: 1230, isCredit: false)));
      final text = tester.widget<Text>(find.text('−\$12.30'));
      expect(
        text.style?.color,
        AppTheme.light().extension<AppSemanticColors>()!.debit,
      );
    });

    testWidgets('colores del tema oscuro', (tester) async {
      await tester.pumpWidget(
        wrap(
          theme: AppTheme.dark(),
          const AmountText(cents: 5000, isCredit: true),
        ),
      );
      final text = tester.widget<Text>(find.text('+\$50.00'));
      expect(
        text.style?.color,
        AppTheme.dark().extension<AppSemanticColors>()!.credit,
      );
    });

    testWidgets('anuncia ingreso y egreso con el monto hablado', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AmountText(cents: 5000, isCredit: true),
              AmountText(cents: 1230, isCredit: false),
            ],
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Ingreso de 50 dólares con 00 centavos'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Egreso de 12 dólares con 30 centavos'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('usa la magnitud aunque cents sea negativo', (tester) async {
      await tester.pumpWidget(wrap(const AmountText(cents: -1230, isCredit: false)));
      expect(find.text('−\$12.30'), findsOneWidget);
    });

    testWidgets('respeta el tamaño del estilo pero impone el color', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const AmountText(
            cents: 5000,
            isCredit: true,
            style: TextStyle(fontSize: 36, color: Colors.purple),
          ),
        ),
      );
      final style = tester.widget<Text>(find.text('+\$50.00')).style!;
      expect(style.fontSize, 36);
      expect(style.color, isNot(Colors.purple));
    });

    for (final theme in {
      'claro': AppTheme.light(),
      'oscuro': AppTheme.dark(),
    }.entries) {
      testWidgets('contraste del texto, tema ${theme.key}', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          wrap(
            theme: theme.value,
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AmountText(cents: 5000, isCredit: true),
                AmountText(cents: 1230, isCredit: false),
              ],
            ),
          ),
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }

    testWidgets('texto al 200 % sin desbordes', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        wrap(
          textScale: 2.0,
          const AmountText(
            cents: 99999999999999,
            isCredit: true,
            style: TextStyle(fontSize: 36),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
