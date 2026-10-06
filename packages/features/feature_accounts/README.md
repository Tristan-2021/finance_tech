# feature_accounts

Cuentas, saldo y movimientos del cliente, con caché cifrada y modo sin
conexión, más el registro de un movimiento manual de demostración.

## Qué incluye

- **Cuentas y saldo:** `AccountsPage` (el shell le pasa nombre, segmento y el
  cierre de sesión; opcionalmente `extra`, un widget que se dibuja bajo el saldo).
- **Movimientos:** lista paginada (offset/limit) con pull-to-refresh.
- **Caché y sin conexión:** *cache-then-network*; si falla la red se sirven los
  datos guardados con un aviso y la fecha (`StaleList`).
- **Registrar movimiento:** botón en la pantalla de cuentas que abre un
  formulario.

Registro en el contenedor: `registerAccountsDependencies(GetIt)` (asume un
`SupabaseClient`; usa `CacheStore`, `Telemetry` y los demás extras solo si están
registrados).

## Registrar movimiento (demostración)

En un banco real los movimientos los genera el núcleo bancario, no el cliente.
Esta función es un **sustituto declarado** para poder demostrar el flujo
acción → saldo → push → resumen, y así se rotula en la interfaz ("Gasto manual
(demostración)"). Los movimientos son **inmutables**: no hay editar ni borrar, a
propósito.

- **RPC:** `add_demo_movement(p_account_id, p_type, p_amount, p_category,
  p_description)`. Valida que la cuenta sea del usuario y rechaza un débito mayor
  al saldo con `insufficient_funds` ("Saldo insuficiente.").
- **Dinero sin `double`:** el texto del monto (coma o punto, máx. 2 decimales,
  mayor que cero, tope 1.000.000,00) se interpreta a centavos con enteros y se
  envía como **cadena decimal exacta** (`1230` → `"12.30"`).
- **Formulario:** tipo (gasto o ingreso), monto, categoría de una lista fija
  (gasto: comida, transporte, ocio, servicios, otros; ingreso: ingreso, otros) y
  descripción opcional de hasta 80 caracteres (por defecto "Gasto manual" /
  "Ingreso manual").
- **Al guardar:** cierra el formulario y refresca el saldo y la primera página de
  movimientos (lo que también actualiza la caché).
- **Telemetría:** `movement_added` con `result` (y `code` si falla); nunca
  importes.

### Telemetría

Los repositorios y el formulario reciben un `Telemetry` (`core_telemetry`);
`registerAccountsDependencies` lo toma de GetIt si está registrado y, si no, no
emiten nada. Solo claves permitidas por el filtro de privacidad: nunca nombres
de cuenta, descripciones, saldos ni importes.

| Evento / traza | Cuándo | Parámetros |
|---|---|---|
| `cache_served` | Se sirven datos guardados por un fallo del servidor | `source` (`accounts` o `movements`) |
| `retry_exhausted` | La petición falla con código `network` tras los reintentos | `source`, `code` |
| `movement_added` | Se intenta registrar un movimiento | `result` (`ok` o `error`) y `code` si falla |
| traza `load_balance` | Carga remota de las cuentas (saldo) | |
| traza `load_movements` | Carga remota de una página de movimientos | |

### Prueba contra el backend real

Las pruebas con falsos no detectan si el RPC acepta la cadena para su parámetro
`numeric`. Con `supabase start` y el usuario demo creado:

```bash
cd packages/features/feature_accounts
flutter test test/movement_rpc_integration_test.dart \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54421 \
  --dart-define=SUPABASE_ANON_KEY=<la-clave-publicable>
```

Crea un movimiento de 0,01 en la cuenta del usuario demo y comprueba que el
saldo sube un centavo. Sin los `--dart-define` se omite (el CI no la ejecuta).

### Recortes

- **Sin conexión no se puede registrar:** falla con un mensaje claro. No hay cola
  de envíos pendientes (fuera de alcance).
- Las categorías son una lista fija en el cliente, no se leen del backend.
- La escritura va en `MovementWriteRepository`, una interfaz aparte de
  `TransactionRepository`, para no ampliar la de lectura.
