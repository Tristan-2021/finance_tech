# banco_app

Shell de la app (`packages/app`): compone los features y decide qué pantalla se
ve. Hoy muestra el flujo de **registro, login, pantalla provisional con nombre
y segmento, y cierre de sesión**. La pantalla provisional (`lib/welcome_page.dart`)
la reemplazará la pantalla de cuentas.

```
lib/
  main.dart             Lee la configuración e inicia la app (o muestra el error)
  di.dart               Raíz de composición (GetIt): SupabaseClient + features
  app.dart              MaterialApp, temas, localización y rutas
  session_gate.dart     Decide login o pantalla provisional según la sesión
  welcome_page.dart     Pantalla provisional (saludo, segmento, cerrar sesión)
  config_error_app.dart Se muestra si faltan los --dart-define
```

## 1. Configuración: `--dart-define`

La URL y la clave **no están en el repo**; se pasan al ejecutar. Sin ellas la
app no se cae: muestra la pantalla "Falta configurar la app" con los nombres
esperados.

| Define              | Valor |
| ------------------- | ----- |
| `SUPABASE_URL`      | URL del backend (ver cada plataforma abajo) |
| `SUPABASE_ANON_KEY` | La clave **publicable** del backend local. El nombre del define es el antiguo; el valor es la *publishable key* |

Nunca uses la `service_role` ni la secret key en la app.

**Obtener la clave publicable:** en el proyecto del backend, con Supabase
levantado:

```bash
supabase status
```

Copia el valor de la clave publicable (en versiones anteriores del CLI aparece
como `anon key`).

## 2. Levantar el backend (lo haces tú, en el repo del backend)

```bash
supabase start                      # API en http://127.0.0.1:54421
./scripts/create_demo_users.sh      # joven@demo.com y adulto@demo.com
./scripts/seed_demo_movements.sh    # opcional: movimientos de ejemplo
```

Usuarios demo (contraseña `demo1234`):

| Correo            | Segmento esperado |
| ----------------- | ----------------- |
| `joven@demo.com`  | `joven`  (24 años) |
| `adulto@demo.com` | `adulto` (41 años) |

`supabase db reset` borra los usuarios: vuelve a correr `create_demo_users.sh`.

## 3. Caso principal: dispositivo Android físico

El backend corre en tu Mac en `http://127.0.0.1:54421`. Desde el teléfono,
`127.0.0.1` es el propio teléfono, no el Mac. La forma soportada es
`adb reverse`: el teléfono llega al backend como `http://127.0.0.1:54421`, sin
depender de la red ni del firewall.

```bash
# 1. El teléfono debe aparecer como "device" (no "unauthorized" ni vacío)
adb devices

# 2. Redirige el puerto del teléfono al de tu Mac
adb reverse tcp:54421 tcp:54421

# 3. Comprueba la redirección (debe listar tcp:54421 tcp:54421)
adb reverse --list

# 4. Obtén el id del dispositivo y ejecuta
flutter devices
cd packages/app
flutter run -d <id-del-dispositivo> \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

> `adb reverse` **se pierde** al desconectar el cable o reiniciar el teléfono.
> Si la app deja de conectar, repite el paso 2.

### Alternativa: IP de la red local del Mac

Si no puedes usar `adb reverse`:

```bash
ipconfig getifaddr en0     # IP del Mac en el Wi-Fi, p. ej. 192.168.1.20
flutter run -d <id> \
  --dart-define=SUPABASE_URL=http://<IP-del-Mac>:54421 \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

El teléfono y el Mac deben estar en el **mismo Wi-Fi**, y el firewall del Mac
debe permitir conexiones entrantes al puerto 54421.

## 4. Otras plataformas

| Plataforma         | `SUPABASE_URL`                     |
| ------------------ | ---------------------------------- |
| Emulador Android   | `http://10.0.2.2:54421`            |
| Simulador iOS      | `http://127.0.0.1:54421`           |
| macOS              | `http://127.0.0.1:54421`           |

