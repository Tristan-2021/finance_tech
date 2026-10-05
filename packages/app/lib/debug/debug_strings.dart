/// Textos del panel de depuración (solo existe en builds de depuración).
abstract final class DebugStrings {
  static const open = 'Panel de depuración';
  static const title = 'Depuración de red';
  static const close = 'Cerrar panel';
  static const offline = 'Sin conexión';
  static const latency = 'Latencia';
  static const noLatency = 'Ninguna';
  static String seconds(int s) => '$s s';
  static String failures(int percent) => 'Fallos 503: $percent %';
  static const reset = 'Restablecer';
  static const clearCache = 'Borrar caché';
  static const cacheCleared = 'Caché borrada';
}
