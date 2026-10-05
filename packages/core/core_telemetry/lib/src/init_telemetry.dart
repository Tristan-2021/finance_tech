import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

import 'firebase_telemetry.dart';
import 'telemetry.dart';

/// Con `--dart-define=TELEMETRY_DEBUG=true` la recolección también funciona en
/// depuración (para poder demostrarla).
const _telemetryInDebug = bool.fromEnvironment('TELEMETRY_DEBUG');

/// Prepara la telemetría y engancha los errores no capturados de Flutter y de
/// la plataforma a Crashlytics (siempre por el filtro de privacidad).
///
/// La recolección está desactivada en depuración salvo `TELEMETRY_DEBUG`. Si
/// Firebase no se inicializó, devuelve [NoopTelemetry].
Future<Telemetry> initTelemetry() async {
  if (Firebase.apps.isEmpty) return const NoopTelemetry();

  try {
    final enabled = !kDebugMode || _telemetryInDebug;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
    await FirebasePerformance.instance.setPerformanceCollectionEnabled(enabled);

    const telemetry = FirebaseTelemetry();

    FlutterError.onError = (details) {
      // Se sigue mostrando el error en la consola, como hace Flutter por defecto.
      FlutterError.presentError(details);
      telemetry.recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        fatal: true,
        reason: 'flutter_error',
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      telemetry.recordError(error, stack, fatal: true, reason: 'platform_error');
      return true;
    };

    return telemetry;
  } catch (_) {
    return const NoopTelemetry();
  }
}
