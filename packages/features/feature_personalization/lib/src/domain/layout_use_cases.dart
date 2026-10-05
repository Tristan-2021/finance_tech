import 'home_layout.dart';
import 'home_layout_repository.dart';

/// Layout actual, sin red y sin esperar.
class GetHomeLayout {
  final HomeLayoutRepository _repository;
  const GetHomeLayout(this._repository);

  HomeLayout call() => _repository.current;
}

/// Pide el layout más reciente; si falla, devuelve el último válido o el de
/// por defecto.
class RefreshHomeLayout {
  final HomeLayoutRepository _repository;
  const RefreshHomeLayout(this._repository);

  Future<HomeLayout> call() => _repository.refresh();
}

/// Layouts nuevos a medida que Remote Config los publica.
class WatchHomeLayout {
  final HomeLayoutRepository _repository;
  const WatchHomeLayout(this._repository);

  Stream<HomeLayout> call() => _repository.changes;
}
