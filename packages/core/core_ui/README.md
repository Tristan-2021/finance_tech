# core_ui

Sistema de diseño compartido (Material 3, fuentes del sistema, sin
dependencias de terceros). Todo se importa desde `package:core_ui/core_ui.dart`.

## Tema (pieza 1)

- `AppTheme.light()` / `AppTheme.dark()`.
- `AppSemanticColors` (`ThemeExtension`): `credit`, `debit`, `warning`.
  `Theme.of(context).extension<AppSemanticColors>()!`.
- `AppSpacing`: `xs` 4, `sm` 8, `md` 12, `lg` 16, `xl` 24, `xxl` 32.
- `AppRadius`: `field` 12, `button` 12, `card` 16.

## Entradas (pieza 2)

- `AppButton`: ancho completo, mínimo 48 dp. Con `isLoading` o
  `onPressed: null` queda deshabilitado; en carga anuncia "<etiqueta>,
  cargando".
- `AppButtonVariant`: `primary` (relleno), `secondary` (contorno), `text`.
- `AppTextField`: etiqueta siempre visible; con `obscure` incluye mostrar/
  ocultar contraseña (y desactiva sugerencias y autocorrección). El error lo
  anuncia el `InputDecorator` como región en vivo.
- `AppStepIndicator(current, total)`: segmentos más el texto "Paso N de M",
  anunciado como una sola etiqueta. `current` es base 1.

## Dinero y fechas (pieza 3)

- `formatCents(int cents, {currency = 'USD'})`: `$1,234.56`, `-$1.00`. Solo
  aritmética entera. Otras monedas muestran su código (`EUR 1.00`).
- `formatDateEs` (`14 may 2026`) y `formatDateTimeEs` (`14 may 2026, 09:30`),
  en hora local y 24 h. Meses: ene feb mar abr may jun jul ago sep oct nov dic.
- `spokenAmountEs(int cents)`: `50 dólares con 00 centavos`, `1 dólar con 00
  centavos`, `0 dólares con 01 centavo`; negativos con `menos`.
- `AmountText(cents, isCredit, style)`: `+$50.00` / `−$12.30` (U+2212), color
  de `AppSemanticColors` y etiqueta "Ingreso de ..." / "Egreso de ...". Recibe
  la magnitud: usa el valor absoluto de `cents`. Requiere `AppTheme`.

## Estados y errores (pieza 4)

- `LoadingView`, `EmptyView(message)`, `ErrorView(message, onRetry)` con botón
  "Reintentar", `OfflineBanner(onRetry)` (icono, texto y acción; región en
  vivo; requiere `AppTheme`).
- `EmptyView` y `ErrorView` están centradas cuando caben y hacen scroll si el
  alto o el texto no alcanzan (nunca desbordan). Necesitan alto acotado, como
  el cuerpo de un `Scaffold`; no colocarlas dentro de otro scroll sin altura.
- `messageForFailure(Failure)` (usa `core_errors`): `network`, `auth`,
  `rls_denied`, `insufficient_funds`; cualquier otro código, o ninguno, da
  "Algo salió mal. Inténtalo de nuevo.". Nunca muestra `failure.message`
  (puede ser técnico).

## Decisiones anotadas

- El texto de `OfflineBanner` no estaba fijado en el contrato: "Sin conexión.
  Algunos datos pueden no estar al día." y acción "Reintentar".

- Sin `intl`: el formato es manual para no añadir dependencias.
- El día no lleva cero a la izquierda (`5 mar 2026`); la hora sí (`07:05`).

- `AppButtonVariant` no tenía valores fijados en el contrato más allá de
  `primary`; se añadieron `secondary` y `text`.
- `AppButton` ocupa todo el ancho disponible; no usarlo dentro de un `Row` sin
  `Expanded`.

- El token `warning` no estaba en la tabla inicial. Valores elegidos con
  contraste AA sobre fondo y superficie: claro `#8A5A00`, oscuro `#F2C46D`.
- Tokens `outline` (bordes de campos, >= 3:1 contra el fondo) y
  `outlineVariant` (divisores) añadidos: claro `#7C8591` / `#E1E4E8`, oscuro
  `#6B7580` / `#2A3139`.
- Los nombres de las constantes de `AppSpacing` y `AppRadius` no estaban
  fijados en el contrato; son los de arriba.
- Etiqueta de campo siempre visible (`FloatingLabelBehavior.always`).
