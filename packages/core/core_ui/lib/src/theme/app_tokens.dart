import 'package:flutter/material.dart';

/// Tokens de color de cada modo. Interno: el resto del código usa `AppTheme`.
class AppTokens {
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color primary;
  final Color onPrimary;
  final Color text;
  final Color textSecondary;
  final Color credit;
  final Color debit;
  final Color warning;
  final Color error;
  final Color onError;

  /// Bordes de controles (contraste >= 3:1 contra el fondo).
  final Color outline;

  /// Divisores sutiles.
  final Color outlineVariant;

  const AppTokens({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.text,
    required this.textSecondary,
    required this.credit,
    required this.debit,
    required this.warning,
    required this.error,
    required this.onError,
    required this.outline,
    required this.outlineVariant,
  });

  static const light = AppTokens(
    brightness: Brightness.light,
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF0B57D0),
    onPrimary: Color(0xFFFFFFFF),
    text: Color(0xFF1B1F24),
    textSecondary: Color(0xFF5B6470),
    credit: Color(0xFF1B7F4B),
    debit: Color(0xFFB3261E),
    warning: Color(0xFF8A5A00),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    outline: Color(0xFF7C8591),
    outlineVariant: Color(0xFFE1E4E8),
  );

  static const dark = AppTokens(
    brightness: Brightness.dark,
    background: Color(0xFF0F1318),
    surface: Color(0xFF171C22),
    primary: Color(0xFF8AB4F8),
    onPrimary: Color(0xFF0B1A33),
    text: Color(0xFFE6E8EB),
    textSecondary: Color(0xFFA3ADB8),
    credit: Color(0xFF6FD39A),
    debit: Color(0xFFF2A19B),
    warning: Color(0xFFF2C46D),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    outline: Color(0xFF6B7580),
    outlineVariant: Color(0xFF2A3139),
  );
}
