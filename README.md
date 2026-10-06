# finance_tech

Plataforma financiera digital en Flutter, organizada como monorepo con Pub
Workspaces y Melos. Incluye **registro, login, cuentas, saldo y movimientos**
contra un backend Supabase local, modo sin conexión, **telemetría con Firebase**,
un **home personalizado por segmento** controlado con Remote Config, un
**conversor de remesas** con datos reales y **notificaciones push**.

```
packages/
  app/                  Shell: compone los features y decide qué pantalla ver
  core/
    core_errors/        Failure compartido
    core_network/       Supabase, reintentos y mapeo de errores
    core_storage/       Caché local cifrada
    core_telemetry/     Analytics, Crashlytics y Performance con filtro de privacidad
    core_ui/            Tema accesible y componentes compartidos
  features/
    feature_onboarding/       Registro en 3 pasos, login y sesión
    feature_accounts/         Cuentas, saldo, movimientos y registrar un movimiento
    feature_personalization/  Home por segmento (Remote Config) y resumen de gastos
    feature_exchange/         Conversor de remesas EUR→USD (tasas del BCE)
    feature_notifications/    Notificaciones push (FCM): permiso, token y avisos
docs/                   Contrato del backend y documentos de arquitectura
```

El trabajo se desarrolla con **Trunk Based Development**: commits pequeños
directos a `main`, con CI en cada push.

## Documentación

- [`documentacion/sdd.md`](documentacion/sdd.md): especificación de la app, trazabilidad requisito→verificación y cómo se aplicó el desarrollo guiado por especificaciones.
- [`documentacion/despliegue.md`](documentacion/despliegue.md): entornos, secretos, CI, publicación y reversión.
- [`documentacion/ia/uso-de-ia.md`](documentacion/ia/uso-de-ia.md): cómo se usó la IA en el desarrollo y su impacto.
- [`documentacion/ia/prompt-maestro.md`](documentacion/ia/prompt-maestro.md): síntesis de las instrucciones que guiaron a los agentes (roles, arquitectura, contratos, flujo).
- [`packages/app/README.md`](packages/app/README.md): configuración, pruebas, cómo colaborar y el guion de demostración.
- README de cada paquete con su API, decisiones, recortes y eventos de telemetría.

## Ejecutar con el backend desplegado

El backend de Supabase ya está desplegado: no hace falta levantar nada en local.
Con un dispositivo Android conectado:

```bash
melos bootstrap
cd packages/app
flutter run -d <id-del-dispositivo> --dart-define=TELEMETRY_DEBUG=true \
  --dart-define=SUPABASE_URL=https://pzpolkpedpjtkaplulxc.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB6cG9sa3BlZHBqdGthcGx1bHhjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEyNDgyNjYsImV4cCI6MjEwNjgyNDI2Nn0.WLx9Hdwx5IFOgboRBM0_MJV4g9Ypl2_D7zC4kAtcP4E
```

Es la clave anónima (publicable); el acceso lo limita RLS. Nunca la `service_role`.
Para las pruebas y el E2E, y para cómo guiar la demostración, ver
[`packages/app/README.md`](packages/app/README.md).

## Ejecutar en local (backend propio)

### 1. Requisitos
Flutter, `melos` (`dart pub global activate melos 8.9.0`), el CLI de Supabase y,
para el Android físico, `adb`. Desde la raíz del repo:

```bash
melos bootstrap
```

### 2. Backend (en el repo del backend)

```bash
supabase start
supabase status          # copia la clave publicable
./scripts/create_demo_users.sh
```

Usuarios demo (contraseña `demo1234`): `joven@demo.com` y `adulto@demo.com`.

### 3. App en un Android físico

```bash
adb devices
adb reverse tcp:54421 tcp:54421
flutter devices          # apunta el id del dispositivo
cd packages/app
flutter run -d <id-del-dispositivo> \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
  --dart-define=SUPABASE_ANON_KEY=<la-clave-publicable>
```

`adb reverse` se pierde al desconectar el cable o reiniciar el teléfono: repite
ese comando si la app deja de conectar.

### 4. App en macOS (sin teléfono)

```bash
cd packages/app
flutter run -d macos \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
  --dart-define=SUPABASE_ANON_KEY=<la-clave-publicable>
```

La clave es la **publicable**; nunca uses la `service_role` ni la secret key.
Sin los `--dart-define`, la app muestra "Falta configurar la app" con los
nombres esperados. El detalle de cada plataforma (emulador Android, simulador
iOS, IP de la red local, problemas frecuentes) está en
[`packages/app/README.md`](packages/app/README.md).

## Firebase, telemetría y home personalizado

Proyecto de Firebase: `banco-demo-05487` (Android: `com.bancointernacional.banco_app`).

- **Telemetría** (`core_telemetry`): eventos de Analytics, errores en Crashlytics
  y trazas de Performance. Un filtro de privacidad solo deja pasar una lista
  cerrada de parámetros (sin correos, nombres, saldos ni importes). La recolección
  está apagada en debug; para verla en `DebugView`:

  ```bash
  adb shell setprop debug.firebase.analytics.app com.bancointernacional.banco_app
  cd packages/app
  flutter run -d <id-del-dispositivo> --dart-define=TELEMETRY_DEBUG=true \
    --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
    --dart-define=SUPABASE_ANON_KEY=<la-clave-publicable>
  ```

  Eventos: `app_opened` y `block_viewed` (con `block_id`, `block_type`, `segment`).

- **Home personalizado** (`feature_personalization`): el parámetro `home_layout`
  de Remote Config (JSON) define qué bloques ve cada segmento y en qué orden.
  Si Remote Config falla o publica un JSON inválido, la app usa el último layout
  válido o el embebido. Para probarlo, edita el JSON en la consola de Firebase,
  publica y la app lo aplica sin reiniciar. El JSON de ejemplo y las reglas del
  parser están en
  [`packages/features/feature_personalization/README.md`](packages/features/feature_personalization/README.md).

## Probar

Desde la raíz del repo, igual que el CI:

```bash
melos exec -- flutter analyze
melos exec --diff=HEAD --include-dependents --dir-exists=test -- flutter test --reporter expanded --exclude-tags integration
```

La segunda corre solo los paquetes que cambiaron y los que dependen de ellos.
Para todos los paquetes: `melos run test`.

Dos pruebas extra, fuera del CI y ejecutadas a mano:

```bash
# E2E en dispositivo (casos de uso falsos, sin backend)
cd packages/app
flutter test integration_test/login_balance_test.dart -d <id-del-dispositivo>

# Integración contra el backend local (necesita los --dart-define)
melos exec --scope=banco_app -- flutter test --tags integration \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
  --dart-define=SUPABASE_ANON_KEY=<la-clave-publicable>
```
