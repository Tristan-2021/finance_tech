# banco_app

Shell de la app (`packages/app`): compone todos los features, decide qué pantalla
se ve y es el **único** lugar que conoce a varios features. Recorre el flujo
completo: registro, login, **Inicio** (home personalizado por segmento con
Remote Config), **Cuenta** (saldo, movimientos, registrar un movimiento),
conversor de remesas, notificaciones push, caché sin conexión y monitoreo con
Firebase.

```
lib/
  main.dart             Firebase, telemetría, configuración y arranque
  di.dart               Raíz de composición (GetIt): clientes HTTP y features
  app.dart              MaterialApp, temas, rutas y panel de depuración
  session_gate.dart     Decide login o pantallas según la sesión
  welcome_page.dart     Perfil, pestañas, avisos push y cierre de sesión
  home_shell.dart       Barra inferior (Inicio / Cuenta) y bloque exchange_rate
  shell_telemetry.dart  Eventos del shell (sin datos personales)
  debug/                Panel de depuración (solo en debug)
integration_test/       E2E contra el backend real (no entra al CI)
```

## Ejecutar con el backend desplegado (recomendado)

El backend de Supabase ya está desplegado: para ejecutar la app **no hace falta
levantar nada en local ni usar `adb reverse`**. Con un dispositivo Android
conectado (`flutter devices` muestra su id):

```bash
cd packages/app
flutter run -d <id-del-dispositivo> --dart-define=TELEMETRY_DEBUG=true \
  --dart-define=SUPABASE_URL=https://pzpolkpedpjtkaplulxc.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB6cG9sa3BlZHBqdGthcGx1bHhjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEyNDgyNjYsImV4cCI6MjEwNjgyNDI2Nn0.WLx9Hdwx5IFOgboRBM0_MJV4g9Ypl2_D7zC4kAtcP4E
```

La clave es la **anónima (publicable)** del proyecto: está pensada para ir en la
app y el acceso a los datos lo limitan las políticas RLS. **Nunca** uses la
`service_role` ni la secret key. Sin `TELEMETRY_DEBUG=true` la telemetría queda
apagada en debug. Puedes entrar con los usuarios demo (`joven@demo.com` y
`adulto@demo.com`, contraseña `demo1234`) o crear una cuenta desde la app.

Pruebas, desde la raíz del repo:

```bash
melos bootstrap
melos exec -- flutter analyze
melos run test
```

Las pruebas unitarias y de widgets no necesitan backend ni red. Para el E2E
contra el backend desplegado, en el dispositivo:

```bash
cd packages/app
flutter test integration_test/critical_flow_test.dart -d <id-del-dispositivo> \
  --dart-define=SUPABASE_URL=https://pzpolkpedpjtkaplulxc.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<la-clave-de-arriba>
```

El resto de este documento explica la configuración y, como alternativa, cómo
correr un backend local.

## 1. Configuración: `--dart-define`

La URL y la clave **no están en el repo**; se pasan al ejecutar. Sin ellas la
app no se cae: muestra "Falta configurar la app" con los nombres esperados.

| Define              | Valor |
| ------------------- | ----- |
| `SUPABASE_URL`      | URL del backend (ver cada plataforma abajo) |
| `SUPABASE_ANON_KEY` | La clave **publicable** del backend local. El nombre del define es el antiguo; el valor es la *publishable key* |
| `TELEMETRY_DEBUG`   | Opcional. `true` activa Analytics/Crashlytics/Performance también en debug |

Nunca uses la `service_role` ni la secret key en la app. La clave sale de
`supabase status` en el proyecto del backend.

## 2. Alternativa: backend local (en el repo del backend)

```bash
supabase start                      # API en http://127.0.0.1:54421
./scripts/create_demo_users.sh      # joven@demo.com y adulto@demo.com
./scripts/seed_demo_movements.sh    # movimientos de ejemplo en 2 meses
supabase functions serve            # Edge Functions (push al crear un movimiento)
```

Usuarios demo (contraseña `demo1234`): `joven@demo.com` (segmento `joven`) y
`adulto@demo.com` (segmento `adulto`). `supabase db reset` borra los usuarios:
vuelve a correr `create_demo_users.sh`.

## 3. Android físico con el backend local

El backend corre en tu Mac; desde el teléfono, `127.0.0.1` es el propio
teléfono. Se usa `adb reverse`:

```bash
adb devices                          # debe aparecer como "device"
adb reverse tcp:54421 tcp:54421      # se pierde al desconectar el cable
flutter devices                      # apunta el id del dispositivo
cd packages/app
flutter run -d <id-del-dispositivo> \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

Alternativa sin `adb reverse`: usa la IP del Mac en el mismo Wi-Fi
(`ipconfig getifaddr en0`) como `SUPABASE_URL` y permite el puerto 54421 en el
firewall.

| Otra plataforma  | `SUPABASE_URL`           |
| ---------------- | ------------------------ |
| Emulador Android | `http://10.0.2.2:54421`  |
| Simulador iOS    | `http://127.0.0.1:54421` |
| macOS            | `http://127.0.0.1:54421` |

### Tráfico http solo en desarrollo

