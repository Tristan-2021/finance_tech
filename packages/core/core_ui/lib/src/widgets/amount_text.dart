import 'package:flutter/material.dart';

import '../format/money_format.dart';
import '../theme/app_semantic_colors.dart';

/// Monto con signo (`+$50.00` / `−$12.30`), color según sentido y etiqueta
/// hablada. Nunca depende solo del color. Requiere `AppTheme`.
class AmountText extends StatelessWidget {
  /// Magnitud en centavos; el sentido lo da [isCredit].
  final int cents;
  final bool isCredit;
  final TextStyle? style;

  const AmountText({
    super.key,
    required this.cents,
    required this.isCredit,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<AppSemanticColors>()!;
    final magnitude = cents.abs();
    final sign = isCredit ? '+' : '−';
    final spoken =
        '${isCredit ? 'Ingreso' : 'Egreso'} de ${spokenAmountEs(magnitude)}';
    final base = style ?? theme.textTheme.bodyMedium ?? const TextStyle();

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Text(
        '$sign${formatCents(magnitude)}',
        style: base.copyWith(color: isCredit ? colors.credit : colors.debit),
      ),
    );
  }
}
