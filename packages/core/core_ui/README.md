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

## Decisiones anotadas

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
