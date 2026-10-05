import 'package:core_errors/core_errors.dart';
import 'package:feature_accounts/src/domain/account.dart';
import 'package:feature_accounts/src/domain/account_repository.dart';
import 'package:feature_accounts/src/domain/get_balance.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAccountRepository implements AccountRepository {
  List<Account>? accounts;
  Failure? failure;

  @override
  Future<({List<Account>? accounts, Failure? failure})> getAccounts() async =>
      (accounts: accounts, failure: failure);
}

void main() {
  late FakeAccountRepository repo;
  setUp(() => repo = FakeAccountRepository());

  const checking = Account(
    id: 'a1',
    name: 'Cuenta principal',
    type: 'checking',
    currency: 'USD',
    balanceCents: 50000,
  );
  const savings = Account(
    id: 'a2',
    name: 'Ahorros',
    type: 'savings',
    currency: 'USD',
    balanceCents: 1,
  );

  group('GetBalance', () {
    test('éxito: devuelve la primera cuenta', () async {
      repo.accounts = [checking, savings];
      final r = await GetBalance(repo)();
      expect(r.failure, isNull);
      expect(r.account, same(checking));
      expect(r.account?.balanceCents, 50000);
    });

    test('lista vacía -> no_account', () async {
      repo.accounts = [];
      final r = await GetBalance(repo)();
      expect(r.account, isNull);
      expect(r.failure?.code, 'no_account');
    });

    test('propaga el Failure del repositorio', () async {
      repo.failure = const Failure('denegado', 'rls_denied');
      final r = await GetBalance(repo)();
      expect(r.account, isNull);
      expect(r.failure?.code, 'rls_denied');
    });
  });
}
