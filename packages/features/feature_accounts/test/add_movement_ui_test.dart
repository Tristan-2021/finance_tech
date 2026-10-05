import 'package:core_errors/core_errors.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_accounts/src/domain/account_repository.dart';
import 'package:feature_accounts/src/domain/movement_write_repository.dart';
import 'package:feature_accounts/src/presentation/accounts_cubit.dart';
import 'package:feature_accounts/src/presentation/accounts_view.dart';
import 'package:feature_accounts/src/presentation/add_movement_cubit.dart';
import 'package:feature_accounts/src/presentation/add_movement_form.dart';
import 'package:feature_accounts/src/presentation/movements_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transaction_repository.dart';

class _FakeAccounts implements AccountRepository {
  int calls = 0;

  @override
  Future<({List<Account>? accounts, Failure? failure})> getAccounts() async {
    calls++;
    return (
      accounts: const [
        Account(
          id: 'a1',
          name: 'Cuenta de ahorros',
          type: 'savings',
          currency: 'USD',
          balanceCents: 123456,
        ),
      ],
      failure: null,
    );
  }
}

class _FakeWrite implements MovementWriteRepository {
  Failure? failure;
  final cents = <int>[];

  @override
  Future<Failure?> addMovement({
    required String accountId,
    required TransactionType type,
    required int amountCents,
    required String category,
    required String description,
  }) async {
    cents.add(amountCents);
    return failure;
  }
}

void main() {
  late _FakeAccounts accounts;
  late FakeTransactionRepository transactions;
  late _FakeWrite write;
  late AccountsCubit accountsCubit;

  setUp(() {
    accounts = _FakeAccounts();
    transactions = FakeTransactionRepository();
    write = _FakeWrite();
    accountsCubit = AccountsCubit(GetAccounts(accounts));
  });
  tearDown(() => accountsCubit.close());

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AccountsView(
          cubit: accountsCubit,
          movementsCubitFactory: (id) =>
              MovementsCubit(GetTransactions(transactions), id),
          addMovementCubitFactory: (id) => AddMovementCubit(AddMovement(write), id),
          greetingName: 'Ana',
          segment: 'joven',
          onSignOut: () {},
        ),
      ),
    );
    accountsCubit.load();
    await tester.pumpAndSettle();
  }

  Finder inForm(Finder finder) =>
      find.descendant(of: find.byType(AddMovementForm), matching: finder);

  testWidgets('un monto inválido muestra el error y no envía', (tester) async {
    await pumpView(tester);
    await tester.tap(find.text('Registrar movimiento'));
    await tester.pumpAndSettle();

    expect(find.text('Gasto manual (demostración)'), findsOneWidget);

    await tester.enterText(inForm(find.byType(TextField)).first, '0');
    await tester.tap(inForm(find.text('Registrar')));
    await tester.pump();

    expect(find.text('El monto debe ser mayor que cero.'), findsOneWidget);
    expect(write.cents, isEmpty);
  });

  testWidgets('guardar cierra el formulario y refresca saldo y movimientos', (
    tester,
  ) async {
    await pumpView(tester);
    final accountCalls = accounts.calls;
    final movementCalls = transactions.calls.length;

    await tester.tap(find.text('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(inForm(find.byType(TextField)).first, '12,30');
    await tester.tap(inForm(find.text('Registrar')));
    await tester.pumpAndSettle();

    expect(write.cents, [1230]);
    expect(find.byType(AddMovementForm), findsNothing);
    expect(accounts.calls, accountCalls + 1);
    expect(transactions.calls.length, movementCalls + 1);
    expect(transactions.calls.last.offset, 0);
  });

  testWidgets('un error del servidor se muestra y el formulario sigue abierto', (
    tester,
  ) async {
    write.failure = const Failure('x', 'insufficient_funds');
    await pumpView(tester);
    await tester.tap(find.text('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(inForm(find.byType(TextField)).first, '5000');
    await tester.tap(inForm(find.text('Registrar')));
    await tester.pumpAndSettle();

    expect(find.text('Saldo insuficiente.'), findsOneWidget);
    expect(find.byType(AddMovementForm), findsOneWidget);
  });
}
