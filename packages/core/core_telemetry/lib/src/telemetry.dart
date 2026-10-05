/// Telemetría de la app. Los features dependen solo de esta interfaz; el
/// plugin de Firebase queda detrás de [FirebaseTelemetry] y en pruebas se usa
/// [NoopTelemetry] o un falso.
abstract interface class Telemetry {
  /// Registra un evento. El nombre debe ser `snake_case` (máx. 40 caracteres) y
  /// solo pasan los parámetros permitidos por `TelemetrySanitizer`.
  void logEvent(String name, [Map<String, Object?> params = const {}]);

  /// Registra un error. Solo se envía el tipo y, si es un `Failure`, su código;
  /// nunca el mensaje. [reason] debe ser un texto fijo, sin datos.
  void recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
    String? reason,
  });

  /// Segmento del usuario (`joven` o `adulto`) para filtrar en las consolas.
  void setSegment(String? segment);

  /// Mide [action] con una traza de rendimiento y devuelve su resultado.
  Future<T> trace<T>(String name, Future<T> Function() action);
}

/// No hace nada: valor por defecto y para pruebas.
class NoopTelemetry implements Telemetry {
  const NoopTelemetry();

  @override
  void logEvent(String name, [Map<String, Object?> params = const {}]) {}

  @override
  void recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
    String? reason,
  }) {}

  @override
  void setSegment(String? segment) {}

  @override
  Future<T> trace<T>(String name, Future<T> Function() action) => action();
}
