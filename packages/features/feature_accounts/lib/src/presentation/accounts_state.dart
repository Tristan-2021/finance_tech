import '../domain/account.dart';

enum AccountsStatus { loading, loaded, error }

class AccountsState {
  final AccountsStatus status;
  final List<Account> accounts;
  final int selectedIndex;

  /// Mensaje de `messageForFailure` cuando [status] es error.
  final String? message;

  /// Si no es `null`, los datos vienen de una copia guardada en esa fecha
  /// (UTC) porque no se pudo contactar al servidor.
  final DateTime? cachedAt;

  const AccountsState({
    this.status = AccountsStatus.loading,
    this.accounts = const [],
    this.selectedIndex = 0,
    this.message,
    this.cachedAt,
  });

  Account? get selected => accounts.isEmpty ? null : accounts[selectedIndex];
}
