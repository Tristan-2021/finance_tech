import 'package:core_errors/core_errors.dart';
import 'package:feature_exchange/src/domain/amount_input.dart';
import 'package:feature_exchange/src/domain/exchange_rate.dart';
import 'package:feature_exchange/src/domain/exchange_rate_repository.dart';
import 'package:feature_exchange/src/domain/get_rate.dart';
import 'package:feature_exchange/src/presentation/exchange_cubit.dart';
import 'package:feature_exchange/src/presentation/exchange_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepository implements ExchangeRateRepository {
  Failure? failure;
  DateTime? cachedAt;
  int calls = 0;

  @override
  Future<RateResult> getRate({required String from, required String to}) async {
    calls++;
    final f = failure;
    if (f != null) return (rate: null, cachedAt: null, failure: f);
    return (
      rate: ExchangeRate(
        base: from,
        target: to,
        rateMicros: 1120400,
        date: DateTime(2026, 10, 5),
      ),
      cachedAt: cachedAt,
      failure: null,
    );
  }
}

void main() {
  late _FakeRepository repository;

  Future<void> pumpCard(WidgetTester tester) async {
    final cubit = ExchangeCubit(GetRate(repository), from: 'EUR', to: 'USD');
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ExchangeView(cubit: cubit)),
        ),
      ),
    );
  }

  setUp(() => repository = _FakeRepository());

  group('parseAmountInput', () {
    test('acepta coma o punto y hasta dos decimales', () {
      expect(parseAmountInput('100'), 10000);
      expect(parseAmountInput('100,5'), 10050);
      expect(parseAmountInput('100.50'), 10050);
      expect(parseAmountInput('.5'), 50);
      expect(parseAmountInput('12.'), 1200);
    });

    test('rechaza vacío, texto y más de dos decimales', () {
      expect(parseAmountInput(''), isNull);
      expect(parseAmountInput('abc'), isNull);
      expect(parseAmountInput('1.234'), isNull);
      expect(parseAmountInput('1,2,3'), isNull);
      expect(parseAmountInput('1234567890123'), isNull);
    });
  });

  testWidgets('muestra el resultado, la tasa y su fecha', (tester) async {
    await pumpCard(tester);

    expect(find.text('Escribe un monto para ver cuánto recibirías.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '100');
    await tester.pump();

    expect(find.text('Recibirías \$112.04'), findsOneWidget);
    expect(find.text('1 EUR = 1.1204 USD'), findsOneWidget);
    expect(find.text('Tasa del 5 oct 2026 (BCE)'), findsOneWidget);
  });

  testWidgets('avisa cuando la tasa viene de la caché', (tester) async {
    repository.cachedAt = DateTime.utc(2026, 10, 5, 12);
    await pumpCard(tester);

    expect(find.text('Sin conexión: tasa guardada del 5 oct 2026.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('error: muestra el mensaje y Reintentar se recupera', (tester) async {
    repository.failure = const Failure('sin red', 'network');
    await pumpCard(tester);

    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    repository.failure = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(repository.calls, 2);
  });
}
