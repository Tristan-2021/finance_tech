import 'package:connectivity_plus/connectivity_plus.dart';

/// Cambios de conectividad del dispositivo.
///
/// Aviso: `connectivity_plus` informa de la **interfaz de red** (wifi, datos…),
/// no de que el servidor sea alcanzable. Úsalo solo como disparador para
/// refrescar; la verdad la dan los fallos de las peticiones.
class ConnectivityMonitor {
  final Stream<List<ConnectivityResult>> _changes;

  /// Sin argumentos escucha a `connectivity_plus`; en pruebas se pasa un stream.
  ConnectivityMonitor([Stream<List<ConnectivityResult>>? changes])
    : _changes = changes ?? Connectivity().onConnectivityChanged;

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  /// `true` cuando hay alguna interfaz de red, `false` cuando no. Solo emite
  /// cuando el valor cambia.
  Stream<bool> get onlineChanges => _changes.map(_isOnline).distinct();

  /// Emite cada vez que se pasa de sin red a con red (se asume que se parte de
  /// con red).
  Stream<void> get onReconnected async* {
    var online = true;
    await for (final now in onlineChanges) {
      if (now && !online) yield null;
      online = now;
    }
  }
}
