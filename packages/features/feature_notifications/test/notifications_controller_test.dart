import 'dart:async';

import 'package:core_errors/core_errors.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_notifications/src/domain/device_token_repository.dart';
import 'package:feature_notifications/src/domain/messaging_gateway.dart';
import 'package:feature_notifications/src/domain/push_message.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements MessagingGateway {
  final log = <String>[];
  bool permission = true;
  String? token = 'token-1';
  PushMessage? initial;
  int permissionRequests = 0;
  final shown = <PushMessage>[];

  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();
  final refresh = StreamController<String>.broadcast();

  @override
  Future<void> initialize() async => log.add('init');

  @override
  Stream<PushMessage> get onForegroundMessage => foreground.stream;

  @override
  Stream<PushMessage> get onOpened => opened.stream;

  @override
  Future<PushMessage?> getInitialMessage() async => initial;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<String?> getToken() async {
    log.add('getToken');
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Future<void> showLocal(PushMessage message) async => shown.add(message);

  @override
  Future<void> deleteToken() async => log.add('fcm-delete');
}

class _FakeTokens implements DeviceTokenRepository {
  final _FakeGateway gateway;
  final registered = <String>[];
  Failure? registerFailure;
  Future<Failure?> Function(String token)? onUnregister;

  _FakeTokens(this.gateway);

  @override
  Future<Failure?> register(String token) async {
    registered.add(token);
    return registerFailure;
  }

  @override
  Future<Failure?> unregister(String token) {
    gateway.log.add('backend-delete:$token');
    return onUnregister?.call(token) ?? Future.value(null);
  }
}

void main() {
  late _FakeGateway gateway;
  late _FakeTokens tokens;
  late NotificationsController controller;
  late int opens;

  setUp(() {
    gateway = _FakeGateway();
    tokens = _FakeTokens(gateway);
    controller = NotificationsController(
      gateway,
      tokens,
      stopTimeout: const Duration(milliseconds: 50),
    );
    opens = 0;
  });

  tearDown(() async {
    await gateway.foreground.close();
    await gateway.opened.close();
    await gateway.refresh.close();
  });

  Future<void> startSession() =>
      controller.start(onOpenAccounts: () => opens++);

  group('start', () {
    test('con permiso concedido registra el token', () async {
      await controller.initialize();
      await startSession();
      expect(tokens.registered, ['token-1']);
    });

    test('un token rotado se vuelve a registrar', () async {
      await controller.initialize();
      await startSession();
      gateway.refresh.add('token-2');
      await pumpEventQueue();
      expect(tokens.registered, ['token-1', 'token-2']);
    });

    test('permiso rechazado: no registra, no lanza y no insiste', () async {
      gateway.permission = false;
      await controller.initialize();
      await startSession();
      await startSession();
      expect(tokens.registered, isEmpty);
      expect(gateway.log, isNot(contains('getToken')));
      expect(gateway.permissionRequests, 1);
    });

    test('un fallo del backend al registrar no lanza', () async {
      tokens.registerFailure = const Failure('sin red', 'network');
      await controller.initialize();
      await startSession();
      expect(tokens.registered, ['token-1']);
    });
  });

  group('stop', () {
    test('borra el token en el backend y luego el de FCM', () async {
      await controller.initialize();
      await startSession();
      gateway.log.clear();
      await controller.stop();
      expect(gateway.log, ['backend-delete:token-1', 'fcm-delete']);
    });

    test('si el backend lanza, no falla y borra el token local', () async {
      await controller.initialize();
      await startSession();
      tokens.onUnregister = (_) => throw Exception('boom');
      await controller.stop();
      expect(gateway.log, contains('fcm-delete'));
    });

    test('si el backend devuelve un Failure, sigue con el borrado local', () async {
      await controller.initialize();
      await startSession();
      tokens.onUnregister = (_) async => const Failure('x', 'network');
      await controller.stop();
      expect(gateway.log, contains('fcm-delete'));
    });

    test('si el backend no responde, el tiempo máximo evita el bloqueo', () async {
      await controller.initialize();
      await startSession();
      tokens.onUnregister = (_) => Completer<Failure?>().future;
      await controller.stop();
      expect(gateway.log.last, 'fcm-delete');
    });

    test('tras stop ya no registra tokens rotados', () async {
      await controller.initialize();
      await startSession();
      await controller.stop();
      gateway.refresh.add('token-2');
      await pumpEventQueue();
      expect(tokens.registered, ['token-1']);
    });
  });

  group('mensajes', () {
    test('en primer plano se muestra como notificación local', () async {
      await controller.initialize();
      const message = PushMessage(
        title: 'Dinero recibido',
        body: 'Revisa tu cuenta',
        data: {'type': 'credit'},
      );
      gateway.foreground.add(message);
      await pumpEventQueue();
      expect(gateway.shown, [message]);
    });

    test('un mensaje solo de datos no se muestra', () async {
      await controller.initialize();
      gateway.foreground.add(const PushMessage(data: {'type': 'debit'}));
      await pumpEventQueue();
      expect(gateway.shown, isEmpty);
    });

    test('tocar una notificación abre cuentas', () async {
      await controller.initialize();
      await startSession();
      gateway.opened.add(const PushMessage(title: 'x'));
      await pumpEventQueue();
      expect(opens, 1);
    });

    test('el mensaje que abrió la app cerrada abre cuentas al iniciar', () async {
      gateway.initial = const PushMessage(title: 'Movimiento registrado');
      await controller.initialize();
      expect(opens, 0, reason: 'aún no hay sesión');
      await startSession();
      expect(opens, 1);
    });

    test('tras stop, tocar una notificación no navega', () async {
      await controller.initialize();
      await startSession();
      await controller.stop();
      gateway.opened.add(const PushMessage(title: 'x'));
      await pumpEventQueue();
      expect(opens, 0);
    });
  });
}
