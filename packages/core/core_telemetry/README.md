# core_telemetry

Telemetría de la app (Crashlytics, Analytics y Performance) con **privacidad
garantizada**. Los features dependen solo de la interfaz `Telemetry`; el plugin
de Firebase vive detrás de `FirebaseTelemetry`.

```dart
final telemetry = await initTelemetry();           // Noop si Firebase no arrancó
telemetry.logEvent('block_viewed', {'block_id': 'tip_ahorro', 'segment': 'joven'});
telemetry.setSegment('joven');
final cuentas = await telemetry.trace('cargar_cuentas', () => getAccounts());
telemetry.recordError(error, stack, reason: 'texto_fijo');
```

## Privacidad (lo que sí y lo que no sale de la app)

Todo pasa por `TelemetrySanitizer`:

- **Parámetros:** lista cerrada de claves (`screen`, `step`, `code`, `segment`,
  `block_id`, `block_type`, `source`, `result`, `count`, `duration_ms`). Cualquier
  otra clave se descarta.
- **Valores:** texto de hasta 100 caracteres (se trunca), número finito o
  booleano. Un texto con `@` (posible correo) se descarta. Listas, mapas, fechas
  y objetos se descartan.
- **Eventos:** `snake_case`, máximo 40 caracteres; si el nombre no cumple, el
  evento no se envía.
- **Errores:** a Crashlytics llega el **nombre del tipo** y, si es un `Failure`,
  su **código**. Nunca el mensaje. El `reason` debe ser un texto fijo.
- **Nunca** correos, nombres, saldos, montos ni descripciones.

## Cuándo se recolecta

En **depuración la recolección está desactivada**. Para poder demostrarla:

```bash
flutter run --dart-define=TELEMETRY_DEBUG=true ...
```

`initTelemetry()` engancha `FlutterError.onError` y `PlatformDispatcher.onError`
a Crashlytics (siempre por el filtro de privacidad). Si Firebase no se
inicializó, devuelve `NoopTelemetry`.

## Rendimiento: lo que NO se promete

Firebase Performance recoge automáticamente el arranque de la app y las
solicitudes HTTP/S de la pila nativa. **La documentación no confirma** que el
tráfico de Dart (`package:http` / `dart:io`), que usa Supabase, entre en esa
recolección, así que no se promete monitoreo automático de red. Lo que hay son
trazas manuales con `trace(...)` alrededor de las operaciones clave.
Tampoco hay medición automática de pantallas individuales de Flutter.

## Requisitos de plataforma

Al agregar Crashlytics y Performance hay que volver a ejecutar `flutterfire
configure` en `packages/app` para que se apliquen sus plugins de Gradle:

```bash
cd packages/app
flutterfire configure --yes --project=banco-demo-05487 \
  --platforms=android --android-package-name=com.bancointernacional.banco_app
flutter build apk --debug
```

Los plugins de Firebase actuales requieren `minSdk` 23 o superior (la app usa
`flutter.minSdkVersion`).
