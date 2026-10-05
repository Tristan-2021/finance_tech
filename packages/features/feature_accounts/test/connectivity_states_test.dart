import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core_errors/core_errors.dart';
import 'package:core_network/core_network.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/domain/account_repository.dart';
import 'package:feature_accounts/src/domain/stale_list.dart';
import 'package:feature_accounts/src/presentation/accounts_cubit.dart';
import 'package:feature_accounts/src/presentation/accounts_state.dart';
import 'package:feature_accounts/src/presentation/accounts_view.dart';
import 'package:feature_accounts/src/presentation/movements_cubit.dart';
import 'package:feature_accounts/src/presentation/movements_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transaction_repository.dart';

const savings = Account(
  id: 'a1',
  name: 'Cuenta de ahorros',
  type: 'savings',
  currency: 'USD',
  balanceCents: 123456,
);

/// Repositorio de cuentas falso. Con [staleAt] devuelve la lista como servida
/// desde la caché.
class FakeAccountRepository implements AccountRepository {
  List<Account> accounts = [savings];
  DateTime? staleAt;
  Failure? failure;
  int calls = 0;

  @override
  Future<({List<Account>? accounts, Failure? failure})> getAccounts() async {
    calls++;
    if (failure != null) return (accounts: null, failure: failure);
    final stale = staleAt;
    return (
      accounts: stale == null ? accounts : StaleList<Account>(accounts, stale),
      failure: null,
    );
  }
}

final savedAt = DateTime.utc(2026, 10, 4, 12, 30);

