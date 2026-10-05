import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/account.dart';
import 'accounts_cubit.dart';
import 'accounts_state.dart';
import 'accounts_strings.dart';
import 'movements_cubit.dart';
import 'movements_slivers.dart';
import 'movements_state.dart';

/// Pantalla de cuentas. Recibe el Cubit y la fábrica de movimientos (no usa
/// GetIt) para probarse sola.
class AccountsView extends StatelessWidget {
  final AccountsCubit cubit;
  final MovementsCubitFactory movementsCubitFactory;
  final String greetingName;
  final String segment;
  final VoidCallback onSignOut;

  const AccountsView({
    super.key,
    required this.cubit,
    required this.movementsCubitFactory,
    required this.greetingName,
    required this.segment,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              greetingName: greetingName,
              segment: segment,
              onSignOut: onSignOut,
            ),
            Expanded(
              child: BlocBuilder<AccountsCubit, AccountsState>(
                bloc: cubit,
                builder: (context, state) => switch (state.status) {
                  AccountsStatus.loading => const LoadingView(),
                  AccountsStatus.error => ErrorView(
                    message: state.message!,
                    onRetry: cubit.load,
                  ),
                  AccountsStatus.loaded =>
                    state.accounts.isEmpty
                        ? const EmptyView(message: AccountsStrings.noAccounts)
                        : _AccountBody(
                            // Cambiar de cuenta crea un Cubit de movimientos nuevo.
                            key: ValueKey(state.selected!.id),
                            state: state,
                            cubit: cubit,
                            movementsCubitFactory: movementsCubitFactory,
                          ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MenuAction { signOut }

class _Header extends StatelessWidget {
  final String greetingName;
  final String segment;
  final VoidCallback onSignOut;

  const _Header({
    required this.greetingName,
    required this.segment,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AccountsStrings.greeting(greetingName),
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Chip(
                  label: Text(AccountsStrings.segmentLabel(segment)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          PopupMenuButton<_MenuAction>(
            tooltip: AccountsStrings.menu,
            onSelected: (_) => onSignOut(),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _MenuAction.signOut,
                child: Text(AccountsStrings.signOut),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Saldo y movimientos de la cuenta seleccionada, en un solo scroll con
/// pull-to-refresh y carga de la página siguiente al acercarse al final.
class _AccountBody extends StatefulWidget {
  final AccountsState state;
  final AccountsCubit cubit;
  final MovementsCubitFactory movementsCubitFactory;

  const _AccountBody({
    super.key,
    required this.state,
    required this.cubit,
    required this.movementsCubitFactory,
  });

  @override
  State<_AccountBody> createState() => _AccountBodyState();
}

class _AccountBodyState extends State<_AccountBody> {
  late final MovementsCubit _movements = widget.movementsCubitFactory(
    widget.state.selected!.id,
  );
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _movements.loadFirst();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _movements.close();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) {
      _movements.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final account = state.selected!;

    return BlocConsumer<MovementsCubit, MovementsState>(
      bloc: _movements,
      listenWhen: (previous, current) =>
          current.refreshError != null ||
          current.items.length != previous.items.length,
      listener: (context, movements) {
        final refreshError = movements.refreshError;
        if (refreshError != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(refreshError)));
          return;
        }
        // Si la primera página no llena la pantalla, no habría scroll que
        // dispare la siguiente: se pide una vez dibujada la lista.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _scroll.hasClients &&
              _scroll.position.maxScrollExtent <= 0) {
            _movements.loadMore();
          }
        });
      },
      builder: (context, movements) => RefreshIndicator(
        onRefresh: _movements.refresh,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.accounts.length > 1) ...[
                      _AccountSelector(state: state, cubit: widget.cubit),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    _BalanceCard(account: account),
                  ],
                ),
              ),
            ),
            ...movementsSlivers(
              state: movements,
              cubit: _movements,
              currency: account.currency,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        ),
      ),
    );
  }
}

class _AccountSelector extends StatelessWidget {
  final AccountsState state;
  final AccountsCubit cubit;

  const _AccountSelector({required this.state, required this.cubit});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.accounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) => ChoiceChip(
          label: Text(state.accounts[i].name),
          selected: i == state.selectedIndex,
          onSelected: (_) => cubit.selectAccount(i),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final Account account;

  const _BalanceCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(account.name, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            Text(AccountsStrings.balanceLabel, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              label:
                  '${AccountsStrings.balanceLabel}: '
                  '${spokenAmountEs(account.balanceCents)}',
              excludeSemantics: true,
              child: Text(
                formatCents(account.balanceCents, currency: account.currency),
                style: theme.textTheme.displaySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
