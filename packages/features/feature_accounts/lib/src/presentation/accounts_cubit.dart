import 'package:core_errors/core_errors.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/account.dart';
import '../domain/get_accounts.dart';
import '../domain/stale_list.dart';
import 'accounts_state.dart';

class AccountsCubit extends Cubit<AccountsState> {
  final GetAccounts _getAccounts;

  AccountsCubit(this._getAccounts) : super(const AccountsState());

  AccountsState _loaded(List<Account> accounts, {int selectedIndex = 0}) {
    return AccountsState(
      status: AccountsStatus.loaded,
      accounts: accounts,
      selectedIndex: selectedIndex,
      cachedAt: accounts is StaleList<Account> ? accounts.cachedAt : null,
    );
  }

  /// Carga las cuentas mostrando "cargando". También sirve como "Reintentar"
  /// tras un error inicial.
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
    emit(_loaded(accounts));
  }

  /// Recarga sin pasar por "cargando" (pull-to-refresh, "Reintentar" del aviso
  /// de datos guardados, vuelta de la red). Si falla, conserva lo mostrado.
  Future<void> refresh() async {
    if (state.status == AccountsStatus.loading) return;
    if (state.status == AccountsStatus.error) return load();

    final result = await _getAccounts();
    if (isClosed) return;

    final accounts = result.accounts;
    if (accounts == null) return; // se conserva lo mostrado

    final selectedId = state.selected?.id;
    final index = accounts.indexWhere((a) => a.id == selectedId);
    emit(_loaded(accounts, selectedIndex: index < 0 ? 0 : index));
  }

  /// Al volver la conectividad: reintenta lo que falló o refresca lo guardado.
  Future<void> recover() =>
      state.status == AccountsStatus.error ? load() : refresh();

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
        cachedAt: state.cachedAt,
      ),
    );
  }
}
