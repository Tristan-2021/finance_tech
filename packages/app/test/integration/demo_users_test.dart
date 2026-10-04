@Tags(['integration'])
library;

import 'package:core_network/core_network.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Sin --dart-define (como en el CI) las pruebas se saltan.
final String? _skip = (_url.isEmpty || _key.isEmpty)
    ? 'Requiere backend local y --dart-define de SUPABASE_URL y SUPABASE_ANON_KEY'
    : null;

const _password = 'demo1234';

class _Session {
  final SupabaseClient client;
  final AuthRepositoryImpl auth;
  const _Session(this.client, this.auth);

  GetBalance get getBalance => GetBalance(
    AccountRepositoryImpl(SupabaseAccountsRemoteDataSource(client)),
  );

  GetTransactions get getTransactions => GetTransactions(
    TransactionRepositoryImpl(SupabaseTransactionsRemoteDataSource(client)),
  );
}

Future<_Session> _login(String email) async {
  final client = SupabaseClient(_url, _key);
  addTearDown(client.dispose);
  final auth = AuthRepositoryImpl(SupabaseAuthRemoteDataSource(client));
  final failure = await auth.signIn(email: email, password: _password);
  expect(failure, isNull, reason: 'login de $email');
  return _Session(client, auth);
}

void main() {
  const demos = [
    (email: 'joven@demo.com', segment: 'joven'),
    (email: 'adulto@demo.com', segment: 'adulto'),
  ];

  for (final demo in demos) {
    group(demo.email, () {
      test('segmento correcto', () async {
        final s = await _login(demo.email);
        final r = await GetProfileSegment(s.auth)();
        expect(r.failure, isNull);
        expect(r.segment, demo.segment);
      }, skip: _skip);

      test('saldo coherente con sus movimientos', () async {
        final s = await _login(demo.email);
        final balance = await s.getBalance();
        expect(balance.failure, isNull);
        final account = balance.account!;

        final tx = await s.getTransactions(account.id, limit: 100);
        expect(tx.failure, isNull);
        final list = tx.transactions!;
        expect(list, isNotEmpty);

        // Más reciente primero: su balance_after es el saldo actual.
        expect(list.first.balanceAfterCents, account.balanceCents);

        // El seed retrasa `created_at`, así que el bono de bienvenida no tiene
        // por qué ser el más antiguo: basta con que exista (credit 500.00).
        expect(
          list.any(
            (t) => t.type == TransactionType.credit && t.amountCents == 50000,
          ),
          isTrue,
          reason: 'bono de bienvenida credit 500.00',
        );

        // Créditos menos débitos deben dar el saldo actual (en centavos).
        final net = list.fold<int>(
          0,
          (sum, t) => t.type == TransactionType.credit
              ? sum + t.amountCents
              : sum - t.amountCents,
        );
        expect(net, account.balanceCents);
      }, skip: _skip);
    });
  }

  test('un usuario no ve cuentas ni movimientos ajenos', () async {
    final joven = await _login('joven@demo.com');
    final adulto = await _login('adulto@demo.com');

    final jovenAccount = (await joven.getBalance()).account!;
    final adultoAccount = (await adulto.getBalance()).account!;
    expect(jovenAccount.id, isNot(adultoAccount.id));

    // RLS: pedir los movimientos de la cuenta ajena devuelve vacío.
    final cruzado = await joven.getTransactions(adultoAccount.id);
    expect(cruzado.failure, isNull);
    expect(cruzado.transactions, isEmpty);
  }, skip: _skip);
}
