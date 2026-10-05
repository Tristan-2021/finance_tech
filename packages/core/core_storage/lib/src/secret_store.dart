import 'dart:convert';

import 'package:hive_ce/hive.dart';

/// Almacén de secretos pequeños (Keychain / Keystore en producción).
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

/// Entrega la clave AES de la caché: la crea una sola vez y la reutiliza.
class EncryptionKeyProvider {
  static const keyName = 'core_storage.cache_key';
  static const _keyLength = 32; // AES-256

  final SecretStore _store;

  const EncryptionKeyProvider(this._store);

  Future<List<int>> loadOrCreate() async {
    final stored = await _store.read(keyName);
    if (stored != null) {
      try {
        final key = base64Decode(stored);
        if (key.length == _keyLength) return key;
      } on FormatException {
        // Valor corrupto: se genera una clave nueva.
      }
    }
    final key = Hive.generateSecureKey();
    await _store.write(keyName, base64Encode(key));
    return key;
  }
}
