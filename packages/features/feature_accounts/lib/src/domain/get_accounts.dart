import 'package:core_errors/core_errors.dart';

import 'account.dart';
import 'account_repository.dart';

class GetAccounts {
  final AccountRepository _repository;
  const GetAccounts(this._repository);

  /// Cuentas del usuario autenticado (RLS filtra en el backend).
  Future<({List<Account>? accounts, Failure? failure})> call() =>
      _repository.getAccounts();
}
