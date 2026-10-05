import 'package:core_errors/core_errors.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/domain/account_repository.dart';
import 'package:feature_accounts/src/presentation/accounts_cubit.dart';
import 'package:feature_accounts/src/presentation/accounts_view.dart';
import 'package:feature_accounts/src/presentation/movements_cubit.dart';
import 'package:feature_accounts/src/presentation/movements_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transaction_repository.dart';

class FakeAccountRepository implements AccountRepository {
  @override
  Future<({List<Account>? accounts, Failure? failure})> getAccounts() async => (
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

void main() {
  late FakeTransactionRepository repo;
  setUp(() => repo = FakeTransactionRepository());

  group('MovementsCubit', () {
    late MovementsCubit cubit;
    setUp(() => cubit = MovementsCubit(GetTransactions(repo), 'a1'));
    tearDown(() => cubit.close());

    test('primera página: 20 movimientos y quedan más', () async {
      repo.all = List.generate(25, makeTx);
      await cubit.loadFirst();

      expect(cubit.state.status, MovementsStatus.loaded);
      expect(cubit.state.items.length, 20);
      expect(cubit.state.hasMore, isTrue);
      expect(repo.calls.single, (accountId: 'a1', offset: 0, limit: 20));
    });

    test('la siguiente página se agrega y no quedan más', () async {
      repo.all = List.generate(25, makeTx);
      await cubit.loadFirst();
      await cubit.loadMore();

      expect(cubit.state.items.length, 25);
      expect(cubit.state.items.last.id, 't24');
      expect(cubit.state.hasMore, isFalse);
      expect(repo.calls.last, (accountId: 'a1', offset: 20, limit: 20));
    });

    test('sin más páginas no vuelve a pedir', () async {
      repo.all = List.generate(5, makeTx);
      await cubit.loadFirst();
      expect(cubit.state.hasMore, isFalse);

      await cubit.loadMore();
      expect(repo.calls.length, 1);
    });

    test('una página justa de 20 pide otra y termina al venir vacía', () async {
      repo.all = List.generate(20, makeTx);
      await cubit.loadFirst();
      expect(cubit.state.hasMore, isTrue);

      await cubit.loadMore();
      expect(cubit.state.items.length, 20);
      expect(cubit.state.hasMore, isFalse);
    });

    test('lista vacía queda cargada sin movimientos', () async {
      await cubit.loadFirst();
      expect(cubit.state.status, MovementsStatus.loaded);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.hasMore, isFalse);
    });

    test('error en la primera página y reintento', () async {
      repo.failure = const Failure('técnico', 'network');
      await cubit.loadFirst();
      expect(cubit.state.status, MovementsStatus.error);
      expect(
        cubit.state.message,
        'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
      );

      repo
        ..failure = null
        ..all = List.generate(3, makeTx);
      await cubit.loadFirst();
      expect(cubit.state.status, MovementsStatus.loaded);
      expect(cubit.state.items.length, 3);
    });

    test('fallo en la segunda página conserva lo mostrado', () async {
      repo.all = List.generate(25, makeTx);
      await cubit.loadFirst();

      repo.failure = const Failure('técnico', 'network');
      await cubit.loadMore();

      expect(cubit.state.status, MovementsStatus.loaded);
      expect(cubit.state.items.length, 20);
      expect(cubit.state.hasMore, isTrue);
      expect(cubit.state.loadingMore, isFalse);
      expect(cubit.state.loadMoreError, isNotNull);
    });

    test('tras un fallo no reintenta solo, pero sí con retry', () async {
      repo.all = List.generate(25, makeTx);
      await cubit.loadFirst();
      repo.failure = const Failure('técnico', 'network');
      await cubit.loadMore();
      final callsAfterFailure = repo.calls.length;

      repo.failure = null;
      await cubit.loadMore(); // el desplazamiento no debe repetir en bucle
      expect(repo.calls.length, callsAfterFailure);

      await cubit.loadMore(retry: true);
      expect(cubit.state.items.length, 25);
      expect(cubit.state.loadMoreError, isNull);
    });

    test('ignora una petición mientras otra está en curso', () async {
      repo.all = List.generate(40, makeTx);
      await cubit.loadFirst();

      final first = cubit.loadMore();
      final second = cubit.loadMore();
      await Future.wait([first, second]);

      expect(cubit.state.items.length, 40);
      expect(repo.calls.length, 2); // primera página + una sola siguiente
    });

    test('refresh reemplaza por la primera página', () async {
      repo.all = List.generate(25, makeTx);
      await cubit.loadFirst();
      await cubit.loadMore();
      expect(cubit.state.items.length, 25);

      repo.all = List.generate(3, makeTx);
      await cubit.refresh();
      expect(cubit.state.items.length, 3);
      expect(cubit.state.hasMore, isFalse);
    });

    test('refresh que falla conserva los datos y avisa', () async {
      repo.all = List.generate(5, makeTx);
      await cubit.loadFirst();

      repo.failure = const Failure('técnico', 'network');
      await cubit.refresh();

      expect(cubit.state.status, MovementsStatus.loaded);
      expect(cubit.state.items.length, 5);
      expect(cubit.state.refreshError, isNotNull);
    });
  });

  group('lista en pantalla', () {
    late AccountsCubit accountsCubit;
    MovementsCubit? movementsCubit;

    setUp(() {
      accountsCubit = AccountsCubit(GetAccounts(FakeAccountRepository()));
      movementsCubit = null;
    });
    tearDown(() => accountsCubit.close());

    Widget view() => MaterialApp(
      theme: AppTheme.light(),
      home: AccountsView(
        cubit: accountsCubit,
        movementsCubitFactory: (id) =>
            movementsCubit = MovementsCubit(GetTransactions(repo), id),
        greetingName: 'Ana',
        segment: 'joven',
        onSignOut: () {},
      ),
    );

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(view());
      accountsCubit.load();
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('cada fila muestra descripción, fecha, monto con signo y saldo', (
      tester,
    ) async {
      repo.all = List.generate(3, makeTx);
      await open(tester);

      expect(find.text('Movimientos'), findsOneWidget);
      expect(find.text('Mov 0'), findsOneWidget);
      expect(find.text('Mov 1'), findsOneWidget);
      expect(find.text('+\$1.00'), findsOneWidget); // ingreso
      expect(find.text('−\$2.00'), findsOneWidget); // egreso
      expect(find.textContaining('comida · 4 oct 2026'), findsNWidgets(3));
      expect(find.text('Saldo: \$500.00'), findsNWidgets(3));
    });

    testWidgets('sin movimientos muestra el estado vacío', (tester) async {
      await open(tester);
      expect(find.text('Aún no tienes movimientos'), findsOneWidget);
    });

    testWidgets('error de red: mensaje y "Reintentar" carga los datos', (
      tester,
    ) async {
      repo.failure = const Failure('técnico', 'network');
      await open(tester);
      expect(
        find.text('Sin conexión. Revisa tu internet e inténtalo de nuevo.'),
        findsOneWidget,
      );

      repo
        ..failure = null
        ..all = List.generate(2, makeTx);
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Mov 0'), findsOneWidget);
    });

    testWidgets('al llegar al final del scroll pide la página siguiente', (
      tester,
    ) async {
      repo.all = List.generate(25, makeTx);
      await open(tester);
      expect(repo.calls.length, 1);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await tester.pump();
      await tester.pump();

      expect(repo.calls.length, 2);
      expect(repo.calls.last.offset, 20);
      expect(movementsCubit?.state.items.length, 25);
    });

    testWidgets('un fallo en la segunda página muestra el aviso y conserva lo cargado', (
      tester,
    ) async {
      repo.all = List.generate(25, makeTx);
      await open(tester);

      repo.failure = const Failure('técnico', 'network');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Sin conexión. Revisa tu internet e inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(movementsCubit?.state.items.length, 20);
    });
  });
}
