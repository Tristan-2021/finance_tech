# feature_personalization

Home dinámico por segmento (Remote Config) y resumen de gastos (RPC
`spending_by_category`).

## Uso desde el shell

```dart
registerPersonalizationDependencies(getIt); // requiere un SupabaseClient
// Telemetry es opcional: si está registrada se usa para block_viewed.

AccountsPage(..., extra: PersonalizedHome(segment: profile.segment));
```

`PersonalizedHome` resuelve sus Cubits desde GetIt. El shell inyecta el widget
en `AccountsPage` (`extra`) porque `feature_accounts` no conoce este feature.

## Parámetro `home_layout` en Remote Config

Crear en la consola de Firebase (Remote Config → Añadir parámetro) el
parámetro `home_layout`, tipo **JSON**, con este valor y **publicar los
cambios**:

```json
{
  "schema_version": 1,
  "default": [
    {"id": "tip_default", "type": "tip", "params": {"text": "Revisa tus movimientos con frecuencia."}},
    {"id": "spending_default", "type": "spending_summary"}
  ],
  "segments": {
    "joven": [
      {"id": "promo_joven", "type": "promo", "params": {"title": "Ahorra desde hoy", "body": "Activa tu meta de ahorro."}},
      {"id": "spending_joven", "type": "spending_summary"},
      {"id": "tip_joven", "type": "tip", "params": {"text": "Separa un 10% de cada ingreso."}}
    ],
    "adulto": [
      {"id": "spending_adulto", "type": "spending_summary"},
      {"id": "rate_adulto", "type": "exchange_rate", "params": {"pair": "USD/EUR", "rate": "0.92"}},
      {"id": "tip_adulto", "type": "tip", "params": {"text": "Revisa tus servicios recurrentes."}}
    ]
  }
}
```

Para probar el cambio en vivo: editar el JSON (p. ej. cambiar el orden de los
bloques de `joven`) y publicar. La app lo aplica sin reiniciar (el real-time de
Remote Config no funciona en Windows; en ese caso se aplica al abrir la app).

El valor embebido (`lib/src/data/default_layout.dart`) se usa si Remote Config
falla o publica algo inválido; siempre se conserva el último layout válido.

### Reglas del parser (`HomeLayoutParser`)

1. JSON mal formado o raíz que no es objeto → inválido.
2. `schema_version` debe ser `1`.
3. Bloques con tipo desconocido, sin `id` o con `id` repetido se descartan.
4. Máximo 12 bloques por lista.
5. `default` es obligatorio y debe quedar con ≥ 1 bloque; segmentos vacíos se
   omiten y caen en `default`.

### Bloques

| `type` | Parámetros | Notas |
|---|---|---|
| `tip` | `text` | Sin `text` no se dibuja. |
| `promo` | `title`, `body` | Sin `title` no se dibuja. |
| `spending_summary` | — | Datos reales de la RPC; estados cargando/vacío/error. |
| `exchange_rate` | `pair`, `rate` (texto) | Valor de referencia publicado en la config, no en vivo. |

Para añadir un tipo: valor en `BlockType`, widget y entrada en `BlockRegistry`.

## Telemetría

`block_viewed` con `block_id`, `block_type` y `segment`, una vez por bloque y
por apertura del home. Nunca importes ni datos del usuario.

## Recortes conocidos

- `parseAmountToCents` duplica el `parseCents` de `feature_accounts`
  (deuda técnica: unificar en un core).
- Al cambiar de cuenta en `AccountsPage` el home se recrea y vuelve a pedir el
  resumen (y a registrar `block_viewed`).
- `exchange_rate` es un valor de referencia estático, sin fuente en vivo.