```bash
cd packages/app
flutter run -d <emulador|simulador|macos> \
  --dart-define=SUPABASE_URL=<url-de-la-tabla> \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

En macOS la app necesita el permiso de red saliente
(`com.apple.security.network.client`), que ya está en
`macos/Runner/DebugProfile.entitlements` y `Release.entitlements`.

## 5. Qué deberías ver

1. **Sin `--dart-define`:** la pantalla "Falta configurar la app" con los
   nombres `SUPABASE_URL` y `SUPABASE_ANON_KEY`.
2. **Primer arranque sin sesión:** un instante de carga y luego el **login**
   ("Inicia sesión").
3. **Login con `joven@demo.com`:** pantalla con "Hola, <nombre>", el chip
   "Segmento: joven" y "Tus cuentas aparecerán aquí".
4. **Login con `adulto@demo.com`:** igual, con "Segmento: adulto".
5. **Contraseña incorrecta:** el mensaje "Correo o contraseña incorrectos." sin
   vaciar los campos.
6. **Cerrar sesión:** vuelve al login; el botón de retroceso no regresa a la
   pantalla anterior.
7. **Crear cuenta:** registro en 3 pasos (correo y contraseña de 8 o más
   caracteres; nombre y fecha de nacimiento, **mayor de 18 años**; uso de la
   cuenta). Al terminar entra a la pantalla con tu nombre y el segmento que
   calcula el backend según tu edad (18 a 29 = `joven`, 30 o más = `adulto`).
8. **Relanzar la app con la sesión abierta:** entra directo a la pantalla
   provisional, sin pasar por el login.
9. **Tema oscuro y texto del sistema al máximo:** todo debe seguir legible y sin
   desbordes.

## 6. Problemas frecuentes

| Síntoma | Causa probable |
| ------- | -------------- |
| "Falta configurar la app" | Faltan `SUPABASE_URL` o `SUPABASE_ANON_KEY` en `flutter run` |
| Error de red / "Sin conexión" en Android físico | Se perdió `adb reverse`; repite `adb reverse tcp:54421 tcp:54421` |
| El login falla con usuarios demo | Backend apagado, o se hizo `supabase db reset` sin recrear los usuarios |
| "Correo o contraseña incorrectos." con credenciales correctas | Usuario inexistente en este backend; corre `create_demo_users.sh` |
| `adb devices` no lista el teléfono | Depuración USB desactivada o sin autorizar el equipo |

## 7. Tráfico http solo en desarrollo

El backend local usa http, no https:

- **Android:** `android:usesCleartextTraffic="true"` está **solo** en
  `android/app/src/debug/AndroidManifest.xml`. El manifest `main` (el de
  release) solo declara el permiso `INTERNET`, sin tráfico no cifrado.
- **iOS:** por defecto no se necesita nada. Si el simulador bloquea la
  conexión, añade `NSAllowsLocalNetworking` en `NSAppTransportSecurity` solo
  para debug y no en el `Info.plist` de release.

## 8. Pruebas

Desde la raíz del repo, igual que el CI:

```bash
melos exec -- flutter analyze
melos exec --scope=banco_app -- flutter test --reporter expanded --exclude-tags integration
```

Las pruebas de widgets usan casos de uso falsos registrados en GetIt: no
necesitan backend. La prueba de integración
(`test/integration/demo_users_test.dart`) sí lo necesita y **no corre en el CI**:

```bash
melos exec --scope=banco_app -- flutter test --tags integration --reporter expanded \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
  --dart-define=SUPABASE_ANON_KEY=<publishable-key>
```

## Realtime y reconexión

Realtime usa WebSocket y no pasa por el `RetryClient` de `core_network`; la
reconexión la gestiona la librería. Los eventos ocurridos durante una
desconexión no se reenvían, así que al recuperar conectividad la app debe
refrescar saldo y movimientos por la API.
