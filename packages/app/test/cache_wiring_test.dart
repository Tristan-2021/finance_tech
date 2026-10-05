import 'package:banco_app/app.dart';
import 'package:banco_app/di.dart';
import 'package:core_errors/core_errors.dart';
import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registro ordenado de lo que ocurre, para comprobar el orden de las llamadas.
final events = <String>[];

class FakeCacheStore implements CacheStore {
  @override
  Future<CacheEntry?> read(String key) async => null;

  @override
  Future<void> write(String key, String json) async {}

  @override
  Future<void> clear() async {
    events.add('clear');
  }

  @override
  Future<void> bindOwner(String ownerId) async {
    events.add('bind:$ownerId');
  }
}

/// Tras cerrar sesión se construye el login, cuyo Cubit usa SignIn.
class FakeSignIn implements SignIn {
  @override
  Future<Failure?> call({
    required String email,
    required String password,
  }) async => null;
}

class FakeGetCurrentUser implements GetCurrentUser {
  @override
  AuthUser? call() => const AuthUser(id: 'u1', email: 'a@b.com');
}

class FakeGetUserProfile implements GetUserProfile {
  @override
  Future<({UserProfile? profile, Failure? failure})> call() async {
    events.add('profile');
    return (
      profile: const UserProfile(fullName: 'Ana Pérez', segment: 'joven'),
      failure: null,
    );
  }
}

class FakeSignOut implements SignOut {
  Failure? failure;

  @override
  Future<Failure?> call() async {
    events.add('signOut');
    return failure;
  }
}

class FakeGetAccounts implements GetAccounts {
  @override
  Future<({List<Account>? accounts, Failure? failure})> call() async => (
    accounts: const [
      Account(
        id: 'a1',
        name: 'Cuenta de ahorros',
        type: 'savings',
        currency: 'USD',
        balanceCents: 50000,
      ),
    ],
    failure: null,
  );
}

class FakeGetTransactions implements GetTransactions {
  @override
  Future<({List<Transaction>? transactions, Failure? failure})> call(
    String accountId, {
    int offset = 0,
    int limit = 20,
  }) async => (transactions: <Transaction>[], failure: null);
}

void useFake<T extends Object>(T fake) {
  sl.unregister<T>();
  sl.registerSingleton<T>(fake);
}

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const BancoApp());
  await tester.pump(); // la puerta resuelve y navega
  await tester.pump(const Duration(seconds: 1)); // transición de ruta
  await tester.pump(); // perfil cargado
  await tester.pump(); // cuentas cargadas
  await tester.pump(); // movimientos cargados
}

Future<void> signOutFromMenu(WidgetTester tester) async {
  await tester.tap(find.text('Cuenta')); // la app abre en Inicio
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byTooltip('Menú'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text('Cerrar sesión'));
  await tester.pump();
  await tester.pump();
}

void main() {
  late FakeSignOut signOut;

  setUp(() async {
    events.clear();
    await sl.reset();
    registerOnboardingDependencies(sl);
    registerAccountsDependencies(sl);
    signOut = FakeSignOut();
    useFake<SignIn>(FakeSignIn());
    useFake<GetCurrentUser>(FakeGetCurrentUser());
    useFake<GetUserProfile>(FakeGetUserProfile());
    useFake<SignOut>(signOut);
    useFake<GetAccounts>(FakeGetAccounts());
    useFake<GetTransactions>(FakeGetTransactions());
  });

  tearDown(() async => sl.reset());

  group('caché ligada a la sesión', () {
    setUp(() => sl.registerSingleton<CacheStore>(FakeCacheStore()));

    testWidgets('se asocia al usuario ANTES de cargar el perfil', (tester) async {
      await pumpApp(tester);

      expect(events.take(2), ['bind:u1', 'profile']);
    });

    testWidgets('cerrar sesión limpia la caché', (tester) async {
      await pumpApp(tester);
      events.clear();

      await signOutFromMenu(tester);

      expect(events, ['signOut', 'clear']);
    });

    testWidgets('si cerrar sesión falla no se limpia la caché', (tester) async {
      signOut.failure = const Failure('sin red', 'network');
      await pumpApp(tester);
      events.clear();

      await signOutFromMenu(tester);

      expect(events, ['signOut']);
    });
  });

  group('panel de depuración', () {
    testWidgets('sin DebugNetworkConfig registrado no hay panel', (tester) async {
      await pumpApp(tester);
      expect(find.byIcon(Icons.bug_report_outlined), findsNothing);
    });

    testWidgets('con DebugNetworkConfig registrado aparece el botón', (
      tester,
    ) async {
      sl.registerSingleton<DebugNetworkConfig>(DebugNetworkConfig());
      await pumpApp(tester);
      expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
    });
  });

  group('registerDependencies', () {
    test('registra la caché, el estado de red y la conectividad si se pasan', () async {
      await sl.reset();
      final client = SupabaseClient('https://example.test', 'test-key');
      addTearDown(client.dispose);
      final cache = FakeCacheStore();
      final status = NetworkStatusNotifier();
      final connectivity = ConnectivityMonitor(const Stream.empty());
      final debug = DebugNetworkConfig();

      registerDependencies(
        client,
        cache: cache,
        networkStatus: status,
        connectivity: connectivity,
        debugConfig: debug,
      );

      expect(sl<CacheStore>(), same(cache));
      expect(sl<NetworkStatusNotifier>(), same(status));
      expect(sl<ConnectivityMonitor>(), same(connectivity));
      expect(sl<DebugNetworkConfig>(), same(debug));
    });

    test('sin parámetros opcionales no registra nada extra', () async {
      await sl.reset();
      final client = SupabaseClient('https://example.test', 'test-key');
      addTearDown(client.dispose);

      registerDependencies(client);

      expect(sl.isRegistered<CacheStore>(), isFalse);
      expect(sl.isRegistered<NetworkStatusNotifier>(), isFalse);
      expect(sl.isRegistered<ConnectivityMonitor>(), isFalse);
      expect(sl.isRegistered<DebugNetworkConfig>(), isFalse);
    });
  });
}
