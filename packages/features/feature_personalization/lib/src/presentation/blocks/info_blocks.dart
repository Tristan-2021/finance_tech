import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../domain/home_block.dart';
import '../personalization_strings.dart';

/// Consejo: ícono + texto. Sin `text` no se dibuja nada.
class TipBlock extends StatelessWidget {
  final HomeBlock block;
  const TipBlock({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    final text = block.stringParam('text');
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.lightbulb_outline,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

/// Promoción informativa: título y cuerpo. Sin `title` no se dibuja nada.
class PromoBlock extends StatelessWidget {
  final HomeBlock block;
  const PromoBlock({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    final title = block.stringParam('title');
    if (title == null || title.isEmpty) return const SizedBox.shrink();
    final body = block.stringParam('body');
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Semantics(
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.local_offer_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
              if (body != null && body.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tipo de cambio de referencia publicado en la propia configuración
/// (`pair` y `rate` como texto): no hay fuente en vivo, y así se indica.
class ExchangeRateBlock extends StatelessWidget {
  final HomeBlock block;
  const ExchangeRateBlock({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    final pair = block.stringParam('pair') ?? 'USD/EUR';
    final rate = block.stringParam('rate');
    if (rate == null || rate.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Semantics(
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                PersonalizationStrings.rateTitle,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('$pair  $rate', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                PersonalizationStrings.rateNote,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
