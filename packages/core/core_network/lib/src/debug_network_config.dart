import 'package:flutter/foundation.dart';

/// Configuración observable de los fallos que se inyectan en la red. Solo para
/// depuración y demostraciones: quien la crea decide que exista únicamente en
/// builds de depuración.
class DebugNetworkConfig extends ChangeNotifier {
  /// Latencias artificiales que ofrece el panel.
  static const latencyOptions = [
    Duration.zero,
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 8),
  ];

  bool _offline = false;
  Duration _latency = Duration.zero;
  int _failurePercent = 0;

  /// Modo sin conexión: cada petición falla con `SocketException`.
  bool get offline => _offline;
  set offline(bool value) {
    if (value == _offline) return;
    _offline = value;
    notifyListeners();
  }

  /// Espera artificial antes de cada petición.
  Duration get latency => _latency;
  set latency(Duration value) {
    if (value == _latency) return;
    _latency = value;
    notifyListeners();
  }

  /// Porcentaje (0 a 100) de peticiones que reciben un 503 forzado.
  int get failurePercent => _failurePercent;
  set failurePercent(int value) {
    final clamped = value < 0 ? 0 : (value > 100 ? 100 : value);
    if (clamped == _failurePercent) return;
    _failurePercent = clamped;
    notifyListeners();
  }

  bool get isDefault =>
      !_offline && _latency == Duration.zero && _failurePercent == 0;

  /// Vuelve a la red normal.
  void reset() {
    if (isDefault) return;
    _offline = false;
    _latency = Duration.zero;
    _failurePercent = 0;
    notifyListeners();
  }
}
