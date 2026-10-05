import 'package:banco_app/app.dart';
import 'package:banco_app/config_error_app.dart';
import 'package:banco_app/di.dart';
import 'package:core_errors/core_errors.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Casos de uso falsos: se implementan (no se heredan) para no necesitar el
// AuthRepository, que el barril de feature_onboarding no exporta.
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

class FakeSignOut implements SignOut {
  Failure? failure;
  int calls = 0;

  @override
  Future<Failure?> call() async {
    calls++;
    return failure;
  }
}

const user = AuthUser(id: 'u1', email: 'a@b.com');

void useFake<T extends Object>(T fake) {
  sl.unregister<T>();
  sl.registerSingleton<T>(fake);
}

Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const BancoApp());
  await tester.pump(); // la puerta resuelve
  await tester.pump(const Duration(seconds: 1)); // transición de ruta
}

NavigatorState navigator(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator));

void main() {
  late FakeGetCurrentUser getCurrentUser;
  late FakeSignIn signIn;
  late FakeSignOut signOut;

  setUp(() async {
    await sl.reset();
    registerOnboardingDependencies(sl);
    getCurrentUser = FakeGetCurrentUser(() => null);
    signIn = FakeSignIn();
    signOut = FakeSignOut();
    useFake<GetCurrentUser>(getCurrentUser);
    useFake<SignIn>(signIn);
    useFake<SignOut>(signOut);
  });

  tearDown(() async => sl.reset());

  group('SessionGate', () {
    testWidgets('con usuario -> pantalla provisional', (tester) async {
      getCurrentUser.impl = () => user;
      await pumpApp(tester);
      expect(find.text('Tus cuentas aparecerán aquí'), findsOneWidget);
      expect(find.text('Inicia sesión'), findsNothing);
    });

    testWidgets('sin usuario -> login', (tester) async {
      await pumpApp(tester);
      expect(find.text('Inicia sesión'), findsOneWidget);
      expect(find.text('Tus cuentas aparecerán aquí'), findsNothing);
    });

    testWidgets('muestra LoadingView mientras consulta', (tester) async {
      await tester.pumpWidget(const BancoApp());
      expect(find.byType(LoadingView), findsOneWidget);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(LoadingView), findsNothing);
    });

    testWidgets('si la consulta falla -> ErrorView y reintento', (tester) async {
      var attempts = 0;
      getCurrentUser.impl = () {
        attempts++;
        if (attempts == 1) throw StateError('sin sesión legible');
        return user;
      };
      await tester.pumpWidget(const BancoApp());
      await tester.pump();
      await tester.pump();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Algo salió mal. Inténtalo de nuevo.'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(getCurrentUser.calls, 2);
      expect(find.byType(ErrorView), findsNothing);
      expect(find.text('Tus cuentas aparecerán aquí'), findsOneWidget);
    });

    testWidgets('la puerta se reemplaza: no hay ruta a la que volver', (
      tester,
    ) async {
      await pumpApp(tester);
      expect(navigator(tester).canPop(), isFalse);
    });
  });

  group('flujo de sesión', () {
    testWidgets('login exitoso -> pantalla provisional sin poder volver', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.enterText(find.byType(TextField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(1), 'secret123');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(signIn.received, (email: 'a@b.com', password: 'secret123'));
      expect(find.text('Tus cuentas aparecerán aquí'), findsOneWidget);
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
      expect(find.text('Tus cuentas aparecerán aquí'), findsNothing);
    });

    testWidgets('cerrar sesión -> login sin poder volver', (tester) async {
      getCurrentUser.impl = () => user;
      await pumpApp(tester);

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(signOut.calls, 1);
      expect(find.text('Inicia sesión'), findsOneWidget);
      expect(find.text('Tus cuentas aparecerán aquí'), findsNothing);
      expect(navigator(tester).canPop(), isFalse);
    });

    testWidgets('cerrar sesión con error: muestra el mensaje y no sale', (
      tester,
    ) async {
      getCurrentUser.impl = () => user;
      signOut.failure = const Failure('técnico', 'network');
      await pumpApp(tester);

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Sin conexión. Revisa tu internet e inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Tus cuentas aparecerán aquí'), findsOneWidget);
    });
  });

  group('MaterialApp', () {
    testWidgets('usa el tema de core_ui, modo sistema y español', (tester) async {
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
    test('registra el SupabaseClient y todo lo de onboarding', () async {
      await sl.reset();
      // Cliente real con URL y clave de mentira: no abre red si no se usa.
      final client = SupabaseClient('https://example.test', 'test-key');
      addTearDown(client.dispose);

      registerDependencies(client);

      expect(sl<SupabaseClient>(), same(client));
      expect(sl<GetCurrentUser>(), isA<GetCurrentUser>());
      expect(sl<SignIn>(), isA<SignIn>());
      expect(sl<SignOut>(), isA<SignOut>());
      expect(sl<GetUserProfile>(), isA<GetUserProfile>());
    });
  });
}
