import 'package:core_errors/core_errors.dart';

import 'account.dart';
import 'account_repository.dart';

class GetBalance {
  final AccountRepository _repository;
  const GetBalance(this._repository);

  /// Devuelve la cuenta principal (la primera) con su saldo.
  Future<({Account? account, Failure? failure})> call() async {
    final r = await _repository.getAccounts();
    if (r.failure != null) return (account: null, failure: r.failure);
    final accounts = r.accounts ?? const <Account>[];
    if (accounts.isEmpty) {
      return (
        account: null,
        failure: const Failure('El usuario no tiene cuentas', 'no_account'),
      );
    }
    return (account: accounts.first, failure: null);
  }
}
