# Prompt maestro: plataforma financiera digital en Flutter

> **Nota de origen:** síntesis retrospectiva, redactada al cierre del proyecto. Las instrucciones originales se dieron por piezas y están en `docs/ia/prompts/` (carpeta local que se publicará con el repositorio).

## 1. Roles

- **El autor dirige y responde por el resultado.** Propone la arquitectura y el stack, define el alcance, las prioridades y los recortes, reparte el trabajo entre agentes (varias ventanas en paralelo, orquestadas con Orca), ejecuta los comandos, prueba en un dispositivo Android físico, y **evalúa y acepta (o rechaza) cada pieza** antes de hacer el commit y el merge. Da fe del resultado porque lo fue validando todo el tiempo.
- **La IA aplica y codifica.** Implementa cada pieza dentro de la arquitectura y las reglas del autor, escribe sus pruebas, y **no decide la arquitectura**. No ejecuta comandos de git ni de verificación salvo donde se le autoriza expresamente. Si falta algo o hay un conflicto, **se detiene y lo dice**.
- **Regla de verdad:** ante cualquier diferencia entre este texto y el código real, **manda el código**. Antes de escribir, lee lo que existe.
- **Honestidad:** no afirmes que algo funciona sin haber visto la salida real que te devuelve el autor.

## 2. Objetivo del reto

Plataforma financiera digital, sin atención física, centrada en experiencias personalizadas y con capacidad de integrar servicios propios o de terceros en un mismo ecosistema, que pueda evolucionar hacia dominios administrados por equipos independientes y que incorpore nuevas experiencias sin republicar la app.

**Alcance mínimo:** onboarding y autenticación; cuentas, saldos y movimientos; personalización dinámica; un servicio o micro aplicativo externo; notificaciones push; explicar el monitoreo en producción; describir el comportamiento ante conectividad limitada, latencia e indisponibilidad parcial; pruebas unitarias, de widgets y un E2E crítico; documentar el uso de IA; y demostrar la conectividad degradada (carga, reintentos, caché, recuperación).

**Entregables:** código con historial, README reproducible (configurar, ejecutar, probar, colaborar), documentación de arquitectura y decisiones (con diagramas, supuestos, riesgos y escalamiento), estrategia de despliegue y operación, y demostración funcional. **Control de versiones: Trunk Based Development.** No se valoran soluciones con datos simulados: debe haber interacción real con servicios.

## 3. Arquitectura (decidida por el autor)

- **Monorepo** Flutter con **Pub Workspaces + Melos 8.9**: la configuración vive en el `pubspec.yaml` raíz; cada paquete lleva `resolution: workspace`; dependencias internas por nombre, sin `path:`.
- **Paquetes:**
  - `core_errors` (Failure), `core_network` (`SupabaseConfig`, `buildRetryClient`, `mapToFailure`, inyección de fallos en debug), `core_storage` (caché cifrada), `core_telemetry` (interfaz `Telemetry` y filtro de privacidad), `core_ui` (tema, componentes, formato de dinero y fechas, vistas de estado).
  - `feature_onboarding`, `feature_accounts`, `feature_personalization`, `feature_exchange`, `feature_notifications`.
  - `packages/app`: el shell que compone todo (navegación, GetIt, panel de depuración).
- **Reglas de dependencia:** un feature **nunca** depende de otro feature, solo de `core_*`; solo el shell conoce a varios features y los conecta con callbacks y registro de bloques. Ningún widget ni Cubit importa `supabase_flutter`: solo la capa de datos toca Supabase.
- **Capas por feature:** `presentation` (Cubit + pantallas) → `domain` (casos de uso, entidades, interfaces; sin Flutter ni plugins) ← `data` (repositorios y data sources).
- **Estado:** Cubit con `flutter_bloc`. **DI:** GetIt, solo en la raíz de composición y en funciones de registro por feature. **Navegación:** Navigator estándar.
- **Dinero:** siempre enteros en centavos; conversión a decimal exacto solo al enviar; **jamás `double`**.
- **Seguridad:** solo la clave publicable (`publishableKey`; `anonKey` está deprecado); nunca `service_role`; nada de URLs ni claves en el código; caché cifrada con la clave en almacenamiento seguro; RLS por usuario.
- **Privacidad:** la telemetría solo deja pasar una lista cerrada de parámetros y únicamente el **código** de un error, nunca su mensaje, ni correos, nombres, importes o descripciones.

## 4. Contratos (se fijan antes de implementar)

- **Backend de apoyo (Supabase):** tablas `accounts`, `transactions` (inmutables; `amount` siempre positivo; el sentido lo da `type` = `credit` o `debit`; `balance_after`), `profiles` (con `segment`, calculado por el backend según la edad), `segments`, `device_tokens`; funciones `add_demo_movement`, `spending_by_category` y `register_device_token`; el saldo lo calcula un trigger y un débito sin fondos falla con `insufficient_funds`.
- **API pública de `core_ui`:** tema claro y oscuro desde tokens, botones y campos, `formatCents`, formato de fechas en español, `AmountText` (signo y color, nunca solo color), vistas de estado (`ErrorView` y `EmptyView` necesitan alto acotado) y `messageForFailure`.
- **API pública de cada feature:** un barril con sus pantallas, entidades y casos de uso necesarios, y su función `registerXDependencies(GetIt)`; nunca clases de la capa de datos.
- **JSON de personalización** (`home_layout` en Remote Config): `schema_version`, lista `default` y lista por segmento; tipos de bloque `tip`, `promo`, `spending_summary` y `exchange_rate`; un JSON inválido, una versión no soportada o su ausencia caen al layout por defecto embebido; los tipos desconocidos se ignoran.
- **Mensaje de push:** "Dinero recibido" para créditos y "Movimiento registrado" para débitos, **sin importes**; `data` con `transaction_id`, `account_id` y `type`; canal de Android `movements`; envío a todos los dispositivos del usuario.

