/// Mensaje push ya reducido a lo que usa la app. Los textos no llevan montos:
/// el detalle se consulta por la API al abrir la app.
class PushMessage {
  final String? title;
  final String? body;

  /// `transaction_id`, `account_id` y `type` según el contrato del backend.
  final Map<String, String> data;

  const PushMessage({this.title, this.body, this.data = const {}});

  /// Un mensaje solo de datos (sin título ni cuerpo) no se muestra.
  bool get isDisplayable => title != null || body != null;
}
