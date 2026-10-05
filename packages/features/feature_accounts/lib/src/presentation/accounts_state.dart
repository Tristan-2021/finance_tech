import '../domain/account.dart';

enum AccountsStatus { loading, loaded, error }

class AccountsState {
  final AccountsStatus status;
  final List<Account> accounts;
  final int selectedIndex;

  /// Mensaje de `messageForFailure` cuando [status] es error.
  final String? message;

  const AccountsState({
    this.status = AccountsStatus.loading,
    this.accounts = const [],
    this.selectedIndex = 0,
    this.message,
  });

  Account? get selected => accounts.isEmpty ? null : accounts[selectedIndex];
}
