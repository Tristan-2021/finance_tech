import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// Indicador de pasos. [current] es base 1. Muestra segmentos y el texto
/// "Paso N de M" (nunca solo color) y lo anuncia como una sola etiqueta.
class AppStepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const AppStepIndicator({
    super.key,
    required this.current,
    required this.total,
  }) : assert(total > 0, 'total debe ser > 0'),
       assert(current >= 1 && current <= total, 'current debe estar en 1..total');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = 'Paso $current de $total';

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var i = 1; i <= total; i++) ...[
                if (i > 1) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: DecoratedBox(
                    key: ValueKey('step-segment-$i'),
                    decoration: BoxDecoration(
                      color: i <= current
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                    child: const SizedBox(height: 4),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
