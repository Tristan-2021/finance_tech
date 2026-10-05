# finance_tech

Plataforma financiera digital en Flutter, organizada como monorepo con Pub
Workspaces y Melos. Hoy incluye el flujo de **registro, login, cuentas, saldo y
movimientos** contra un backend Supabase local.

```
packages/
  app/                  Shell: compone los features y decide qué pantalla ver
  core/
    core_errors/        Failure compartido
    core_network/       Supabase, reintentos y mapeo de errores
    core_ui/            Tema accesible y componentes compartidos
  features/
    feature_onboarding/ Registro en 3 pasos, login y sesión
    feature_accounts/   Cuentas, saldo y movimientos
docs/                   Contrato del backend y documentos de arquitectura
```

## Ejecutar en local

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
