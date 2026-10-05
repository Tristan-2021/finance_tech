import 'dart:convert';
import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'cache_store.dart';
import 'secret_store.dart';

/// [CacheStore] sobre una caja de `hive_ce` cifrada con AES-256. La clave vive
/// en el [SecretStore]; la caché es descartable: si no se puede abrir (clave
/// perdida o archivo dañado) se borra y se empieza de cero.
///
/// Pensado para móvil y escritorio (usa archivos).
class HiveCacheStore implements CacheStore {
  static const _boxName = 'core_storage_cache';
  static const _ownerKey = '__owner__';

  final Box<String> _box;
  final DateTime Function() _clock;

  HiveCacheStore._(this._box, this._clock);

  /// Abre la caché. Sin [path] usa el directorio de documentos de la app; con
  /// [path] usa esa carpeta (útil en pruebas).
  static Future<HiveCacheStore> open({
    required EncryptionKeyProvider keyProvider,
    String? path,
    DateTime Function()? clock,
  }) async {
    final cipher = HiveAesCipher(await keyProvider.loadOrCreate());
    final directory = path ?? (await getApplicationDocumentsDirectory()).path;
    Hive.init(directory);

    Box<String> box;
    try {
      box = await Hive.openBox<String>(_boxName, encryptionCipher: cipher);
    } catch (_) {
      _discardBoxFiles(directory);
      box = await Hive.openBox<String>(_boxName, encryptionCipher: cipher);
    }
    return HiveCacheStore._(box, clock ?? DateTime.now);
  }

  /// Borra los archivos de la caja a mano. No se usa `deleteBoxFromDisk`
  /// porque falla si el archivo `.lock` ya no existe tras una apertura fallida.
  static void _discardBoxFiles(String directory) {
    for (final extension in const ['hive', 'hivec', 'lock']) {
      try {
        final file = File('$directory/$_boxName.$extension');
        if (file.existsSync()) file.deleteSync();
      } catch (_) {
        // Un archivo que no se puede borrar no debe impedir reabrir.
      }
    }
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
