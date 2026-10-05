import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Origen del JSON `home_layout`. Interfaz para poder sustituir Remote Config
/// en los tests.
abstract interface class LayoutSource {
  /// Descarga y activa el valor más reciente; devuelve el JSON crudo.
  /// Lanza si no hay red o el servicio falla.
  Future<String?> fetch();

  /// Emite el JSON crudo cada vez que se publica un cambio.
  Stream<String?> get updates;
}

/// Remote Config se obtiene de forma perezosa ([_remoteConfig]): si Firebase no
/// se pudo inicializar, el fallo queda dentro de [fetch] o [updates] y la app
/// sigue con el layout embebido.
class RemoteConfigLayoutSource implements LayoutSource {
  static const parameterKey = 'home_layout';

  final FirebaseRemoteConfig Function() _remoteConfig;
  bool _configured = false;

  RemoteConfigLayoutSource(this._remoteConfig);

  Future<FirebaseRemoteConfig> _ready() async {
    final remoteConfig = _remoteConfig();
    if (!_configured) {
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      _configured = true;
    }
    return remoteConfig;
  }

  static String? _valueOf(FirebaseRemoteConfig remoteConfig) {
    final value = remoteConfig.getString(parameterKey);
    return value.isEmpty ? null : value;
  }

  @override
  Future<String?> fetch() async {
    final remoteConfig = await _ready();
    await remoteConfig.fetchAndActivate();
    return _valueOf(remoteConfig);
  }

  @override
  Stream<String?> get updates async* {
    final FirebaseRemoteConfig remoteConfig;
    try {
      remoteConfig = _remoteConfig();
    } catch (_) {
      return;
    }
    yield* remoteConfig.onConfigUpdated
        .where((update) => update.updatedKeys.contains(parameterKey))
        .asyncMap((_) async {
          await remoteConfig.activate();
          return _valueOf(remoteConfig);
        });
  }
}
