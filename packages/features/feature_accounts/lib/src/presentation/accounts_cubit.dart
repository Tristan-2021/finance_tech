import 'package:core_errors/core_errors.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/get_accounts.dart';
import 'accounts_state.dart';

class AccountsCubit extends Cubit<AccountsState> {
  final GetAccounts _getAccounts;

  AccountsCubit(this._getAccounts) : super(const AccountsState());

  /// Carga las cuentas. También sirve como "Reintentar".
  Future<void> load() async {
    emit(const AccountsState());
    final result = await _getAccounts();
    if (isClosed) return;

    final accounts = result.accounts;
    if (accounts == null) {
      emit(
        AccountsState(
          status: AccountsStatus.error,
          message: messageForFailure(
            result.failure ?? const Failure('', 'unknown'),
          ),
        ),
      );
      return;
    }
    emit(AccountsState(status: AccountsStatus.loaded, accounts: accounts));
  }

  void selectAccount(int index) {
    if (index == state.selectedIndex ||
        index < 0 ||
        index >= state.accounts.length) {
      return;
    }
    emit(
      AccountsState(
        status: state.status,
        accounts: state.accounts,
        selectedIndex: index,
      ),
    );
  }
}
