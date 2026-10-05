import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

import 'telemetry.dart';
import 'telemetry_sanitizer.dart';

/// [Telemetry] sobre Firebase. Todo pasa por [TelemetrySanitizer] y ningún
/// fallo de los plugins llega a la app.
class FirebaseTelemetry implements Telemetry {
  const FirebaseTelemetry();

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // La telemetría nunca debe romper la app.
    }
  }

  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) {
    final safeName = TelemetrySanitizer.eventName(name);
    if (safeName == null) return;

    // Analytics solo admite texto y números: los booleanos van como 1 o 0.
    final safeParams = TelemetrySanitizer.params(
      params,
    ).map<String, Object>((key, value) => MapEntry(key, value is bool ? (value ? 1 : 0) : value));

    unawaited(
      _guard(
        () => FirebaseAnalytics.instance.logEvent(
          name: safeName,
          parameters: safeParams.isEmpty ? null : safeParams,
        ),
      ),
    );
  }

  @override
  void recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
    String? reason,
  }) {
    final safeReason = reason == null ? null : TelemetrySanitizer.text(reason);
    unawaited(
      _guard(
        () => FirebaseCrashlytics.instance.recordError(
          SanitizedError.from(error),
          stack,
          reason: safeReason,
          fatal: fatal,
        ),
      ),
    );
  }

  @override
  void setSegment(String? segment) {
    final value = segment == null ? null : TelemetrySanitizer.text(segment);
    unawaited(
      _guard(() async {
        await FirebaseAnalytics.instance.setUserProperty(
          name: 'segment',
          value: value,
        );
        await FirebaseCrashlytics.instance.setCustomKey('segment', value ?? '');
      }),
    );
  }

  @override
  Future<T> trace<T>(String name, Future<T> Function() action) async {
    final safeName = TelemetrySanitizer.eventName(name);
    if (safeName == null) return action();

    Trace? perfTrace;
    try {
      perfTrace = FirebasePerformance.instance.newTrace(safeName);
      await perfTrace.start();
    } catch (_) {
      perfTrace = null;
    }
    try {
      return await action();
    } finally {
      final started = perfTrace;
      await _guard(() async {
        await started?.stop();
      });
    }
  }
}
