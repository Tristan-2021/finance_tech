import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../domain/transaction.dart';
import '../domain/transaction_type.dart';
import 'accounts_strings.dart';
import 'movements_cubit.dart';
import 'movements_state.dart';

const _stateHeight = 320.0;

SliverToBoxAdapter _fixed(Widget child) =>
    SliverToBoxAdapter(child: SizedBox(height: _stateHeight, child: child));

/// Slivers de la sección "Movimientos" según el estado. Los estados con
/// mensaje (`ErrorView`, `EmptyView`) van en una caja de alto acotado.
List<Widget> movementsSlivers({
  required MovementsState state,
  required MovementsCubit cubit,
  required String currency,
}) {
  final title = SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Builder(
        builder: (context) => Text(
          AccountsStrings.movementsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    ),
  );

  return switch (state.status) {
    MovementsStatus.loading => [title, _fixed(const LoadingView())],
    MovementsStatus.error => [
      title,
      _fixed(ErrorView(message: state.message!, onRetry: cubit.loadFirst)),
    ],
    MovementsStatus.loaded =>
      state.items.isEmpty
          ? [
              title,
              _fixed(const EmptyView(message: AccountsStrings.noMovements)),
            ]
          : [title, _list(state, cubit, currency)],
  };
}

Widget _list(MovementsState state, MovementsCubit cubit, String currency) {
  final hasFooter = state.loadingMore || state.loadMoreError != null;
  return SliverList.builder(
    itemCount: state.items.length + (hasFooter ? 1 : 0),
    itemBuilder: (context, i) {
      if (i < state.items.length) {
        return _MovementTile(transaction: state.items[i], currency: currency);
      }
      return _Footer(state: state, cubit: cubit);
    },
  );
}

class _MovementTile extends StatelessWidget {
  final Transaction transaction;
  final String currency;

  const _MovementTile({required this.transaction, required this.currency});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = transaction;
    final category = t.category;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.outlineVariant,
              foregroundColor: theme.colorScheme.onSurface,
              child: Icon(_iconFor(t), size: 20),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.description ?? category ?? AccountsStrings.movementFallback,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  '${category ?? AccountsStrings.uncategorized} · '
                  '${formatDateEs(t.createdAt)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AmountText(
                  cents: t.amountCents,
                  isCredit: t.type == TransactionType.credit,
                ),
                Text(
                  AccountsStrings.balanceAfter(
                    formatCents(t.balanceAfterCents, currency: currency),
                  ),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La categoría es texto libre: una desconocida cae en el icono del sentido.
IconData _iconFor(Transaction t) {
  return switch (t.category?.toLowerCase()) {
    'comida' => Icons.restaurant,
    'transporte' => Icons.directions_bus,
    'ocio' => Icons.movie_outlined,
    'servicios' => Icons.receipt_long,
    'ingreso' => Icons.south_west,
    _ =>
      t.type == TransactionType.credit ? Icons.south_west : Icons.north_east,
  };
}

class _Footer extends StatelessWidget {
  final MovementsState state;
  final MovementsCubit cubit;

  const _Footer({required this.state, required this.cubit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = state.loadMoreError;

    if (error == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: CircularProgressIndicator(
            semanticsLabel: AccountsStrings.loadingMore,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: AccountsStrings.retry,
            variant: AppButtonVariant.secondary,
            onPressed: () => cubit.loadMore(retry: true),
          ),
        ],
      ),
    );
  }
}
