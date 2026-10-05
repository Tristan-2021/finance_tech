import 'dart:convert';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'cache_store.dart';
import 'secret_store.dart';

/// [CacheStore] sobre una caja de `hive_ce` cifrada con AES-256. La clave vive
/// en el [SecretStore]; la caché es descartable: si no se puede abrir (clave
/// perdida o archivo dañado) se borra y se empieza de cero.
class HiveCacheStore implements CacheStore {
  static const _boxName = 'core_storage_cache';
  static const _ownerKey = '__owner__';

  final Box<String> _box;
  final DateTime Function() _clock;

  HiveCacheStore._(this._box, this._clock);

  /// Abre la caché. Sin [path] usa el directorio de la app (`initFlutter`);
  /// con [path] usa esa carpeta (útil en pruebas).
  static Future<HiveCacheStore> open({
    required EncryptionKeyProvider keyProvider,
    String? path,
    DateTime Function()? clock,
  }) async {
    final cipher = HiveAesCipher(await keyProvider.loadOrCreate());
    if (path == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(path);
    }

    Box<String> box;
    try {
      box = await Hive.openBox<String>(_boxName, encryptionCipher: cipher);
    } catch (_) {
      await Hive.deleteBoxFromDisk(_boxName);
      box = await Hive.openBox<String>(_boxName, encryptionCipher: cipher);
    }
    return HiveCacheStore._(box, clock ?? DateTime.now);
  }

  @override
  Future<CacheEntry?> read(String key) async {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CacheEntry(
        value: map['value'] as String,
        savedAt: DateTime.parse(map['savedAt'] as String),
      );
    } catch (_) {
      await _box.delete(key); // entrada ilegible: se descarta
      return null;
    }
  }

  @override
  Future<void> write(String key, String json) {
    return _box.put(
      key,
      jsonEncode({
        'value': json,
        'savedAt': _clock().toUtc().toIso8601String(),
      }),
    );
  }

  @override
  Future<void> clear() async {
    await _box.clear();
  }

  @override
  Future<void> bindOwner(String ownerId) async {
    if (_box.get(_ownerKey) == ownerId) return;
    await _box.clear();
    await _box.put(_ownerKey, ownerId);
  }

  /// Cierra la caja (el archivo queda guardado en disco).
  Future<void> close() => _box.close();
}
