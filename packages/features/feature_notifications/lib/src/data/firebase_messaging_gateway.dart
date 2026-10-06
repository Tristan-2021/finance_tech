import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/messaging_gateway.dart';
import '../domain/push_message.dart';

/// Implementación con `firebase_messaging` (FCM) y `flutter_local_notifications`.
///
/// `FirebaseMessaging.instance` se pide al usarse, no al construir: si Firebase
/// no arrancó, el fallo cae dentro de los métodos (que el controlador atrapa).
///
/// Con la app en segundo plano o cerrada, Android muestra por sí solo los
/// mensajes con bloque `notification`, así que no hace falta un handler de
/// segundo plano.
class FirebaseMessagingGateway implements MessagingGateway {
  final FlutterLocalNotificationsPlugin _local;
  final _opened = StreamController<PushMessage>.broadcast();
  int _nextId = 0;

  FirebaseMessagingGateway({FlutterLocalNotificationsPlugin? local})
    : _local = local ?? FlutterLocalNotificationsPlugin();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static PushMessage _toMessage(RemoteMessage message) => PushMessage(
    title: message.notification?.title,
    body: message.notification?.body,
    data: {
      for (final entry in message.data.entries)
        entry.key: entry.value.toString(),
    },
  );

  @override
  Future<void> initialize() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) => _opened.add(
        PushMessage(
          data: {'type': response.payload ?? ''},
          origin: PushOrigin.foreground,
        ),
      ),
    );
    // El canal debe existir antes de que llegue un mensaje.
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            movementsChannelId,
            movementsChannelName,
            description: movementsChannelDescription,
            importance: Importance.high,
          ),
        );
    FirebaseMessaging.onMessageOpenedApp
        .map(_toMessage)
        .listen(_opened.add);
  }

  @override
  Stream<PushMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(_toMessage);

  @override
  Stream<PushMessage> get onOpened => _opened.stream;

  @override
  Future<PushMessage?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _toMessage(message);
  }

  /// En Android 13 o superior muestra el diálogo del sistema; en versiones
  /// anteriores no hay diálogo y el permiso ya está concedido.
  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Future<void> showLocal(PushMessage message) {
    return _local.show(
      id: _nextId++,
      title: message.title,
      body: message.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          movementsChannelId,
          movementsChannelName,
          channelDescription: movementsChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: message.data['type'],
    );
  }

  @override
  Future<void> deleteToken() => _messaging.deleteToken();
}
