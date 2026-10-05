import '../domain/transaction.dart';

enum MovementsStatus { loading, loaded, error }

class MovementsState {
  final MovementsStatus status;
  final List<Transaction> items;

  /// Puede haber una página más (la última página llegó llena).
  final bool hasMore;
  final bool loadingMore;

  /// Si no es `null`, la primera página viene de una copia guardada en esa
  /// fecha (UTC) porque no se pudo contactar al servidor.
  final DateTime? cachedAt;

  /// Fallo al cargar la página siguiente: lo ya mostrado se conserva.
  final String? loadMoreError;

  /// Fallo al refrescar con datos ya mostrados: se avisa sin borrar la lista.
  final String? refreshError;

  /// Fallo de la primera carga (cuando [status] es error).
  final String? message;

  const MovementsState({
    this.status = MovementsStatus.loading,
    this.items = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.cachedAt,
    this.loadMoreError,
    this.refreshError,
    this.message,
  });

  /// Los datos (`status`, `items`, `hasMore`, `loadingMore`, `cachedAt`) se
  /// conservan si no se pasan. Los errores y el mensaje se reemplazan siempre:
  /// sin argumento quedan en `null`.
  MovementsState copyWith({
    MovementsStatus? status,
    List<Transaction>? items,
    bool? hasMore,
    bool? loadingMore,
    String? loadMoreError,
    String? refreshError,
    String? message,
  }) {
    return MovementsState(
      status: status ?? this.status,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      cachedAt: cachedAt,
      loadMoreError: loadMoreError,
      refreshError: refreshError,
      message: message,
    );
  }
}
