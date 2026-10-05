# feature_personalization

Home dinámico por segmento (Remote Config) y resumen de gastos (RPC
`spending_by_category`). Esta entrega cubre **dominio y datos**; la
presentación (`PersonalizedHome`, `BlockRegistry`, `HomeCubit`) viene después.

## Layout (`home_layout`)

JSON en el parámetro `home_layout` de Remote Config. El valor embebido está en
`lib/src/data/default_layout.dart` y se usa si Remote Config falla o publica
algo inválido (se conserva siempre el último válido).

Reglas del parser (`HomeLayoutParser`):

1. JSON mal formado o raíz que no es objeto → inválido.
2. `schema_version` debe ser `1`.
3. Bloques con tipo desconocido, sin `id` o con `id` repetido se descartan.
4. Máximo 12 bloques por lista.
5. `default` es obligatorio y debe quedar con ≥ 1 bloque; segmentos vacíos se
   omiten y caen en `default`.

Tipos de bloque: `tip`, `promo`, `spending_summary`, `exchange_rate`.
El segmento es un dato (`String`), no un enum.

## Resumen de gastos

Todo en centavos (`int`). El porcentaje de variación usa división entera.

## Recortes conocidos

- `parseAmountToCents` duplica el `parseCents` de `feature_accounts`
  (deuda técnica: unificar en un core).
- La actualización en tiempo real depende de `onConfigUpdated`, que no está
  soportado en Windows.