## 5. Qué se construyó

- **Onboarding y sesión:** registro en tres pasos (acceso con contraseña de al menos 8 caracteres, datos con mayoría de edad, uso de la cuenta), login, cierre de sesión, sesión restaurada, y lectura del segmento (`joven` o `adulto`).
- **Cuentas:** saldo y movimientos reales con paginación (`offset` y `limit`, orden estable) y registrar un movimiento como función de demostración.
- **Personalización:** el home cambia por segmento con Remote Config, en vivo, con un resumen de gastos por categoría.
- **Servicio externo:** conversor EUR→USD con una API pública (tasas diarias del BCE), con la fecha visible, reintentos y caché, y cálculo con aritmética entera; patrón Adapter.
- **Push:** permiso (Android 13 o superior), registro del token, borrado del token **antes** de cerrar sesión, aviso en primer plano y toque que abre la cuenta. En el backend, un disparador asíncrono llama a una Edge Function que envía por FCM con idempotencia, y un fallo nunca revierte el movimiento.
- **Monitoreo:** Analytics, Crashlytics y Performance a través de `Telemetry`, con eventos del shell (`app_opened`, `login_success`, `register_completed`, `sign_out`, `screen_viewed`), de personalización (`block_viewed`) y eventos finos por feature, ya integrados: `register_step_completed`, `register_failed`, `login_failed`, `cache_served`, `retry_exhausted`, `movement_added`, `push_permission` y `push_opened`, más trazas `load_balance`, `load_movements` y `load_exchange_rate`.
- **Resiliencia:** reintentos con backoff; caché cifrada con *cache-then-network*; modo sin conexión que muestra los datos guardados con su fecha; recuperación automática; **dos clientes HTTP independientes** (backend y tasas) con fallos configurables por separado desde un panel de depuración solo en debug.

## 6. Pruebas

Proporcionales al riesgo: a fondo en lo crítico (dinero y su conversión, errores, reintentos, caché, paginación, privacidad, ciclo de vida del token, reglas de negocio) y nada en lo trivial (tema, textos, aspecto). Falsos escritos a mano y sin red en el CI. **Un E2E** con `integration_test` contra el backend real, en dispositivo: login → home → cuenta → sin conexión → recuperación → cierre de sesión. No corre en el CI.

## 7. Flujo de trabajo

1. El autor entrega una **pieza** (una unidad pequeña y completa) con contexto, propiedad de carpetas, entregable, pruebas y criterios de aceptación.
2. La IA lee el código real, implementa solo esa pieza y sus pruebas, y se detiene. Si necesita algo ajeno, lo pide.
3. El autor ejecuta `melos run analyze` y `melos run test`, prueba en el dispositivo y devuelve la salida real.
4. Con todo en verde, el autor integra con **Trunk Based Development:** parte de `main` actualizado, rama corta `feat/<package>-<what>`, uno o dos commits, merge `--no-ff` a `main` el mismo día, rama borrada, y CI en verde antes de abrir la siguiente pieza. Prohibido Git Flow y acumular piezas en una rama. (En las primeras piezas los commits se subieron directamente a `main`; la rama corta por pieza se formalizó a partir del frente de notificaciones.)
5. **Mensajes de commit y de merge en inglés**, en modo imperativo y con conventional commits y el paquete como alcance (por ejemplo `feat(core_ui): add theme tokens`). Los primeros commits del historial están en español; el criterio del inglés rige desde el frente de notificaciones.

**Orden en que se trabajó:** workspace y CI → conexión al backend (red, errores, auth, cuentas, movimientos) → sistema de diseño y onboarding en paralelo → shell con sesión → pantalla de cuentas y movimientos → caché, modo sin conexión y panel de depuración → Firebase, telemetría y personalización → push → tasas → registrar movimiento → integración en el shell y E2E → eventos finos de telemetría.

## 8. Criterios de aceptación globales

```bash
melos run analyze
melos run test
grep -rl "package:supabase_flutter" packages/features packages/core/core_ui --include="*.dart"
grep -rnE "service_role|anonKey|1250\.75" packages/*/lib packages/*/*/lib
grep -rnE "127\.0\.0\.1|10\.0\.2\.2|eyJhbGci|sb_(publishable|secret)_" packages/*/lib packages/*/*/lib
```

Los tres `grep` no deben devolver resultados, con una excepción conocida: el último encuentra el mensaje de error de `SupabaseConfig` que sugiere el comando con la URL local, que no es una URL usada por el código. Además, el CI debe mostrar `flutter test` ejecutándose en los paquetes modificados y no un verde por diff vacío.

## 9. Fuera de alcance y limitaciones declaradas

- **Recortado por decisión:** la mini-app embebida por WebView, la cola de operaciones sin conexión, la configuración de alertas de monitoreo, la entrega continua del APK firmado y el hardening (certificate pinning, detección de root, biometría).
- **Pendiente documentado:** la sesión de Supabase usa el almacenamiento por defecto, no cifrado.
- **Por diseño:** transferencias, pagos y tarjetas quedan fuera; registrar un movimiento es una función de demostración que sustituye al núcleo bancario; las tasas son diarias, no en tiempo real.
