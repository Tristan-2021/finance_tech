import 'dart:async';

import 'package:banco_app/app.dart';
import 'package:banco_app/di.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

// E2E del flujo crítico contra el backend local REAL (sin falsos):
//
//   login -> home personalizado -> pestaña Cuenta con saldo y movimientos
//   -> modo sin conexión + refrescar -> aviso de datos guardados con su fecha
//   -> vuelve la conectividad -> los datos se recuperan solos -> cerrar sesión
//
// Se ejecuta a mano en el dispositivo (NO entra al CI). Con `supabase start` y
// los usuarios demo creados (`./scripts/create_demo_users.sh`):
//
//   adb reverse tcp:54421 tcp:54421
//   cd packages/app
//   flutter test integration_test/critical_flow_test.dart -d <id-del-dispositivo> \
//     --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
//     --dart-define=SUPABASE_ANON_KEY=<la-clave-publicable>
//
// El modo sin conexión se activa por código con `DebugNetworkConfig` (el mismo
// que usa el panel de depuración) y la vuelta de la red se simula emitiendo los
// cambios de conectividad que `ConnectivityMonitor` escucha en producción.

const _email = String.fromEnvironment('DEMO_EMAIL', defaultValue: 'joven@demo.com');
const _password = String.fromEnvironment('DEMO_PASSWORD', defaultValue: 'demo1234');

/// Avanza fotogramas hasta que [finder] encuentra algo (o falla al agotar el
/// tiempo). No usa `pumpAndSettle`: hay indicadores de carga y peticiones reales.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('No apareció $finder en ${timeout.inSeconds} s');
}

/// Lo contrario: espera a que [finder] deje de encontrar algo.
Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isEmpty) return;
  }
  throw TestFailure('Siguió apareciendo $finder tras ${timeout.inSeconds} s');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'login -> home -> cuenta -> sin conexión -> recuperación -> cerrar sesión',
    (tester) async {
      // --- Composición real, con la red y la conectividad bajo control ---
      await sl.reset();
      addTearDown(sl.reset);
      final debug = DebugNetworkConfig();
      final reconnect = StreamController<List<ConnectivityResult>>.broadcast();
      addTearDown(reconnect.close);
      final status = NetworkStatusNotifier();
      final client = await initSupabase(
        SupabaseConfig.fromEnvironment(),
        innerClient: FaultInjectingClient(http.Client(), debug),
        status: status,
      );
      // Parte limpio: sin sesión de ejecuciones anteriores ni datos guardados.
      await client.auth.signOut();
      final cache = await HiveCacheStore.open(
        keyProvider: EncryptionKeyProvider(FlutterSecretStore()),
      );
      await cache.clear();

      registerDependencies(
        client,
        cache: cache,
        networkStatus: status,
        connectivity: ConnectivityMonitor(reconnect.stream),
        debugConfig: debug,
      );
      // Los avisos push no forman parte de este flujo: sin el pre-aviso.
      sl.unregister<NotificationsController>();

      await tester.pumpWidget(const BancoApp());

      // 1. Login real
      await pumpUntil(tester, find.text('Inicia sesión'));
      await tester.enterText(find.byType(TextField).at(0), _email);
      await tester.enterText(find.byType(TextField).at(1), _password);
      await tester.tap(find.text('Iniciar sesión'));
      await pumpUntil(tester, find.byType(NavigationBar));

      // 2. Home personalizado: bloques del segmento joven (layout por defecto,
      //    porque en este arranque no se inicializa Firebase/Remote Config) y
      //    el resumen de gastos con datos reales.
      await pumpUntil(tester, find.text('Ahorra desde hoy'));
      expect(find.text('Tus gastos del mes'), findsOneWidget);
      await pumpUntilGone(tester, find.byType(CircularProgressIndicator));

      // 3. Cuenta: saldo y movimientos reales
      await tester.tap(find.text('Cuenta'));
      await pumpUntil(tester, find.text('Saldo disponible'));
      await pumpUntil(tester, find.textContaining('Saldo: '));
      expect(find.textContaining('Mostrando datos guardados'), findsNothing);

      // 4. Sin conexión + refrescar (pull-to-refresh): se sirven los datos
      //    guardados con el aviso y su fecha.
      debug.offline = true;
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 400));
      await pumpUntil(
        tester,
        find.textContaining('Mostrando datos guardados el'),
        timeout: const Duration(seconds: 30),
      );
      expect(find.text('Saldo disponible'), findsOneWidget);

      // 5. Vuelve la red: sin tocar nada, los datos se recuperan solos.
      debug.offline = false;
      reconnect
        ..add([ConnectivityResult.none])
        ..add([ConnectivityResult.wifi]);
      await pumpUntilGone(
        tester,
        find.textContaining('Mostrando datos guardados el'),
        timeout: const Duration(seconds: 30),
      );

      // 6. Cerrar sesión
      await tester.tap(find.byTooltip('Menú'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Cerrar sesión'));
      await pumpUntil(tester, find.text('Inicia sesión'));
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
