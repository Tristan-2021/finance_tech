import 'package:banco_app/di.dart';
import 'package:banco_app/welcome_page.dart';
import 'package:core_errors/core_errors.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registro ordenado de lo que ocurre, para comprobar el orden de las llamadas.
final log = <String>[];

/// Se implementa (no se hereda): así no necesita el gateway ni el repositorio de
/// tokens, que el barril del feature no exporta.
class FakeNotifications implements NotificationsController {
  void Function()? onOpenAccounts;
  Object? stopError;

  @override
  Duration get stopTimeout => Duration.zero;

  @override
  Future<void> initialize() async => log.add('initialize');

  @override
  Future<void> start({required void Function() onOpenAccounts}) async {
    log.add('start');
    this.onOpenAccounts = onOpenAccounts;
  }

  @override
  Future<void> stop() async {
    log.add('stop');
    if (stopError != null) throw stopError!;
  }
}

class FakeSignOut implements SignOut {
  Failure? failure;

  @override
  Future<Failure?> call() async {
    log.add('signOut');
    return failure;
  }
}

class FakeGetCurrentUser implements GetCurrentUser {
  @override
  AuthUser? call() => const AuthUser(id: 'u1', email: 'a@b.com');
}

class FakeGetUserProfile implements GetUserProfile {
  @override
  Future<({UserProfile? profile, Failure? failure})> call() async => (
    profile: const UserProfile(fullName: 'Ana Pérez', segment: 'joven'),
    failure: null,
  );
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

void main() {
  late FakeNotifications notifications;
  late FakeSignOut signOut;

  setUp(() async {
    log.clear();
    await sl.reset();
    registerAccountsDependencies(sl);
    useFake<GetAccounts>(FakeGetAccounts());
    useFake<GetTransactions>(FakeGetTransactions());
    notifications = FakeNotifications();
    signOut = FakeSignOut();
  });

  tearDown(() async => sl.reset());

  Future<void> pumpWelcome(
    WidgetTester tester, {
    bool acceptPrePrompt = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: WelcomePage(
          getCurrentUser: FakeGetCurrentUser(),
          getUserProfile: FakeGetUserProfile(),
          signOut: signOut,
          notifications: notifications,
          prePrompt: (_) async => acceptPrePrompt,
          onSignedOut: () => log.add('signedOut'),
        ),
      ),
    );
    await tester.pump(); // perfil
    await tester.pump(); // pintado y pre-aviso
    await tester.pumpAndSettle();
  }

  Future<void> signOutFromMenu(WidgetTester tester) async {
    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menú'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
  }

  group('notificaciones en el ciclo de sesión', () {
    testWidgets('tras cargar el perfil, el pre-aviso aceptado inicia los avisos', (
      tester,
    ) async {
      await pumpWelcome(tester);
      expect(log, ['start']);
    });

    testWidgets('si rechaza el pre-aviso no se pide el permiso', (tester) async {
      await pumpWelcome(tester, acceptPrePrompt: false);
      expect(log, isNot(contains('start')));
    });

    testWidgets('cerrar sesión llama a stop() ANTES de SignOut', (tester) async {
      await pumpWelcome(tester);
      log.clear();

      await signOutFromMenu(tester);

      expect(log, ['stop', 'signOut', 'signedOut']);
    });

    testWidgets('un fallo de stop() no impide cerrar sesión', (tester) async {
      await pumpWelcome(tester);
      notifications.stopError = Exception('sin red');
      log.clear();

      await signOutFromMenu(tester);

      expect(log, ['stop', 'signOut', 'signedOut']);
    });

    testWidgets('aunque rechace el pre-aviso, stop() borra el token al salir', (
      tester,
    ) async {
      await pumpWelcome(tester, acceptPrePrompt: false);
      log.clear();

      await signOutFromMenu(tester);

      expect(log, ['stop', 'signOut', 'signedOut']);
    });

    testWidgets('el toque de una notificación lleva a la pestaña Cuenta', (
      tester,
    ) async {
      await pumpWelcome(tester);
      expect(find.byTooltip('Menú'), findsNothing); // abre en Inicio

      notifications.onOpenAccounts!();
      await tester.pumpAndSettle();

      expect(find.byTooltip('Menú'), findsOneWidget);
      expect(find.text('Cuenta de ahorros'), findsOneWidget);
    });
  });
}
