/// Desde qué estado de la app se abrió una notificación.
enum PushOrigin { foreground, background, terminated }

/// Mensaje push ya reducido a lo que usa la app. Los textos no llevan montos:
/// el detalle se consulta por la API al abrir la app.
class PushMessage {
  final String? title;
  final String? body;

  /// `transaction_id`, `account_id` y `type` según el contrato del backend.
  final Map<String, String> data;

  /// Solo tiene sentido en los mensajes que abren la app: una notificación
  /// local (mostrada con la app abierta) es `foreground`; una del sistema
  /// tocada con la app en segundo plano, `background`.
  final PushOrigin origin;

  const PushMessage({
    this.title,
    this.body,
    this.data = const {},
    this.origin = PushOrigin.background,
  });

  /// Un mensaje solo de datos (sin título ni cuerpo) no se muestra.
  bool get isDisplayable => title != null || body != null;
}
