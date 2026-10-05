import 'package:core_errors/core_errors.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/get_transactions.dart';
import 'movements_state.dart';

/// Crea el Cubit de movimientos de una cuenta. Se registra en GetIt para que
/// la vista no dependa del contenedor.
typedef MovementsCubitFactory = MovementsCubit Function(String accountId);

/// Movimientos paginados de una cuenta (offset/limit, del más reciente al más
/// antiguo). Un fallo en una página posterior conserva lo ya mostrado.
class MovementsCubit extends Cubit<MovementsState> {
  static const pageSize = 20;

  final GetTransactions _getTransactions;
  final String accountId;

  /// Una sola petición a la vez (carga, siguiente página o refresco).
  bool _busy = false;

  MovementsCubit(this._getTransactions, this.accountId)
    : super(const MovementsState());

  String _message(Failure? failure) =>
      messageForFailure(failure ?? const Failure('', 'unknown'));

  /// Primera página. También sirve como "Reintentar" tras un error inicial.
  Future<void> loadFirst() async {
    _busy = true;
    emit(const MovementsState());
    final result = await _getTransactions(accountId, offset: 0, limit: pageSize);
    _busy = false;
    if (isClosed) return;

    final items = result.transactions;
    if (items == null) {
      emit(
        MovementsState(
          status: MovementsStatus.error,
          message: _message(result.failure),
        ),
      );
      return;
    }
    emit(
      MovementsState(
        status: MovementsStatus.loaded,
        items: items,
        hasMore: items.length >= pageSize,
      ),
    );
  }

  /// Página siguiente. Tras un fallo, solo se reintenta con [retry] (para que
  /// el desplazamiento no repita la petición en bucle).
  Future<void> loadMore({bool retry = false}) async {
    if (_busy || state.status != MovementsStatus.loaded || !state.hasMore) {
      return;
    }
    if (state.loadMoreError != null && !retry) return;

    _busy = true;
    emit(state.copyWith(loadingMore: true));
    final result = await _getTransactions(
      accountId,
      offset: state.items.length,
      limit: pageSize,
    );
    _busy = false;
    if (isClosed) return;

    final page = result.transactions;
    if (page == null) {
      emit(
        state.copyWith(
          loadingMore: false,
          loadMoreError: _message(result.failure),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        items: [...state.items, ...page],
        hasMore: page.length >= pageSize,
        loadingMore: false,
      ),
    );
  }

  /// Pull-to-refresh: vuelve a la primera página. Si falla y ya había datos,
  /// los conserva y avisa con [MovementsState.refreshError].
  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    final result = await _getTransactions(accountId, offset: 0, limit: pageSize);
    _busy = false;
    if (isClosed) return;

    final items = result.transactions;
    if (items == null) {
      final message = _message(result.failure);
      emit(
        state.items.isEmpty
            ? MovementsState(status: MovementsStatus.error, message: message)
            : state.copyWith(refreshError: message),
      );
      return;
    }
    emit(
      MovementsState(
        status: MovementsStatus.loaded,
        items: items,
        hasMore: items.length >= pageSize,
      ),
    );
  }
}
