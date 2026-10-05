import 'package:flutter/foundation.dart';

/// Estado de los reintentos HTTP, para que la interfaz muestre "Reintentando…".
/// `RetryClient` lo avisa en cada reintento (`onRetry`) y el cliente observado
/// avisa cuándo empiezan y terminan las peticiones.
class NetworkStatusNotifier extends ChangeNotifier {
  int _active = 0;
  int _retries = 0;

  /// Hay al menos una petición reintentándose.
  bool get isRetrying => _retries > 0;

  /// Reintentos acumulados desde que hay peticiones en curso.
  int get retryCount => _retries;

  void requestStarted() => _active++;

  void requestFinished() {
    if (_active > 0) _active--;
    if (_active == 0 && _retries != 0) {
      _retries = 0;
      notifyListeners();
    }
  }

  void retryStarted() {
    _retries++;
    notifyListeners();
  }
}
