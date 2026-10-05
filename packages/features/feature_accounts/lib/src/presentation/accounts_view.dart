import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/account.dart';
import 'accounts_cubit.dart';
import 'accounts_state.dart';
import 'accounts_strings.dart';

/// Pantalla de cuentas. Recibe el Cubit (no usa GetIt) para probarse sola.
class AccountsView extends StatelessWidget {
  final AccountsCubit cubit;
  final String greetingName;
  final String segment;
  final VoidCallback onSignOut;

  const AccountsView({
    super.key,
    required this.cubit,
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
                        : _Loaded(state: state, cubit: cubit),
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

class _Loaded extends StatelessWidget {
  final AccountsState state;
  final AccountsCubit cubit;

  const _Loaded({required this.state, required this.cubit});

  @override
  Widget build(BuildContext context) {
    final account = state.selected!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (state.accounts.length > 1) ...[
          _AccountSelector(state: state, cubit: cubit),
          const SizedBox(height: AppSpacing.lg),
        ],
        _BalanceCard(account: account),
      ],
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