`android:usesCleartextTraffic="true"` está **solo** en
`android/app/src/debug/AndroidManifest.xml`; el manifest `main` (release) solo
declara `INTERNET`, `POST_NOTIFICATIONS` y el canal de notificaciones.

### Problemas frecuentes

| Síntoma | Causa probable |
| ------- | -------------- |
| "Falta configurar la app" | Faltan `SUPABASE_URL` o `SUPABASE_ANON_KEY` |
| "Sin conexión" en Android físico | Se perdió `adb reverse`; repite el comando |
| El login falla con los usuarios demo | Backend apagado o `supabase db reset` sin recrear los usuarios |
| No llega la notificación | Falta la clave de FCM en el backend (modo prueba solo registra el mensaje) o no se aceptó el permiso |

## 4. Firebase (monitoreo)

Proyecto `banco-demo-05487`. Para ver los eventos en `DebugView`:

```bash
adb shell setprop debug.firebase.analytics.app com.bancointernacional.banco_app
flutter run -d <id> --dart-define=TELEMETRY_DEBUG=true \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

Eventos del shell: `app_opened`, `login_success`, `register_completed`,
`sign_out` y `screen_viewed` (con `screen`). Un filtro de privacidad deja pasar
solo una lista cerrada de parámetros (nunca correos, nombres ni importes).

## 5. Pruebas

Desde la raíz, igual que el CI:

```bash
melos exec -- flutter analyze
melos exec --diff=HEAD~1 --include-dependents --dir-exists=test -- flutter test --exclude-tags integration
```

La segunda corre solo lo que cambió y lo que depende de ello; para todo,
`melos run test`. Las pruebas de widgets usan casos de uso falsos: no necesitan
backend ni red.

### E2E del flujo crítico (dispositivo, backend real, fuera del CI)

`integration_test/critical_flow_test.dart` es **una sola prueba** que recorre:
login con `joven@demo.com` → home personalizado → pestaña Cuenta con saldo y
movimientos reales → modo sin conexión (por código, con `DebugNetworkConfig`) y
refrescar → aviso de **datos guardados con su fecha** → vuelve la conectividad →
los datos **se recuperan solos** → cerrar sesión.

```bash
adb reverse tcp:54421 tcp:54421
cd packages/app
flutter test integration_test/critical_flow_test.dart -d <id-del-dispositivo> \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

Necesita `supabase start` y los usuarios demo. `integration_test/login_balance_test.dart`
es la variante con casos de uso falsos (sin backend).

## 6. Colaborar

### Trunk Based Development

- Se parte siempre de `main` actualizado (`git pull origin main`).
- **Una pieza pequeña por rama corta** `feat/<paquete>-<qué>`, con 1 o 2 commits,
  push, **merge a `main` con `--no-ff` el mismo día** y rama borrada (local y
  remota). Nada de `develop`, `release` ni ramas de más de 24 horas.
- Cada merge deja `analyze` y `test` en verde, en local y en GitHub Actions. Si
  el CI está rojo no se abre la siguiente rama.
- Commits y merges **en inglés**, modo imperativo, minúsculas tras el tipo:
  `feat(feature_exchange): add exchange card`, `test(app): ...`,
  `fix(app): ...`, `docs(repo): ...`, `merge(<paquete>): ...`.

### Crear un paquete nuevo

1. Crea la carpeta bajo `packages/core/` o `packages/features/` con su
   `pubspec.yaml` (`resolution: workspace`, el mismo SDK que los demás) y su
   `analysis_options.yaml`.
2. Regístralo en `workspace:` del `pubspec.yaml` raíz.
3. Dependencias internas por nombre, sin `path:`. Un feature depende solo de
   paquetes `core_*`, nunca de otro feature.
4. `melos bootstrap`, y expón solo lo público en el barril `lib/<paquete>.dart`.

### Reglas de arquitectura

Un feature nunca depende de otro; el shell los une. Ningún widget ni Cubit
importa `supabase_flutter` (solo la capa de datos, con los tipos que reexporta
`core_network`). Dominio sin Flutter ni plugins. **Dinero en centavos `int`,
nunca `double`.** Textos en español en un archivo del paquete. Nada de URLs ni
claves hardcodeadas.

### Quién es dueño de qué

| Paquete | Frente |
| ------- | ------ |
| `core_errors`, `core_network`, `core_storage`, `core_ui` | Base (red, caché, tema) |
| `feature_onboarding`, `feature_accounts` | Base; el registro de movimientos es del frente D |
| `core_telemetry`, `feature_personalization` | Frente A (Firebase y Remote Config) |
| `feature_notifications` | Frente B (push) |
| `feature_exchange` | Frente C (tasas de cambio) |
| `packages/app` | Frente E (integración, E2E y guion) |

## 7. Guion de demostración (video)

App lanzada con el comando de "Ejecutar con el backend desplegado" (que ya
incluye `TELEMETRY_DEBUG=true`; con el backend local haría falta además
`adb reverse`). Mantén abiertas la consola de Firebase (Remote Config,
Analytics `DebugView`, Crashlytics) y el panel de depuración (ícono de bicho,
abajo a la derecha, sobre la barra de pestañas).