void main() {
  late FakeAccountRepository accountsRepo;
  late FakeTransactionRepository txRepo;

  setUp(() {
    accountsRepo = FakeAccountRepository();
    txRepo = FakeTransactionRepository()..all = List.generate(3, makeTx);
  });

  group('AccountsCubit con datos guardados', () {
    late AccountsCubit cubit;
    setUp(() => cubit = AccountsCubit(GetAccounts(accountsRepo)));
    tearDown(() => cubit.close());

    test('datos de la caché quedan marcados con su fecha', () async {
      accountsRepo.staleAt = savedAt;
      await cubit.load();

      expect(cubit.state.status, AccountsStatus.loaded);
      expect(cubit.state.cachedAt, savedAt);
      expect(cubit.state.selected?.id, 'a1');
    });

    test('datos frescos no llevan fecha', () async {
      await cubit.load();
      expect(cubit.state.cachedAt, isNull);
    });

    test('refresh con datos frescos quita la marca de guardados', () async {
      accountsRepo.staleAt = savedAt;
      await cubit.load();

      accountsRepo.staleAt = null;
      await cubit.refresh();

      expect(cubit.state.cachedAt, isNull);
      expect(cubit.state.status, AccountsStatus.loaded);
    });

    test('refresh que falla conserva lo mostrado', () async {
      await cubit.load();

      accountsRepo.failure = const Failure('sin red', 'network');
      await cubit.refresh();

      expect(cubit.state.status, AccountsStatus.loaded);
      expect(cubit.state.selected?.id, 'a1');
    });

    test('recover tras un error inicial vuelve a cargar', () async {
      accountsRepo.failure = const Failure('sin red', 'network');
      await cubit.load();
      expect(cubit.state.status, AccountsStatus.error);

      accountsRepo.failure = null;
      await cubit.recover();

      expect(cubit.state.status, AccountsStatus.loaded);
    });

    test('cambiar de cuenta conserva la marca de guardados', () async {
      accountsRepo
        ..accounts = [
          savings,
          const Account(
            id: 'a2',
            name: 'Cuenta corriente',
            type: 'checking',
            currency: 'USD',
            balanceCents: 5000,
          ),
        ]
        ..staleAt = savedAt;
      await cubit.load();

      cubit.selectAccount(1);

      expect(cubit.state.selected?.id, 'a2');
      expect(cubit.state.cachedAt, savedAt);
    });
  });

  group('MovementsCubit con datos guardados', () {
    late MovementsCubit cubit;
    setUp(() => cubit = MovementsCubit(GetTransactions(txRepo), 'a1'));
    tearDown(() => cubit.close());

    test('la primera página de la caché queda marcada con su fecha', () async {
      txRepo.staleAt = savedAt;
      await cubit.loadFirst();

      expect(cubit.state.cachedAt, savedAt);
      expect(cubit.state.items.length, 3);
    });

    test('refresh con datos frescos quita la marca', () async {
      txRepo.staleAt = savedAt;
      await cubit.loadFirst();

      txRepo.staleAt = null;
      await cubit.refresh();

      expect(cubit.state.cachedAt, isNull);
    });

    test('recover tras un error inicial vuelve a cargar', () async {
      txRepo.failure = const Failure('sin red', 'network');
      await cubit.loadFirst();
      expect(cubit.state.status, MovementsStatus.error);

      txRepo.failure = null;
      await cubit.recover();

      expect(cubit.state.status, MovementsStatus.loaded);
      expect(cubit.state.items.length, 3);
    });

    test('recover con datos mostrados los refresca sin borrarlos', () async {
      txRepo.staleAt = savedAt;
      await cubit.loadFirst();

      txRepo.staleAt = null;
      txRepo.failure = const Failure('sin red', 'network');
      await cubit.recover(); // sigue sin red: se conserva lo mostrado

      expect(cubit.state.items.length, 3);
      expect(cubit.state.cachedAt, savedAt);
      expect(cubit.state.refreshError, isNotNull);
    });
  });

  group('pantalla', () {
    late AccountsCubit accountsCubit;
    late NetworkStatusNotifier status;
    late StreamController<List<ConnectivityResult>> connectivityEvents;

    setUp(() {
      accountsCubit = AccountsCubit(GetAccounts(accountsRepo));
      status = NetworkStatusNotifier();
      connectivityEvents = StreamController<List<ConnectivityResult>>.broadcast();
    });
    tearDown(() async {
      await accountsCubit.close();
      await connectivityEvents.close();
    });

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AccountsView(
            cubit: accountsCubit,
            movementsCubitFactory: (id) =>
                MovementsCubit(GetTransactions(txRepo), id),
            greetingName: 'Ana',
            segment: 'joven',
            onSignOut: () {},
            networkStatus: status,
            connectivity: ConnectivityMonitor(connectivityEvents.stream),
          ),
        ),
      );
      accountsCubit.load();
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('con datos guardados avisa con la fecha de guardado', (
      tester,
    ) async {
      accountsRepo.staleAt = savedAt;
      txRepo.staleAt = savedAt;
      await open(tester);

      expect(find.textContaining('Mostrando datos guardados el'), findsOneWidget);
      expect(find.textContaining('4 oct 2026'), findsWidgets);
      // Los datos siguen visibles junto al aviso.
      expect(find.text('\$1,234.56'), findsOneWidget);
      expect(find.text('Mov 0'), findsOneWidget);
    });

    testWidgets('con datos frescos no hay aviso', (tester) async {
      await open(tester);
      expect(find.textContaining('Mostrando datos guardados'), findsNothing);
    });

    testWidgets('"Reintentar" del aviso refresca y lo quita al recuperar', (
      tester,
    ) async {
      accountsRepo.staleAt = savedAt;
      txRepo.staleAt = savedAt;
      await open(tester);
      expect(find.textContaining('Mostrando datos guardados'), findsOneWidget);

      accountsRepo.staleAt = null;
      txRepo.staleAt = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Mostrando datos guardados'), findsNothing);
      expect(find.text('\$1,234.56'), findsOneWidget);
    });

    testWidgets('si "Reintentar" sigue sin red, los datos no se borran', (
      tester,
    ) async {
      accountsRepo.staleAt = savedAt;
      txRepo.staleAt = savedAt;
      await open(tester);

      accountsRepo.failure = const Failure('sin red', 'network');
      txRepo.failure = const Failure('sin red', 'network');
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Mostrando datos guardados'), findsOneWidget);
      expect(find.text('\$1,234.56'), findsOneWidget);
      expect(find.text('Mov 0'), findsOneWidget);
    });

    testWidgets('muestra "Reintentando…" mientras se reintenta', (tester) async {
      await open(tester);
      expect(find.text('Reintentando…'), findsNothing);

      status
        ..requestStarted()
        ..retryStarted();
      await tester.pump();
      expect(find.text('Reintentando…'), findsOneWidget);

      status.requestFinished();
      await tester.pump();
      expect(find.text('Reintentando…'), findsNothing);
    });

    testWidgets('al volver la conectividad refresca solo', (tester) async {
      accountsRepo.staleAt = savedAt;
      txRepo.staleAt = savedAt;
      await open(tester);
      expect(find.textContaining('Mostrando datos guardados'), findsOneWidget);
      final callsBefore = accountsRepo.calls;

      // La red se recupera: ahora el servidor responde con datos frescos.
      accountsRepo.staleAt = null;
      txRepo.staleAt = null;
      connectivityEvents
        ..add([ConnectivityResult.none])
        ..add([ConnectivityResult.wifi]);
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(accountsRepo.calls, greaterThan(callsBefore));
      expect(find.textContaining('Mostrando datos guardados'), findsNothing);
    });
  });
}
