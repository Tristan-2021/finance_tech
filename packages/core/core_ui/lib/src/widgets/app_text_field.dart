import 'package:flutter/material.dart';

/// Campo de texto con etiqueta siempre visible. Con `obscure: true` incluye el
/// botón mostrar/ocultar. El `errorText` lo anuncia el lector de pantalla
/// (región en vivo del `InputDecorator`).
class AppTextField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.errorText,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: widget.obscure && _hidden,
      enableSuggestions: !widget.obscure,
      autocorrect: !widget.obscure,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Mostrar contraseña' : 'Ocultar contraseña',
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: widget.enabled
                    ? () => setState(() => _hidden = !_hidden)
                    : null,
              )
            : null,
      ),
    );
  }
}