1. **Registro.** "Crear cuenta": correo y contraseña, nombre y fecha de
   nacimiento (mayor de 18; 18–29 años = `joven`, 30 o más = `adulto`) y uso de la
   cuenta. Entra con su nombre y el segmento que calcula el backend. Acepta el
   pre-aviso "Te avisaremos de tus movimientos" y el permiso del sistema.
2. **Login.** Cierra sesión (menú de **Cuenta**) y entra con `joven@demo.com`.
3. **Home personalizado.** En **Inicio**, los bloques del segmento `joven`
   (promoción, resumen de gastos, consejo). Cierra sesión y entra con
   `adulto@demo.com`: otros bloques y orden (resumen, tipo de cambio, consejo).
4. **Cambio en vivo en Remote Config.** Con `joven` en **Inicio**, en la consola
   edita `home_layout` y añade a la lista `joven`:
   `{"id": "rate_live", "type": "exchange_rate"}` y un
   `{"id": "tip_demo", "type": "tip", "params": {"text": "Bloque nuevo desde Remote Config"}}`;
   **Publicar cambios**. Los bloques aparecen **sin reinstalar ni reiniciar**.
   (El JSON y las reglas están en `packages/features/feature_personalization/README.md`.)
5. **Conversor con datos reales.** En la tarjeta de remesas escribe `100`: se ve
   el resultado en dólares, la tasa usada y su **fecha** ("Tasa del … (BCE)"; es
   una tasa diaria, no en vivo).
6. **Registrar un movimiento.** Pestaña **Cuenta** → "Registrar movimiento"
   ("Gasto manual (demostración)"): gasto de `12,30`, categoría comida. Se ve
   bajar el **saldo** y aparecer en la **lista**; vuelve a **Inicio** y el
   **resumen de gastos** cambia. Llega la **notificación push** del backend
   (pruébala con la app abierta, en segundo plano y cerrada); al tocarla la app
   abre la pestaña **Cuenta** con el saldo actualizado. Con un gasto mayor al
   saldo se ve "Saldo insuficiente.".
7. **Conectividad degradada** (panel de depuración, un bloque por servicio):
   - **Sin conexión** en *Backend*: refresca en **Cuenta** (pull-to-refresh) y
     aparece "Mostrando datos guardados el {fecha}" con el saldo y los
     movimientos visibles. Apágalo: se recupera solo.
   - **Latencia 8 s**: cierra sesión y vuelve a entrar; se ve el estado de carga.
   - **Fallos 503 al 50 %**: refresca varias veces; se ve "Reintentando…" y, al
     pasar una petición, los datos se actualizan solos. *Restablecer* devuelve la
     red normal.
   - **Indisponibilidad parcial, solo tasas**: activa *Sin conexión* únicamente
     en *Tasas de cambio*, ve a **Cuenta** y vuelve a **Inicio**: el conversor
     muestra la tasa guardada con "Sin conexión: tasa guardada del {fecha}" y
     *Reintentar*, mientras el resto de la app funciona.
   - **Indisponibilidad parcial, solo backend**: apaga *Backend* y deja *Tasas*
     activas: saldo y movimientos salen de la caché y el conversor sigue
     respondiendo.
   - **Sin copia y sin red**: con *Sin conexión* en *Backend*, *Borrar caché* y
     cerrar sesión y volver a entrar: no hay datos y aparece el error con
     *Reintentar*.
8. **Monitoreo.** En el panel pulsa **Evento de prueba** y **Error de prueba**:
   `debug_test_event` aparece en `DebugView` y el error en Crashlytics (puede
   tardar unos minutos). En `DebugView` también se ven `app_opened`,
   `login_success`, `screen_viewed` y `block_viewed`.
9. **Pruebas y CI.** En la terminal: `melos exec -- flutter analyze` y
   `melos run test`; muestra el CI en verde en GitHub Actions y, en el
   dispositivo, el E2E (`critical_flow_test.dart`).

Aislamiento entre usuarios: cierra sesión y entra con el otro usuario; no se ven
datos ni notificaciones del anterior (la caché se limpia y el token de
notificaciones se borra del backend antes de cerrar la sesión).

## 8. Notas técnicas

### Requisitos de plataforma de la caché cifrada

`flutter_secure_storage` guarda la clave en Keychain / Keystore: en Android,
`minSdk` 23 o superior y `android:allowBackup="false"` (ya aplicado); en macOS,
`keychain-access-groups` en los entitlements (ya aplicado).

### Realtime y reconexión

Realtime usa WebSocket y no pasa por el `RetryClient` de `core_network`; los
eventos ocurridos durante una desconexión no se reenvían, así que al recuperar
conectividad la app refresca saldo y movimientos por la API.

### Recortes conocidos

- Android únicamente (iOS/macOS sin configurar para push ni Firebase).
- El pre-aviso de notificaciones sale en cada arranque con sesión, aunque el
  permiso ya esté concedido.
- Sin conexión no se puede registrar un movimiento ni hay cola de envíos.
- Remote Config en tiempo real no está soportado en Windows.
