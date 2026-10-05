import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/spending_summary.dart';
import '../personalization_strings.dart';
import '../spending_cubit.dart';

/// Resumen de gastos del mes. Es dueño de su [SpendingCubit]: lo crea con
/// [cubitFactory] y lo cierra al salir.
class SpendingSummaryBlock extends StatefulWidget {
  final SpendingCubit Function() cubitFactory;
  const SpendingSummaryBlock({super.key, required this.cubitFactory});

  @override
  State<SpendingSummaryBlock> createState() => _SpendingSummaryBlockState();
}

class _SpendingSummaryBlockState extends State<SpendingSummaryBlock> {
  late final SpendingCubit _cubit = widget.cubitFactory();

  @override
  void initState() {
    super.initState();
    _cubit.load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              PersonalizationStrings.spendingTitle,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            BlocBuilder<SpendingCubit, SpendingState>(
              bloc: _cubit,
              builder: (context, state) => switch (state.status) {
                SpendingStatus.loading => const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                SpendingStatus.empty => Text(
                  PersonalizationStrings.spendingEmpty,
                  style: theme.textTheme.bodyMedium,
                ),
                SpendingStatus.error => _ErrorRow(
                  message: state.message!,
                  onRetry: _cubit.load,
                ),
                SpendingStatus.loaded => _Summary(summary: state.summary!),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRow({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onRetry,
            child: const Text(PersonalizationStrings.spendingRetry),
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  final SpendingSummary summary;
  const _Summary({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = summary.changePercent;
    final category = summary.topCategory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label:
              '${PersonalizationStrings.spendingTitle}: '
              '${spokenAmountEs(summary.totalCents)}',
          excludeSemantics: true,
          child: Text(
            formatCents(summary.totalCents),
            style: theme.textTheme.headlineSmall,
          ),
        ),
        if (category != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            PersonalizationStrings.topCategory(
              category,
              formatCents(summary.topCategoryCents),
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ],
        if (percent != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  percent > 0
                      ? Icons.trending_up
                      : percent < 0
                      ? Icons.trending_down
                      : Icons.trending_flat,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  PersonalizationStrings.change(percent),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
