import 'package:banco_app/home_shell.dart';
import 'package:core_telemetry/core_telemetry.dart';
import 'package:feature_personalization/feature_personalization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Counter extends StatefulWidget {
  final String label;
  final List<String> log;
  const _Counter(this.label, this.log);

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  void initState() {
    super.initState();
    widget.log.add(widget.label);
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

class _FakeLayouts implements HomeLayoutRepository {
  final HomeLayout layout;
  _FakeLayouts(this.layout);

  @override
  HomeLayout get current => layout;

  @override
  Future<HomeLayout> refresh() async => layout;

  @override
  Stream<HomeLayout> get changes => const Stream.empty();
}

void main() {
  group('HomeShell', () {
    late ShellNavigator navigator;
    late List<String> created;

    setUp(() {
      navigator = ShellNavigator();
      created = [];
    });
    tearDown(() => navigator.dispose());

    Future<void> pumpShell(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        home: HomeShell(
          navigator: navigator,
          homeBuilder: (_) => _Counter('pantalla inicio', created),
          accountsBuilder: (_) => _Counter('pantalla cuenta', created),
        ),
      ),
    );

    testWidgets('abre en Inicio y las pestañas cambian de pantalla', (
      tester,
    ) async {
      await pumpShell(tester);
      expect(find.text('pantalla inicio'), findsOneWidget);
      expect(find.text('pantalla cuenta'), findsNothing);

      await tester.tap(find.text('Cuenta'));
      await tester.pump();
      expect(find.text('pantalla cuenta'), findsOneWidget);
      expect(find.text('pantalla inicio'), findsNothing);

      await tester.tap(find.text('Inicio'));
      await tester.pump();
      expect(find.text('pantalla inicio'), findsOneWidget);
    });

    testWidgets('cambiar de pestaña conserva el estado de cada una', (
      tester,
    ) async {
      await pumpShell(tester);
      await tester.tap(find.text('Cuenta'));
      await tester.pump();
      await tester.tap(find.text('Inicio'));
      await tester.pump();

      expect(created, ['pantalla inicio', 'pantalla cuenta']);
    });

    testWidgets('openAccounts va a Cuenta y la recarga', (tester) async {
      await pumpShell(tester);
      navigator.openAccounts();
      await tester.pump();

      expect(navigator.tab, ShellTab.accounts);
      expect(find.text('pantalla cuenta'), findsOneWidget);
      // La pestaña Cuenta se recreó (así recarga el saldo); Inicio no.
      expect(created, ['pantalla inicio', 'pantalla cuenta', 'pantalla cuenta']);
    });
  });

  group('bloques', () {
    testWidgets('un tipo sin constructor registrado se omite sin error', (
      tester,
    ) async {
      final layouts = _FakeLayouts(
        HomeLayout(
          schemaVersion: 1,
          defaultBlocks: const [
            HomeBlock(id: 'p', type: BlockType.promo, params: {'title': 'Promo'}),
            HomeBlock(id: 't', type: BlockType.tip, params: {'text': 'Un consejo'}),
          ],
          segmentBlocks: const {},
        ),
      );
      final cubit = HomeCubit(
        GetHomeLayout(layouts),
        RefreshHomeLayout(layouts),
        WatchHomeLayout(layouts),
        const NoopTelemetry(),
        'joven',
      );
      addTearDown(cubit.close);
      // Solo el consejo está registrado: la promoción no tiene constructor.
      final registry = BlockRegistry({
        BlockType.tip: (_, block) => Text(block.stringParam('text')!),
      });
      await cubit.start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HomeBlocksView(cubit: cubit, registry: registry)),
        ),
      );

      expect(find.text('Un consejo'), findsOneWidget);
      expect(find.text('Promo'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
