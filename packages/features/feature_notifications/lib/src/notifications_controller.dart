import 'dart:async';

import 'package:core_telemetry/core_telemetry.dart';

import 'domain/device_token_repository.dart';
import 'domain/messaging_gateway.dart';
import 'domain/push_message.dart';

/// Ciclo de vida de las notificaciones push, pensado para el shell:
///
/// - [initialize]: al arrancar, antes del login.
/// - [start]: tras autenticarse.
/// - [stop]: al cerrar sesión, antes de cerrar la sesión de Supabase.
///
/// Todo es de mejor esfuerzo: ningún fallo de red, de permiso o de plugin
/// impide usar la app ni cerrar sesión. Nunca se registra el token.
///
/// Telemetría: `push_permission` (`result`: `granted` o `denied`) y
/// `push_opened` (`source`: `foreground`, `background` o `terminated`). Nunca el
/// texto del mensaje ni el token.
class NotificationsController {
  final MessagingGateway _gateway;
  final DeviceTokenRepository _tokens;
  final Telemetry _telemetry;

  /// Tiempo máximo de cada paso de [stop].
  final Duration stopTimeout;

  void Function()? _onOpenAccounts;
  bool _initialized = false;
  bool _askedThisSession = false;

  /// Una notificación abrió la app antes de que hubiera sesión: se atiende en
  /// cuanto el shell llama a [start].
  bool _pendingOpen = false;

  String? _registeredToken;
  StreamSubscription<String>? _refreshSubscription;

  NotificationsController(
    this._gateway,
    this._tokens, {
    this.stopTimeout = const Duration(seconds: 3),
    this._telemetry = const NoopTelemetry(),
  });

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _gateway.initialize();
    } catch (_) {
      // Sin canal las notificaciones pueden no verse, pero la app sigue.
    }
    try {
      _gateway.onForegroundMessage.listen(_showForeground);
      _gateway.onOpened.listen((message) => _handleOpen(message.origin));
    } catch (_) {
      // Si Firebase no arrancó, la app funciona sin avisos.
    }
    try {
      if (await _gateway.getInitialMessage() != null) {
        _handleOpen(PushOrigin.terminated);
      }
    } catch (_) {}
  }

  Future<void> start({required void Function() onOpenAccounts}) async {
    _onOpenAccounts = onOpenAccounts;
    if (_pendingOpen) {
      _pendingOpen = false;
      onOpenAccounts();
    }

    if (_askedThisSession) return;
    _askedThisSession = true;

    var granted = false;
    try {
      granted = await _gateway.requestPermission();
    } catch (_) {
      // Un fallo al pedir el permiso se trata como denegado.
    }
    _telemetry.logEvent('push_permission', {
      'result': granted ? 'granted' : 'denied',
    });
    if (!granted) return;

    await _refreshSubscription?.cancel();
    _refreshSubscription = _gateway.onTokenRefresh.listen(_register);
    try {
      final token = await _gateway.getToken();
      if (token != null) await _register(token);
    } catch (_) {}
  }

  Future<void> stop() async {
    _onOpenAccounts = null;
    _askedThisSession = false;
    _pendingOpen = false;
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;

    final known = _registeredToken;
    _registeredToken = null;

    // Primero el backend (si no, el siguiente usuario del teléfono recibiría
    // los avisos de este) y después el token de FCM.
    await _bestEffort(() async {
      final token = known ?? await _gateway.getToken();
      if (token != null) await _tokens.unregister(token);
    });
    await _bestEffort(_gateway.deleteToken);
  }

  Future<void> _register(String token) async {
    try {
      final failure = await _tokens.register(token);
      if (failure == null) _registeredToken = token;
    } catch (_) {}
  }

  void _showForeground(PushMessage message) {
    if (!message.isDisplayable) return;
    _gateway.showLocal(message).catchError((_) {});
  }

  void _handleOpen(PushOrigin origin) {
    _telemetry.logEvent('push_opened', {'source': origin.name});
    final open = _onOpenAccounts;
    if (open == null) {
      _pendingOpen = true;
    } else {
      open();
    }
  }

  Future<void> _bestEffort(Future<void> Function() action) async {
    try {
      await action().timeout(stopTimeout);
    } catch (_) {}
  }
}
