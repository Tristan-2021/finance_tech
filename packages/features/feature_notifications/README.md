# feature_notifications

Cliente de notificaciones push: pide el permiso, registra el token FCM en el
backend (`register_device_token`), muestra los avisos con la app abierta y
avisa al shell cuando el usuario toca una notificación.

## Uso (lo integra el shell)

```dart
registerNotificationsDependencies(getIt);        // requiere un SupabaseClient
final notifications = getIt<NotificationsController>();

await notifications.initialize();                // al arrancar, antes del login
// tras autenticarse:
if (await showNotificationsPrePrompt(context)) {
  await notifications.start(onOpenAccounts: () { /* ir a cuentas y refrescar */ });
}
// al cerrar sesión, ANTES de cerrar la sesión de Supabase:
await notifications.stop();
```

- `start` pide el permiso (en Android 13+ es un permiso en tiempo de
  ejecución), registra el token y lo vuelve a registrar si rota. Si lo
  rechazan, no registra nada, no lanza errores y no vuelve a preguntar en la
  sesión.
- `stop` borra el token en el backend y luego el de FCM; es de mejor esfuerzo
  (máx. 3 s por paso) y nunca impide cerrar sesión. Así el siguiente usuario
  del mismo teléfono no recibe los avisos del anterior.
- Un aviso que abre la app antes del login se atiende cuando el shell llama a
  `start`.

## Contrato con el backend

Textos "Dinero recibido" / "Movimiento registrado" **sin montos**; `data` con
`transaction_id`, `account_id` y `type`; canal Android `movements`. La app no
interpreta montos del mensaje: al abrirla consulta el detalle por la API.

## Android

- `AndroidManifest.xml` (`packages/app`): permiso `POST_NOTIFICATIONS` y
  `com.google.firebase.messaging.default_notification_channel_id = movements`.
- El canal `movements` ("Movimientos", importancia alta) se crea en
  `initialize()`, antes de que llegue un mensaje.
- Con la app en segundo plano o cerrada, Android muestra por sí solo los
  mensajes con bloque `notification`; no hay handler de segundo plano. Con la
  app abierta, se muestra como notificación local en el mismo canal.
- Requisitos de los plugins (documentación de pub.dev): `firebase_messaging`
  16.x pide `firebase_core ^4.14.0`; `flutter_local_notifications` 22.x pide
  `compileSdk` ≥ 35, AGP ≥ 8.11.1 y Java 17. El *core library desugaring* solo
  se exige para notificaciones programadas, que esta app no usa.

## Telemetría

`NotificationsController` recibe un `Telemetry` (`core_telemetry`);
`registerNotificationsDependencies` lo toma de GetIt si está registrado. Nunca
se envía el texto del mensaje ni el token.

| Evento | Cuándo | Parámetros |
|---|---|---|
| `push_permission` | Al pedir el permiso en `start` | `result` (`granted` o `denied`) |
| `push_opened` | Al tocar una notificación | `source`: `foreground` (notificación local), `background` o `terminated` (abrió la app cerrada) |

## Recortes

- iOS/macOS no están configurados (solo Android).
- Tocar una notificación local lleva siempre a cuentas, sin distinguir por
  `transaction_id`.
