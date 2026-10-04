import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, text }

/// Botón de ancho completo con área táctil mínima de 48 dp (del tema).
/// Con [isLoading] queda deshabilitado y muestra un indicador; con
/// `onPressed: null` queda deshabilitado.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final handler = (onPressed != null && !isLoading) ? onPressed : null;
    final child = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Text(label, textAlign: TextAlign.center);

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: handler,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: handler,
        child: child,
      ),
      AppButtonVariant.text => TextButton(onPressed: handler, child: child),
    };

    final sized = SizedBox(width: double.infinity, child: button);
    if (!isLoading) return sized;

    // Sin texto visible, el lector de pantalla sigue oyendo la etiqueta.
    return Semantics(
      button: true,
      enabled: false,
      label: '$label, cargando',
      excludeSemantics: true,
      child: sized,
    );
  }
}
