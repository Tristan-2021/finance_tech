import 'package:core_errors/core_errors.dart';

import 'account.dart';

abstract class AccountRepository {
  /// Cuentas del usuario autenticado; el filtrado lo hace RLS en el backend.
  Future<({List<Account>? accounts, Failure? failure})> getAccounts();
}
