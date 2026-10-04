import 'package:flutter/material.dart';

import 'app_radius.dart';
import 'app_semantic_colors.dart';
import 'app_spacing.dart';
import 'app_tokens.dart';

/// Tema Material 3 generado desde [AppTokens]. Fuentes del sistema.
abstract final class AppTheme {
  static ThemeData light() => _build(AppTokens.light);
  static ThemeData dark() => _build(AppTokens.dark);

  static ThemeData _build(AppTokens t) {
    final scheme = ColorScheme(
      brightness: t.brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      secondary: t.primary,
      onSecondary: t.onPrimary,
      error: t.error,
      onError: t.onError,
      surface: t.surface,
      onSurface: t.text,
      onSurfaceVariant: t.textSecondary,
      outline: t.outline,
      outlineVariant: t.outlineVariant,
      surfaceTint: Colors.transparent,
    );
    final textTheme = _textTheme(t);

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
    );
    const buttonMinSize = Size(64, 48);

    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.background,
      textTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [
        AppSemanticColors(
          credit: t.credit,
          debit: t.debit,
          warning: t.warning,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        foregroundColor: t.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: t.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        // Etiqueta siempre visible, nunca solo un placeholder.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: t.textSecondary),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: t.textSecondary,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: t.error),
        border: border(t.outline),
        enabledBorder: border(t.outline),
        focusedBorder: border(t.primary, 2),
        errorBorder: border(t.error),
        focusedErrorBorder: border(t.error, 2),
        disabledBorder: border(t.outlineVariant),
      ),
    );
  }

  /// Saldo 36 (semibold), título 22, cuerpo 16, detalle 13.
  static TextTheme _textTheme(AppTokens t) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: t.text,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: t.text,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: t.text,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.4, color: t.text),
      bodyMedium: TextStyle(fontSize: 16, height: 1.4, color: t.text),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, color: t.textSecondary),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: t.text,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: t.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: 13,
        height: 1.3,
        color: t.textSecondary,
      ),
    );
  }
}
