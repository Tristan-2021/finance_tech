import 'dart:async';

import 'package:banco_app/app.dart';
import 'package:banco_app/config_error_app.dart';
import 'package:banco_app/di.dart';
import 'package:core_errors/core_errors.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Casos de uso falsos: se implementan (no se heredan) para no necesitar los
// repositorios, que los barriles de los features no exportan.
class FakeGetCurrentUser implements GetCurrentUser {
  AuthUser? Function() impl;
  int calls = 0;
  FakeGetCurrentUser(this.impl);

  @override
  AuthUser? call() {
    calls++;
    return impl();
  }
}

class FakeSignIn implements SignIn {
  Failure? failure;
  ({String email, String password})? received;

  @override
  Future<Failure?> call({
    required String email,
    required String password,
  }) async {
    received = (email: email, password: password);
    return failure;
  }
}

/// El parámetro es `Object?` (un supertipo de `SignUpParams`, que el barril no
/// exporta): es un override válido y evita importar de `src/`.
class FakeSignUp implements SignUp {
  Failure? failure;
  Object? received;
  int calls = 0;

  @override
  Future<Failure?> call(Object? params) async {
    calls++;
    received = params;
    return failure;
  }
}

class FakeSignOut implements SignOut {
  Failure? failure;
  int calls = 0;

  @override
  Future<Failure?> call() async {
    calls++;
    return failure;
  }
}

typedef ProfileResult = ({UserProfile? profile, Failure? failure});

class FakeGetUserProfile implements GetUserProfile {
  Future<ProfileResult> Function() impl = () async => (
    profile: const UserProfile(fullName: 'Ana Pérez', segment: 'joven'),
    failure: null,
  );
  int calls = 0;

  @override
  Future<ProfileResult> call() {
    calls++;
    return impl();
  }
}

typedef AccountsResult = ({List<Account>? accounts, Failure? failure});

class FakeGetAccounts implements GetAccounts {
  Future<AccountsResult> Function() impl = () async => (
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

  @override
  Future<AccountsResult> call() => impl();
}

typedef TransactionsResult = ({
  List<Transaction>? transactions,
  Failure? failure,
});

/// Sin movimientos: estos tests prueban la composición del shell, no la lista.
class FakeGetTransactions implements GetTransactions {
  @override
  Future<TransactionsResult> call(
    String accountId, {
    int offset = 0,
    int limit = 20,
  }) async => (transactions: <Transaction>[], failure: null);
}

const user = AuthUser(id: 'u1', email: 'a@b.com');

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

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> signOutFromMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menú'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.text('Cerrar sesión'));
  await tester.pump();
}

NavigatorState navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator));

