# Estrategia de despliegue

Cómo se configura, se publica y se revierte cada pieza del sistema. Lo marcado con **[confirmar]** depende de cómo el autor desplegó el backend y no se puede comprobar desde el repositorio.

## 1. Piezas y dónde viven

| Pieza | Dónde | Cómo se actualiza |
|---|---|---|
| **App Flutter (Android)** | Dispositivo del usuario | Se compila desde `packages/app` con `flutter build apk` |
| **Backend (Postgres, Auth, RLS, RPC, Realtime)** | Proyecto de Supabase desplegado (`pzpolkpedpjtkaplulxc.supabase.co`) | Migraciones SQL con la CLI de Supabase |
| **Push** | Trigger en `transactions` → Edge Function `notify-transaction` → FCM v1 | Despliegue de la función y de sus secretos |
| **Layout del home** | Parámetro `home_layout` de Remote Config (proyecto Firebase `banco-demo-05487`) | Se edita y se publica en la consola, sin nueva versión de la app |
| **Monitoreo** | Firebase (Analytics, Crashlytics, Performance) | Se configura una vez con FlutterFire; no se despliega |

## 2. Entornos y configuración

Hay dos entornos y **la app no cambia de código entre ellos**: solo cambian los `--dart-define`.

| Entorno | `SUPABASE_URL` | Uso |
|---|---|---|
| **Desplegado** | `https://pzpolkpedpjtkaplulxc.supabase.co` | Demostración y evaluación; no necesita nada en local |
| **Local** | `http://127.0.0.1:54421` (con `adb reverse` en un teléfono) | Desarrollo con `supabase start`; el tráfico http solo está permitido en el manifest de **debug** |

- La URL y la clave **no están en el código**: se pasan al ejecutar o compilar (`SupabaseConfig.fromEnvironment`). Sin ellas la app muestra "Falta configurar la app" en lugar de caerse.
- `TELEMETRY_DEBUG=true` activa Analytics, Crashlytics y Performance también en debug; en release la telemetría está activa por defecto.
- Comandos completos: `packages/app/README.md`.

## 3. Secretos

| Dato | Dónde puede estar | Dónde nunca |
|---|---|---|
| Clave **anónima (publicable)** de Supabase | `--dart-define` y documentación: es pública por diseño y el acceso lo limita RLS | — |
| `service_role` y secret key de Supabase | Solo el backend | La app, el repositorio, los README |
| Cuenta de servicio de FCM | Secretos de la Edge Function (`supabase secrets set`) **[confirmar]** | La app, el repositorio |
| `google-services.json` y `firebase_options.dart` | El repositorio (identifican el proyecto, no son secretos) | — |

Una revisión automática en la verificación final busca `service_role`, `anonKey` y claves o URLs fijas en el código.

## 4. Integración continua

GitHub Actions (`.github/workflows/ci.yml`) en cada push a `main` y en cada pull request:

1. `melos bootstrap`.
2. `melos exec -- flutter analyze` en todos los paquetes.
3. `flutter test --exclude-tags integration` solo en los paquetes que cambiaron y los que dependen de ellos (`--diff` contra el commit anterior).

Las pruebas de integración y el E2E (`integration_test/critical_flow_test.dart`) **no entran al CI**: necesitan un dispositivo y el backend real, y se ejecutan a mano antes de entregar.

**Límite conocido:** el CI no compila el APK. Un problema solo visible al compilar (por ejemplo, el *core library desugaring* que pide `flutter_local_notifications`) aparece únicamente en el dispositivo. Mitigación actual: `flutter build apk --debug` en la lista de comprobación de abajo.

## 5. Publicar cada pieza

### Backend (Supabase)
1. Los cambios de esquema se escriben como **migraciones** SQL versionadas y se prueban en local (`supabase db reset`, `supabase test db`).
2. Se aplican al proyecto desplegado con `supabase db push` **[confirmar]**.
3. La Edge Function se publica con `supabase functions deploy notify-transaction`, con `FCM_DRY_RUN=false` y la cuenta de servicio de FCM como secreto **[confirmar]**.
4. Las migraciones **solo van hacia adelante**: un cambio incompatible exige una migración nueva, no editar una ya aplicada.

### Layout del home (Remote Config)
1. Se edita el JSON `home_layout` (reglas y ejemplo en `packages/features/feature_personalization/README.md`).
2. **Publicar cambios** en la consola. La app lo aplica en vivo.
3. Es seguro equivocarse: un JSON inválido se descarta y la app conserva el último layout válido o el embebido.

### App (Android)
1. `main` siempre está en verde (Trunk Based Development).
2. Comprobar: `flutter build apk --debug` y el E2E en un dispositivo.
3. Generar el artefacto: `flutter build apk --release` (o `appbundle`) con los mismos `--dart-define` del entorno destino.
4. Distribuirlo (ver "Pendiente").

## 6. Reversión

| Pieza | Cómo se revierte |
|---|---|
| **App** | Reinstalar la versión anterior del APK. El código de `main` se revierte con `git revert` de la fusión (cada pieza es un merge sin fast-forward, así que se revierte una pieza entera) |
| **Layout del home** | Volver a la versión anterior del parámetro en el historial de Remote Config, o dejar que caiga al layout embebido |
| **Backend** | Nueva migración que deshaga el cambio; las migraciones aplicadas no se editan |
| **Push** | `FCM_DRY_RUN=true` detiene los envíos sin tocar la app; un fallo del push nunca revierte el movimiento |

## 7. Riesgos y mitigaciones

- **Servicio externo caído (tasas):** reintentos con backoff, caché de la última tasa con su fecha y aviso en pantalla. El resto de la app sigue funcionando (clientes HTTP independientes).
- **Backend caído:** saldo y movimientos salen de la caché cifrada con su fecha de guardado; la app se recupera sola al volver la red.
- **Datos del usuario anterior en el mismo teléfono:** la caché se asocia al usuario y se limpia al cerrar sesión; el token de notificaciones se borra del backend antes de cerrar la sesión.
- **Configuración de FCM errónea:** la push falla sin afectar a la app (se vio durante las pruebas: la causa estaba en el backend, no en el cliente).

## 8. Pendiente (no hecho, declarado)

- **Firma de release:** `build.gradle.kts` firma el modo release con la clave de debug. Para publicar de verdad hace falta un keystore propio y un `key.properties` fuera del repositorio.
- **Distribución:** no hay canal automatizado (Firebase App Distribution o Play Console). El APK se entrega o se instala a mano.
- **CI de compilación:** añadir un trabajo que compile el APK en cada merge o en cada etiqueta de versión.
- **Entorno de staging:** hoy hay un backend local y uno desplegado, sin uno intermedio.
- **iOS:** sin configurar (push, Firebase ni firma).
- **Despliegue automático del backend:** hoy se aplica a mano con la CLI.
