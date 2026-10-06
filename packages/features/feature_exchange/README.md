# feature_exchange

Conversor de remesas EUR → USD con datos reales de
[Frankfurter](https://frankfurter.dev) (tasas de referencia del Banco Central
Europeo, sin clave). Es un bloque para el home, no una pantalla.

## Uso (lo integra el shell)

```dart
registerExchangeDependencies(getIt, httpClient: client); // client: el de debug o http.Client()
// ...
const ExchangeCard(); // from = 'EUR', to = 'USD'
```

El shell inyecta el `http.Client`: en debug es el que inyecta fallos, así la
demostración de conectividad cubre también este servicio. El paquete lo
envuelve con `buildRetryClient` (3 reintentos con backoff; 502/503/504 y
errores de red). Si el shell registró un `CacheStore` y un
`NetworkStatusNotifier`, se usan.

## Servicio externo

`GET https://api.frankfurter.dev/v1/latest?base=EUR&symbols=USD` →
`{"amount":1.0,"base":"EUR","date":"2026-10-05","rates":{"USD":1.1204}}`.
Las tasas son **diarias, no en tiempo real**: la tarjeta muestra la fecha de la
tasa y lo aclara.

El servicio queda detrás de `ExchangeRateRemoteDataSource` (patrón *Adapter*):
cambiar de proveedor es escribir otra implementación.

## Dinero sin `double`

- La tasa se interpreta desde la cadena decimal del JSON y se guarda como
  entero escalado a 6 decimales (`1.1204` → `1120400`). Notación científica,
  cero, negativos o texto se rechazan.
- El monto se escribe con coma o punto (máx. 2 decimales) y se convierte a
  centavos con enteros.
- Conversión: `(centavos * tasa + 500000) ~/ 1000000`. **Redondeo: a la mitad
  hacia arriba** sobre el centavo destino.

## Caché y recuperación

*Cache-then-network*: con red guarda la tasa; si el servicio no responde
(`network` o `unknown`) sirve la última guardada y la tarjeta avisa
"Sin conexión: tasa guardada del {fecha}" con **Reintentar**. Sin copia y sin
red muestra el error con **Reintentar**. Se recupera sola al reintentar.

## Telemetría

Los repositorios reciben un `Telemetry` (`core_telemetry`);
`registerExchangeDependencies` lo toma de GetIt si está registrado y, si no, no
emiten nada. Solo claves permitidas por el filtro de privacidad: nunca montos,
tasas ni monedas.

| Evento / traza | Cuándo | Parámetros |
|---|---|---|
| `cache_served` | Se sirve la tasa guardada por un fallo del servicio | `source: exchange` |
| `retry_exhausted` | La petición falla con código `network` tras los reintentos | `source: exchange`, `code` |
| traza `load_exchange_rate` | Llamada remota a Frankfurter | |

## Recortes

- Solo EUR → USD en la interfaz (el paquete acepta otros pares, pero la UI y la
  caché solo se probaron con ese).
- El proveedor no se puede cambiar en tiempo de ejecución ni hay alternativa si
  Frankfurter cae.
- Sin prueba E2E propia: la integración con el home y el cliente de debug
  corresponde al shell.
