import 'package:core_errors/core_errors.dart';
import 'package:feature_personalization/feature_personalization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeSpendingRepository spending;
  late FakeLayoutRepository layouts;

  Future<void> pumpHome(
    WidgetTester tester,
    List<HomeBlock> blocks,
  ) async {
    layouts = FakeLayoutRepository(
      HomeLayout(schemaVersion: 1, defaultBlocks: blocks, segmentBlocks: const {}),
    );
    final cubit = HomeCubit(
      GetHomeLayout(layouts),
      RefreshHomeLayout(layouts),
      WatchHomeLayout(layouts),
      FakeTelemetry(),
      'joven',
    );
    final registry = BlockRegistry.standard(
      spendingCubitFactory: () => SpendingCubit(GetSpendingSummary(spending)),
    );
    await cubit.start();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeBlocksView(cubit: cubit, registry: registry),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  setUp(() => spending = FakeSpendingRepository());

  testWidgets('dibuja consejo, promoción y tipo de cambio', (tester) async {
    await pumpHome(tester, [
      block('t', BlockType.tip, {'text': 'Ahorra un poco'}),
      block('p', BlockType.promo, {'title': 'Meta', 'body': 'Activa tu meta'}),
      block('r', BlockType.exchangeRate, {'pair': 'USD/EUR', 'rate': '0.92'}),
    ]);
    expect(find.text('Ahorra un poco'), findsOneWidget);
    expect(find.text('Meta'), findsOneWidget);
    expect(find.text('Activa tu meta'), findsOneWidget);
    expect(find.text('USD/EUR  0.92'), findsOneWidget);
  });

  testWidgets('bloques sin parámetros obligatorios no dibujan nada', (tester) async {
    await pumpHome(tester, [
      block('t', BlockType.tip),
      block('p', BlockType.promo),
      block('r', BlockType.exchangeRate),
    ]);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('resumen de gastos con importes en centavos', (tester) async {
    spending.summary = const SpendingSummary(
      totalCents: 12550,
      topCategory: 'comida',
      topCategoryCents: 8000,
      previousTotalCents: 10000,
    );
    await pumpHome(tester, [block('s', BlockType.spendingSummary)]);
    expect(find.text('\$125.50'), findsOneWidget);
    expect(find.textContaining('comida'), findsOneWidget);
    expect(find.text('25% más que el mes anterior'), findsOneWidget);
  });

  testWidgets('resumen vacío muestra el estado vacío', (tester) async {
    await pumpHome(tester, [block('s', BlockType.spendingSummary)]);
    expect(find.text('Aún no tienes gastos este mes.'), findsOneWidget);
  });

  testWidgets('error del resumen permite reintentar', (tester) async {
    spending.failure = const Failure('sin red', 'network');
    await pumpHome(tester, [block('s', BlockType.spendingSummary)]);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(spending.calls, 1);

    spending
      ..failure = null
      ..summary = const SpendingSummary(
        totalCents: 500,
        topCategory: null,
        topCategoryCents: 0,
        previousTotalCents: null,
      );
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();
    expect(spending.calls, 2);
    expect(find.text('\$5.00'), findsOneWidget);
  });
}
