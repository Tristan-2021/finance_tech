# feature_onboarding

Registro, inicio de sesión, cierre de sesión y lectura del perfil. Depende solo
de paquetes `core_*` (`core_errors`, `core_network`, `core_ui`).

## API pública

Todo sale de `package:feature_onboarding/feature_onboarding.dart`:

| Qué | Para qué |
|---|---|
| `LoginPage(onAuthenticated, onGoToRegister)` | Pantalla de login |
| `RegisterPage(onRegistered, onGoToLogin)` | Registro en 3 pasos |
| `registerOnboardingDependencies(GetIt)` | Registro de dependencias |
| `GetCurrentUser` | Usuario de la sesión (`AuthUser?`), lectura local y síncrona |
| `SignOut` | Cierra la sesión (`Failure?`) |
| `GetUserProfile` | Nombre y segmento (`UserProfile`) |
| `SignIn` | Iniciar sesión sin pantalla (p. ej. pruebas de integración) |
| `AuthUser`, `UserProfile` | Entidades propias; no se expone el `User` de Supabase |

Nada de `data/` se exporta. Un test lo comprueba.

## Cómo lo usa el shell

```dart
// Raíz de composición, después de registrar el SupabaseClient:
registerOnboardingDependencies(GetIt.instance);

// Navegación por callbacks (Navigator estándar):
LoginPage(
  onAuthenticated: () => /* ir al home */,
  onGoToRegister: () => /* ir a RegisterPage */,
);
RegisterPage(
  onRegistered: () => /* ir al home */,
  onGoToLogin: () => /* volver a LoginPage */,
);
```

`LoginPage` y `RegisterPage` resuelven su Cubit desde `GetIt.instance`, por eso
`registerOnboardingDependencies` debe haberse llamado antes. Los Cubits se
registran como fábricas y las páginas los cierran al salir.

### Puerta de sesión

`GetCurrentUser` y `SignOut` son los que consumirá la puerta de sesión del
shell: al arrancar, `GetCurrentUser()` decide entre el home (hay usuario) y
`LoginPage` (es `null`); `SignOut()` cierra la sesión y devuelve un `Failure?`.
La sesión la restaura Supabase al iniciar, así que la lectura no usa la red.

## Decisiones anotadas

- `GetCurrentUser` es síncrono: lee la sesión ya restaurada, sin red.
- El login tiene un estado extra, `LoginInvalid`, para los errores por campo.
- `LoginPage` y `RegisterPage` usan `GetIt.instance` (no reciben el contenedor).
- La contraseña del registro vive solo en memoria dentro del `RegisterCubit`,
  nunca en su estado, y se borra al terminar.
- `account_usage` se envía con el texto de la opción elegida ("Ahorrar",
  "Recibir remesas", …).
- Mayoría de edad: 18 años cumplidos; el día exacto del cumpleaños cuenta.
- En el registro, un `AuthException` usa el mensaje genérico de
  `messageForFailure("Correo o contraseña incorrectos.")`; está pendiente de
  decidir si el registro necesita un texto propio.
- `GetUserProfile` exige `full_name` y `segment`; si falta alguno devuelve un
  `Failure`.
- El selector de fecha sale en español solo si el shell configura las
  localizaciones de Material.
