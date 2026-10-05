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

class RemoteConfigLayoutSource implements LayoutSource {
  static const parameterKey = 'home_layout';

  final FirebaseRemoteConfig _remoteConfig;
  bool _configured = false;

  RemoteConfigLayoutSource(this._remoteConfig);

  Future<void> _configure() async {
    if (_configured) return;
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    _configured = true;
  }

  @override
  Future<String?> fetch() async {
    await _configure();
    await _remoteConfig.fetchAndActivate();
    final value = _remoteConfig.getString(parameterKey);
    return value.isEmpty ? null : value;
  }

  @override
  Stream<String?> get updates => _remoteConfig.onConfigUpdated
      .where((update) => update.updatedKeys.contains(parameterKey))
      .asyncMap((_) async {
        await _remoteConfig.activate();
        final value = _remoteConfig.getString(parameterKey);
        return value.isEmpty ? null : value;
      });
}
