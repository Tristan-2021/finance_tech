import 'push_message.dart';

/// Canal de Android de los avisos de movimientos. El backend envía sus
/// mensajes con este `channel_id`, así que debe existir antes de que llegue uno.
const movementsChannelId = 'movements';
const movementsChannelName = 'Movimientos';

/// Frontera con los plugins de Firebase Messaging y de notificaciones locales.
/// El controlador solo conoce esta interfaz; las pruebas usan un falso.
abstract interface class MessagingGateway {
  /// Crea el canal [movementsChannelId] (importancia alta) y prepara las
  /// notificaciones locales.
  Future<void> initialize();

  /// Mensaje recibido con la app abierta.
  Stream<PushMessage> get onForegroundMessage;

  /// Notificación tocada con la app en segundo plano (de FCM o local).
  Stream<PushMessage> get onOpened;

  /// Mensaje que abrió la app estando cerrada, si lo hubo.
  Future<PushMessage?> getInitialMessage();

  /// Pide el permiso de notificaciones. `true` si está concedido; en Android
  /// anterior a 13 no hay diálogo y devuelve `true`.
  Future<bool> requestPermission();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  /// Muestra [message] como notificación local en el canal de movimientos.
  Future<void> showLocal(PushMessage message);

  /// Borra el token de FCM del dispositivo.
  Future<void> deleteToken();
}
