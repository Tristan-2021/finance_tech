import 'package:core_network/core_network.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import 'data/device_token_remote_data_source.dart';
import 'data/device_token_repository_impl.dart';
import 'data/firebase_messaging_gateway.dart';
import 'domain/device_token_repository.dart';
import 'domain/messaging_gateway.dart';
import 'notifications_controller.dart';

/// Registra en [getIt] el gateway, el registro de tokens y el
/// [NotificationsController] (un único objeto para toda la app: se inicializa
/// al arrancar y se detiene al cerrar sesión).
///
/// Asume que un `SupabaseClient` ya está registrado.
void registerNotificationsDependencies(GetIt getIt) {
  getIt
    ..registerLazySingleton<MessagingGateway>(FirebaseMessagingGateway.new)
    ..registerLazySingleton<DeviceTokenRemoteDataSource>(
      () => SupabaseDeviceTokenRemoteDataSource(
        getIt<SupabaseClient>(),
        defaultTargetPlatform.name.toLowerCase(),
      ),
    )
    ..registerLazySingleton<DeviceTokenRepository>(
      () => DeviceTokenRepositoryImpl(getIt<DeviceTokenRemoteDataSource>()),
    )
    ..registerLazySingleton<NotificationsController>(
      () => NotificationsController(
        getIt<MessagingGateway>(),
        getIt<DeviceTokenRepository>(),
      ),
    );
}