void main() {
  late FakeGetCurrentUser getCurrentUser;
  late FakeSignIn signIn;
  late FakeSignUp signUp;
  late FakeSignOut signOut;
  late FakeGetUserProfile getUserProfile;
  late FakeGetAccounts getAccounts;

  setUp(() async {
    await sl.reset();
    registerOnboardingDependencies(sl);
    registerAccountsDependencies(sl);
    getCurrentUser = FakeGetCurrentUser(() => null);
    signIn = FakeSignIn();
    signUp = FakeSignUp();
    signOut = FakeSignOut();
    getUserProfile = FakeGetUserProfile();
    getAccounts = FakeGetAccounts();
    useFake<GetCurrentUser>(getCurrentUser);
    useFake<SignIn>(signIn);
    useFake<SignUp>(signUp);
    useFake<SignOut>(signOut);
    useFake<GetUserProfile>(getUserProfile);
    useFake<GetAccounts>(getAccounts);
    useFake<GetTransactions>(FakeGetTransactions());
  });

  tearDown(() async => sl.reset());

  group('SessionGate', () {
    testWidgets('con usuario -> pantalla de cuentas', (tester) async {
      getCurrentUser.impl = () => user;
      await pumpApp(tester);
      expect(find.text('Hola, Ana Pérez'), findsOneWidget);
      expect(find.text('Inicia sesión'), findsNothing);
    });

    testWidgets('sin usuario -> login', (tester) async {
      await pumpApp(tester);
      expect(find.text('Inicia sesión'), findsOneWidget);
      expect(find.text('Hola, Ana Pérez'), findsNothing);
    });

    testWidgets('muestra LoadingView mientras consulta', (tester) async {
      await tester.pumpWidget(const BancoApp());
      expect(find.byType(LoadingView), findsOneWidget);
      await settle(tester);
      expect(find.byType(LoadingView), findsNothing);
    });

    testWidgets('si la consulta falla -> ErrorView y reintento', (
      tester,
    ) async {
      var attempts = 0;
      getCurrentUser.impl = () {
        attempts++;
        if (attempts == 1) throw StateError('sin sesión legible');
        return user;
      };
      await tester.pumpWidget(const BancoApp());
      await tester.pump();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Algo salió mal. Inténtalo de nuevo.'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await settle(tester);

      expect(getCurrentUser.calls, 2);
      expect(find.byType(ErrorView), findsNothing);
      expect(find.text('Hola, Ana Pérez'), findsOneWidget);
    });

    testWidgets('la puerta se reemplaza: no hay ruta a la que volver', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(navigator(tester).canPop(), isFalse);
    });
  });

  group('flujo de sesión', () {
    testWidgets('login exitoso -> pantalla de cuentas sin poder volver', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(1), 'secret123');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();
      await settle(tester);

      expect(signIn.received, (email: 'a@b.com', password: 'secret123'));
      expect(find.text('Hola, Ana Pérez'), findsOneWidget);
      expect(find.text('Inicia sesión'), findsNothing);
      expect(navigator(tester).canPop(), isFalse);
    });

    testWidgets('login con error: se queda en el login con el mensaje', (
      tester,
    ) async {
      signIn.failure = const Failure('técnico', 'auth');
      await pumpApp(tester);
      await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(1), 'mala');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      expect(find.text('Hola, Ana Pérez'), findsNothing);
    });

    testWidgets('cerrar sesión -> login sin poder volver', (tester) async {
      getCurrentUser.impl = () => user;
      await pumpApp(tester);

      await signOutFromMenu(tester);
      await settle(tester);

      expect(signOut.calls, 1);
      expect(find.text('Inicia sesión'), findsOneWidget);
      expect(find.text('Hola, Ana Pérez'), findsNothing);
      expect(navigator(tester).canPop(), isFalse);
    });

    testWidgets('cerrar sesión con error: muestra el mensaje y no sale', (
      tester,
    ) async {
      getCurrentUser.impl = () => user;
      signOut.failure = const Failure('técnico', 'network');
      await pumpApp(tester);

      await signOutFromMenu(tester);
      await tester.pump();

      expect(
        find.text('Sin conexión. Revisa tu internet e inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Hola, Ana Pérez'), findsOneWidget);
    });
  });

  group('navegación login <-> registro', () {
    testWidgets('"Crear cuenta" abre el registro', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Crear cuenta'));
      await settle(tester);

      expect(find.text('Paso 1 de 3'), findsOneWidget);
      expect(find.text('Crea tu cuenta'), findsOneWidget);
      expect(find.text('Inicia sesión'), findsNothing);
      expect(navigator(tester).canPop(), isFalse);
    });

    testWidgets('"Ya tengo una cuenta" vuelve al login', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Crear cuenta'));
      await settle(tester);

      await tester.tap(find.text('Ya tengo una cuenta'));
      await settle(tester);

      expect(find.text('Inicia sesión'), findsOneWidget);
      expect(find.text('Paso 1 de 3'), findsNothing);
    });

    testWidgets('registro completo -> onRegistered lleva a la pantalla', (
      tester,
    ) async {
      // Hay sesión solo después de que SignUp se ejecutó.
      getCurrentUser.impl = () => signUp.calls > 0 ? user : null;
      await pumpApp(tester);
      await tester.tap(find.text('Crear cuenta'));
      await settle(tester);

      // Paso 1
      await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(1), 'secret123');
      await tester.tap(find.text('Continuar'));
      await tester.pump();

      // Paso 2: nombre y fecha (el selector propone exactamente 18 años)
      await tester.enterText(find.byType(TextField).at(0), 'Ana Pérez');
      await tester.tap(find.textContaining('Fecha de nacimiento'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(DatePickerDialog),
              matching: find.byType(TextButton),
            )
            .last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pump();

      // Paso 3
      expect(find.text('Paso 3 de 3'), findsOneWidget);
      await tester.tap(find.text('Ahorrar'));
      await tester.pump();
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();
      await settle(tester);

      expect(signUp.calls, 1);
      final params = signUp.received as dynamic;
      expect(params.email, 'a@b.com');
      expect(params.fullName, 'Ana Pérez');
      expect(params.accountUsage, 'Ahorrar');
      expect(find.text('Hola, Ana Pérez'), findsOneWidget);
      expect(find.text('Paso 3 de 3'), findsNothing);
      expect(navigator(tester).canPop(), isFalse);
    });
  });

  group('pantalla de cuentas: composición con el perfil', () {
    setUp(() => getCurrentUser.impl = () => user);

    testWidgets('saludo, segmento joven y saldo de la cuenta', (tester) async {
      await pumpApp(tester);
      expect(find.text('Hola, Ana Pérez'), findsOneWidget);
      expect(find.text('Segmento: joven'), findsOneWidget);
      expect(find.byType(Chip), findsOneWidget);
      expect(find.text('Cuenta de ahorros'), findsOneWidget);
      expect(find.text('\$500.00'), findsOneWidget);
    });

    testWidgets('segmento adulto', (tester) async {
      getUserProfile.impl = () async => (
        profile: const UserProfile(fullName: 'Luis Gómez', segment: 'adulto'),
        failure: null,
      );
      await pumpApp(tester);
      expect(find.text('Hola, Luis Gómez'), findsOneWidget);
      expect(find.text('Segmento: adulto'), findsOneWidget);
    });

    testWidgets('mientras carga el perfil muestra LoadingView', (tester) async {
      final gate = Completer<ProfileResult>();
      getUserProfile.impl = () => gate.future;
      await pumpApp(tester);

      expect(find.byType(LoadingView), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);

      gate.complete((
        profile: const UserProfile(fullName: 'Ana Pérez', segment: 'joven'),
        failure: null,
      ));
      await tester.pump(); // perfil
      await tester.pump(); // cuentas
      await tester.pump(); // movimientos
      expect(find.byType(LoadingView), findsNothing);
      expect(find.text('Hola, Ana Pérez'), findsOneWidget);
    });

    testWidgets('error de perfil -> ErrorView, reintento y datos', (
      tester,
    ) async {
      var attempts = 0;
      getUserProfile.impl = () async {
        attempts++;
        if (attempts == 1) {
          return (profile: null, failure: const Failure('técnico', 'network'));
        }
        return (
          profile: const UserProfile(fullName: 'Ana Pérez', segment: 'joven'),
          failure: null,
        );
      };
      await pumpApp(tester);

      expect(find.byType(ErrorView), findsOneWidget);
      expect(
        find.text('Sin conexión. Revisa tu internet e inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('técnico'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(getUserProfile.calls, 2);
      expect(find.byType(ErrorView), findsNothing);
      expect(find.text('Hola, Ana Pérez'), findsOneWidget);
    });

    testWidgets('con el perfil en error se puede cerrar sesión', (
      tester,
    ) async {
      getUserProfile.impl = () async =>
          (profile: null, failure: const Failure('x', 'rls_denied'));
      await pumpApp(tester);
      expect(find.byType(ErrorView), findsOneWidget);

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pump();
      await settle(tester);

      expect(signOut.calls, 1);
      expect(find.text('Inicia sesión'), findsOneWidget);
    });
  });

  group('MaterialApp', () {
    testWidgets('usa el tema de core_ui, modo sistema y español', (
      tester,
    ) async {
      await pumpApp(tester);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
      expect(
        app.theme?.colorScheme.primary,
        AppTheme.light().colorScheme.primary,
      );
      expect(
        app.darkTheme?.colorScheme.primary,
        AppTheme.dark().colorScheme.primary,
      );
      final context = tester.element(find.byType(Scaffold).first);
      expect(Localizations.localeOf(context).languageCode, 'es');
    });
  });

  group('ConfigErrorApp', () {
    testWidgets('muestra el mensaje con los nombres de los --dart-define', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ConfigErrorApp(
          message: 'Falta SUPABASE_URL o SUPABASE_ANON_KEY.',
        ),
      );
      expect(find.text('Falta configurar la app'), findsOneWidget);
      expect(
        find.text('Falta SUPABASE_URL o SUPABASE_ANON_KEY.'),
        findsOneWidget,
      );
    });
  });

  group('registerDependencies', () {
    test('registra el SupabaseClient y todo lo de los features', () async {
      await sl.reset();
      // Cliente real con URL y clave de mentira: no abre red si no se usa.
      final client = SupabaseClient('https://example.test', 'test-key');
      addTearDown(client.dispose);

      registerDependencies(client);

      expect(sl<SupabaseClient>(), same(client));
      expect(sl<GetCurrentUser>(), isA<GetCurrentUser>());
      expect(sl<SignIn>(), isA<SignIn>());
      expect(sl<SignUp>(), isA<SignUp>());
      expect(sl<SignOut>(), isA<SignOut>());
      expect(sl<GetUserProfile>(), isA<GetUserProfile>());
      expect(sl<GetAccounts>(), isA<GetAccounts>());
      expect(sl<GetBalance>(), isA<GetBalance>());
      expect(sl<GetTransactions>(), isA<GetTransactions>());
    });
  });
}
