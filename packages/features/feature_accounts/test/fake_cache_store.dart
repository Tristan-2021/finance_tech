import 'package:core_storage/core_storage.dart';

/// Caché en memoria. [now] es la fecha que se anota al guardar.
class FakeCacheStore implements CacheStore {
  final entries = <String, CacheEntry>{};
  DateTime now = DateTime.utc(2026, 10, 4, 12);
  bool failWrites = false;
  bool failReads = false;

  @override
  Future<CacheEntry?> read(String key) async {
    if (failReads) throw StateError('lectura fallida');
    return entries[key];
  }

  @override
  Future<void> write(String key, String json) async {
    if (failWrites) throw StateError('escritura fallida');
    entries[key] = CacheEntry(value: json, savedAt: now);
  }

  @override
  Future<void> clear() async {
    entries.clear();
  }

  @override
  Future<void> bindOwner(String ownerId) async {}
}
