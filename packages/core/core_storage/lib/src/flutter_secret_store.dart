import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secret_store.dart';

/// [SecretStore] sobre `flutter_secure_storage` (Keychain en iOS/macOS,
/// Keystore en Android).
class FlutterSecretStore implements SecretStore {
  final FlutterSecureStorage _storage;

  FlutterSecretStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}
