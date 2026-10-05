import 'package:core_telemetry/core_telemetry.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import 'routes.dart';

/// Registra un evento desde el shell si hay telemetría registrada. Solo
/// parámetros permitidos por el filtro de privacidad (`screen`, `segment`…):
/// nunca correos, nombres ni importes.
void trackEvent(String name, [Map<String, Object?> params = const {}]) {
  final getIt = GetIt.instance;
  if (getIt.isRegistered<Telemetry>()) {
    getIt<Telemetry>().logEvent(name, params);
  }
}

/// Registra `screen_viewed` al entrar al login o al registro. Las pestañas del
/// home registran el suyo desde `WelcomePage`.
class ScreenViewObserver extends NavigatorObserver {
  static const _screens = {
    AppRoutes.login: 'login',
    AppRoutes.register: 'register',
  };

  void _log(Route<dynamic>? route) {
    final screen = _screens[route?.settings.name];
    if (screen != null) trackEvent('screen_viewed', {'screen': screen});
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _log(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _log(newRoute);
}
