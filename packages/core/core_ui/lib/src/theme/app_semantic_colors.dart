import 'package:flutter/material.dart';

/// Colores con significado financiero. Acceso:
/// `Theme.of(context).extension<AppSemanticColors>()!`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color credit;
  final Color debit;
  final Color warning;

  const AppSemanticColors({
    required this.credit,
    required this.debit,
    required this.warning,
  });

  @override
  AppSemanticColors copyWith({Color? credit, Color? debit, Color? warning}) {
    return AppSemanticColors(
      credit: credit ?? this.credit,
      debit: debit ?? this.debit,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      credit: Color.lerp(credit, other.credit, t)!,
      debit: Color.lerp(debit, other.debit, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSemanticColors &&
      other.credit == credit &&
      other.debit == debit &&
      other.warning == warning;

  @override
  int get hashCode => Object.hash(credit, debit, warning);
}
