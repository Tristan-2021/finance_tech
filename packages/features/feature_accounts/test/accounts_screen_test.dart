import 'package:core_errors/core_errors.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/domain/account_repository.dart';
import 'package:feature_accounts/src/presentation/accounts_cubit.dart';
import 'package:feature_accounts/src/presentation/accounts_state.dart';
import 'package:feature_accounts/src/presentation/accounts_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

class FakeAccountRepository implements AccountRepository {
  List<Account>? accounts = [];
  Failure? failure;
  int calls = 0;

  @override
  Future<({List<Account>? accounts, Failure? failure})> getAccounts() async {
    calls++;
    return failure == null
        ? (accounts: accounts, failure: null)
        : (accounts: null, failure: failure);
  }
}

const savings = Account(
  id: 'a1',
  name: 'Cuenta de ahorros',
  type: 'savings',
  currency: 'USD',
  balanceCents: 123456,
);
const checking = Account(
  id: 'a2',
  name: 'Cuenta corriente',
  type: 'checking',
  currency: 'USD',
  balanceCents: 5000,
);

void main() {
  late FakeAccountRepository repo;
  late AccountsCubit cubit;
  setUp(() {
    repo = FakeAccountRepository();
    cubit = AccountsCubit(GetAccounts(repo));
  });
  tearDown(() => cubit.close());

  group('AccountsCubit', () {
    test('carga las cuentas con la primera seleccionada', () async {
      repo.accounts = [savings, checking];
      await cubit.load();
      expect(cubit.state.status, AccountsStatus.loaded);
      expect(cubit.state.accounts, [savings, checking]);
      expect(cubit.state.selected, savings);
    });

    test('sin cuentas queda cargado y vacío', () async {
      await cubit.load();
      expect(cubit.state.status, AccountsStatus.loaded);
      expect(cubit.state.accounts, isEmpty);
      expect(cubit.state.selected, isNull);
    });

    test('cada código de Failure produce su mensaje', () async {
      const expected = {
        'network': 'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
        'rls_denied': 'No tienes permiso para ver esta información.',
        'unknown': 'Algo salió mal. Inténtalo de nuevo.',
      };
      for (final entry in expected.entries) {
        repo.failure = Failure('técnico', entry.key);
        await cubit.load();
        expect(cubit.state.status, AccountsStatus.error, reason: entry.key);
        expect(cubit.state.message, entry.value, reason: entry.key);
      }
    });

    test('reintentar tras un error carga los datos', () async {
      repo.failure = const Failure('x', 'network');
      await cubit.load();
      expect(cubit.state.status, AccountsStatus.error);

      repo
        ..failure = null
        ..accounts = [savings];
      await cubit.load();
      expect(cubit.state.status, AccountsStatus.loaded);
      expect(cubit.state.selected, savings);
    });

    test('selectAccount cambia la cuenta y ignora índices inválidos', () async {
      repo.accounts = [savings, checking];
      await cubit.load();

      cubit.selectAccount(1);
      expect(cubit.state.selected, checking);

      cubit.selectAccount(5);
      cubit.selectAccount(-1);
      expect(cubit.state.selected, checking);
    });
  });

  group('AccountsView', () {
    late int signOuts;
    setUp(() => signOuts = 0);

    Widget view() => MaterialApp(
      theme: AppTheme.light(),
      home: AccountsView(
        cubit: cubit,
        greetingName: 'Ana Pérez',
        segment: 'joven',
        onSignOut: () => signOuts++,
      ),
    );

    testWidgets('muestra saludo, segmento, cuenta y saldo real', (
      tester,
    ) async {
      repo.accounts = [savings];
      await tester.pumpWidget(view());
      cubit.load();
      await tester.pump();
      await tester.pump();

      expect(find.text('Hola, Ana Pérez'), findsOneWidget);
      expect(find.text('Segmento: joven'), findsOneWidget);
      expect(find.text('Cuenta de ahorros'), findsOneWidget);
      expect(find.text('\$1,234.56'), findsOneWidget);
    });

    testWidgets('con varias cuentas, el selector cambia el saldo', (
      tester,
    ) async {
      repo.accounts = [savings, checking];
      await tester.pumpWidget(view());
      cubit.load();
      await tester.pump();
      await tester.pump();
      expect(find.text('\$1,234.56'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Cuenta corriente'));
      await tester.pump();
      expect(find.text('\$50.00'), findsOneWidget);
      expect(find.text('\$1,234.56'), findsNothing);
    });

    testWidgets('sin cuentas muestra el estado vacío', (tester) async {
      await tester.pumpWidget(view());
      cubit.load();
      await tester.pump();
      await tester.pump();
      expect(find.text('Aún no tienes cuentas'), findsOneWidget);
    });

    testWidgets('error: mensaje y "Reintentar" vuelve a cargar', (tester) async {
      repo.failure = const Failure('técnico', 'network');
      await tester.pumpWidget(view());
      cubit.load();
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Sin conexión. Revisa tu internet e inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('técnico'), findsNothing);

      repo
        ..failure = null
        ..accounts = [savings];
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump();
      expect(find.text('\$1,234.56'), findsOneWidget);
    });

    testWidgets('el menú "Cerrar sesión" llama a onSignOut', (tester) async {
      repo.accounts = [savings];
      await tester.pumpWidget(view());
      cubit.load();
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byTooltip('Menú'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pump();
      expect(signOuts, 1);
    });
  });

  group('registerAccountsDependencies', () {
    test('registra casos de uso y fábrica de Cubit', () async {
      final getIt = GetIt.asNewInstance();
      // Cliente real con URL y clave de mentira: no abre red si no se usa.
      final client = SupabaseClient('https://example.test', 'test-key');
      addTearDown(client.dispose);
      getIt.registerSingleton<SupabaseClient>(client);

      registerAccountsDependencies(getIt);

      expect(getIt<GetAccounts>(), isA<GetAccounts>());
      expect(getIt<GetBalance>(), isA<GetBalance>());
      expect(getIt<GetTransactions>(), isA<GetTransactions>());
      final a = getIt<AccountsCubit>();
      final b = getIt<AccountsCubit>();
      expect(identical(a, b), isFalse);
      await a.close();
      await b.close();
    });
  });
}
