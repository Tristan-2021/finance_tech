import 'home_layout.dart';

abstract interface class HomeLayoutRepository {
  /// Último layout válido (descargado o por defecto). Se lee sin red y nunca
  /// espera.
  HomeLayout get current;

  /// Pide el layout más reciente. Si falla, devuelve el último válido.
  Future<HomeLayout> refresh();

  /// Avisa cuando Remote Config publica un layout nuevo y válido.
  Stream<HomeLayout> get changes;
}
