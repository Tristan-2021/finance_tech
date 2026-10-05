# core_storage

Caché local cifrada para los features. Los features dependen solo de la
interfaz `CacheStore`; ni `hive_ce` ni `flutter_secure_storage` se importan
fuera de este paquete.

```dart
final store = await HiveCacheStore.open(
  keyProvider: EncryptionKeyProvider(FlutterSecretStore()),
);
await store.bindOwner(user.id);          // descarta la caché de otro usuario
await store.write('accounts', json);     // guarda y registra la fecha
final entry = await store.read('accounts'); // entry?.value, entry?.savedAt (UTC)
await store.clear();                     // al cerrar sesión
```

## Cómo funciona

- **Cifrado:** una caja de `hive_ce` con AES-256 (`HiveAesCipher`).
- **Clave:** se genera una vez (`Hive.generateSecureKey()`, 32 bytes) y se
  guarda en `flutter_secure_storage` (Keychain / Keystore). Si falta o está
  corrupta, se crea otra; la caché es descartable, así que si no se puede
  abrir se borra y se empieza de cero.
- **Fecha:** cada entrada guarda su `savedAt` (UTC) para poder decir "datos
  guardados el …".
- **Dueño:** `bindOwner(id)` asocia la caché a un usuario; si el dueño guardado
  es otro (o no hay ninguno) se descarta todo. Se guarda un identificador, nunca
  contraseñas ni tokens.

## Requisitos de plataforma (a aplicar cuando la app integre el paquete)

Confirmados en la documentación de cada paquete (versiones: `hive_ce` 2.x,
`flutter_secure_storage` 11.x):

- **`hive_ce`:** Dart puro, sin dependencias nativas. No requiere cambios en
  `android/` ni `ios/`.
- **`flutter_secure_storage` en Android:** `minSdk` 23 o superior (la app usa
  `flutter.minSdkVersion`; con un Flutter reciente ya cumple) y **desactivar el
  auto-backup** de Android (`android:allowBackup="false"` en el manifest
  principal), porque restaurar un backup sin la clave del Keystore provoca
  errores.
- **`flutter_secure_storage` en macOS:** añadir
  `<key>keychain-access-groups</key><array/>` a `DebugProfile.entitlements` y
  `Release.entitlements`.
- **iOS:** sin cambios adicionales.
