# banco_app

App Flutter del monorepo `finance_tech`. Al arrancar llama a `initSupabase`
(`core_network`) y registra el `SupabaseClient` en GetIt (`lib/di.dart`).

## Configuración de Supabase (`--dart-define`)

La URL y la clave publicable **no están en el repo**; se pasan al ejecutar.
Si falta alguna, la app falla al arrancar indicando qué `--dart-define` falta.

| Define              | Valor                                               |
| ------------------- | --------------------------------------------------- |
| `SUPABASE_URL`      | URL del backend (ver tabla por plataforma)          |
| `SUPABASE_ANON_KEY` | Clave **publicable** (`supabase status`). Nombre antiguo del define; el valor es la publishable key |

Nunca uses `service_role` ni la secret key en la app.

### URL según la plataforma

| Plataforma                | `SUPABASE_URL`                      |
| ------------------------- | ----------------------------------- |
| iOS simulador / macOS     | `http://127.0.0.1:54421`            |
| Emulador Android          | `http://10.0.2.2:54421`             |
| Dispositivo físico        | `http://<IP-LAN-del-equipo>:54421`  |

Ejemplo (iOS simulador):

```bash
flutter run \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

En dispositivo físico el teléfono y el equipo deben estar en la misma red y
Supabase local debe aceptar conexiones desde la LAN.

## Tráfico http en desarrollo

El backend local usa http, no https:

- **Android:** `android:usesCleartextTraffic="true"` está **solo** en
  `android/app/src/debug/AndroidManifest.xml`. El manifest `main` (que usa
  release) no lo declara.
- **iOS:** por defecto no se necesita nada. Si el simulador bloquea la
  conexión, agrega `NSAllowsLocalNetworking` en `NSAppTransportSecurity`
  solo para debug (por ejemplo con un `Info.plist` de debug o xcconfig) y no
  en el `Info.plist` de release.

## Realtime y reconexión

Realtime usa WebSocket y no pasa por el `RetryClient` de `core_network`; la
reconexión la gestiona la librería. Los eventos ocurridos durante una
desconexión no se reenvían, así que al recuperar conectividad la app debe
refrescar saldo y movimientos por la API.
