import 'package:banco_app/app.dart';
import 'package:banco_app/di.dart';
import 'package:core_errors/core_errors.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Flujo E2E crítico: login -> saldo -> movimientos.
//
// Se ejecuta en un dispositivo o emulador (NO en el CI: `flutter test` solo
// corre `test/`). Usa casos de uso falsos registrados en GetIt, así que no
// necesita backend ni --dart-define:
//
//   cd packages/app
//   flutter test integration_test/login_balance_test.dart -d <id-del-dispositivo>

class _FakeGetCurrentUser implements GetCurrentUser {
  @override
  AuthUser? call() => null; // sin sesión: la app arranca en el login
}

class _FakeSignIn implements SignIn {
  @override
  Future<Failure?> call({
    required String email,
    required String password,
  }) async => null;
}

class _FakeSignOut implements SignOut {
  @override
  Future<Failure?> call() async => null;
}

class _FakeGetUserProfile implements GetUserProfile {
  @override
  Future<({UserProfile? profile, Failure? failure})> call() async => (
    profile: const UserProfile(fullName: 'Ana Pérez', segment: 'joven'),
    failure: null,
  );
}

class _FakeGetAccounts implements GetAccounts {
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

/// 25 movimientos: la primera página trae 20 y la segunda, 5.
class _FakeGetTransactions implements GetTransactions {
  final all = List.generate(
    25,
    (i) => Transaction(
      id: 't$i',
      accountId: 'a1',
      type: i.isEven ? TransactionType.credit : TransactionType.debit,
      amountCents: 100 * (i + 1),
      balanceAfterCents: 50000,
      createdAt: DateTime.utc(2026, 10, 4, 12).subtract(Duration(minutes: i)),
      category: 'comida',
      description: 'Mov $i',
    ),
  );

  @override
  Future<({List<Transaction>? transactions, Failure? failure})> call(
    String accountId, {
    int offset = 0,
    int limit = 20,
  }) async => (
    transactions: all.skip(offset).take(limit).toList(),
    failure: null,
  );
}

void useFake<T extends Object>(T fake) {
  sl.unregister<T>();
  sl.registerSingleton<T>(fake);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login -> saldo -> movimientos', (tester) async {
    await sl.reset();
    addTearDown(sl.reset);
    registerOnboardingDependencies(sl);
    registerAccountsDependencies(sl);
    useFake<GetCurrentUser>(_FakeGetCurrentUser());
    useFake<SignIn>(_FakeSignIn());
    useFake<SignOut>(_FakeSignOut());
    useFake<GetUserProfile>(_FakeGetUserProfile());
    useFake<GetAccounts>(_FakeGetAccounts());
    useFake<GetTransactions>(_FakeGetTransactions());

    await tester.pumpWidget(const BancoApp());
    await tester.pumpAndSettle();

    // 1. Sin sesión: login
    expect(find.text('Inicia sesión'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'joven@demo.com');
    await tester.enterText(find.byType(TextField).at(1), 'demo1234');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    // 2. Saldo
    expect(find.text('Hola, Ana Pérez'), findsOneWidget);
    expect(find.text('Segmento: joven'), findsOneWidget);
    expect(find.text('Cuenta de ahorros'), findsOneWidget);
    expect(find.text('\$500.00'), findsOneWidget);

    // 3. Movimientos: la primera página y, al desplazar, la segunda
    expect(find.text('Mov 0'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Mov 24'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Mov 24'), findsOneWidget);
  });
}
