import 'package:banco_app/debug/debug_panel.dart';
import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCacheStore implements CacheStore {
  int clears = 0;

  @override
  Future<CacheEntry?> read(String key) async => null;

  @override
  Future<void> write(String key, String json) async {}

  @override
  Future<void> clear() async {
    clears++;
  }

  @override
  Future<void> bindOwner(String ownerId) async {}
}

void main() {
  late DebugNetworkConfig config;
  late FakeCacheStore cache;

  setUp(() {
    config = DebugNetworkConfig();
    cache = FakeCacheStore();
  });

  Future<void> openPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) =>
            DebugPanelOverlay(config: config, cache: cache, child: child!),
        home: const Scaffold(body: Text('contenido')),
      ),
    );
    await tester.tap(find.byIcon(Icons.bug_report_outlined));
    await tester.pump();
  }

  testWidgets('el panel arranca cerrado y deja ver el contenido', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) =>
            DebugPanelOverlay(config: config, cache: cache, child: child!),
        home: const Scaffold(body: Text('contenido')),
      ),
    );

    expect(find.text('contenido'), findsOneWidget);
    expect(find.text('Depuración de red'), findsNothing);
    expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
  });

  testWidgets('humo: modo sin conexión, latencia, restablecer y borrar caché', (
    tester,
  ) async {
    await openPanel(tester);
    expect(find.text('Depuración de red'), findsOneWidget);

    // Sin conexión
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(config.offline, isTrue);

    // Latencia
    await tester.tap(find.text('3 s'));
    await tester.pump();
    expect(config.latency, const Duration(seconds: 3));

    // Fallos 503
    await tester.tap(find.text('50 %'));
    await tester.pump();
    expect(config.failurePercent, 50);

    // Restablecer
    await tester.tap(find.text('Restablecer'));
    await tester.pump();
    expect(config.isDefault, isTrue);

    // Borrar caché
    await tester.tap(find.text('Borrar caché'));
    await tester.pump();
    expect(cache.clears, 1);
    expect(find.text('Caché borrada'), findsOneWidget);
  });

  testWidgets('el panel se cierra con su botón', (tester) async {
    await openPanel(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.text('Depuración de red'), findsNothing);
    expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
  });
}
