/// Una entrada guardada: el valor (JSON como texto) y cuándo se guardó.
class CacheEntry {
  final String value;

  /// Momento en que se guardó, en UTC.
  final DateTime savedAt;

  const CacheEntry({required this.value, required this.savedAt});
}

/// Caché local de pares clave -> JSON. Los features dependen de esta interfaz,
/// nunca de la implementación ni del paquete de persistencia.
abstract interface class CacheStore {
  /// `null` si la clave no existe.
  Future<CacheEntry?> read(String key);

  /// Guarda [json] bajo [key] y registra la fecha de guardado.
  Future<void> write(String key, String json);

  /// Borra todo (p. ej. al cerrar sesión).
  Future<void> clear();

  /// Asocia la caché al usuario [ownerId]. Si el dueño guardado es otro, o no
  /// hay ninguno, descarta todo lo guardado antes de seguir: así nunca se
  /// muestran datos de otro usuario.
  Future<void> bindOwner(String ownerId);
}
