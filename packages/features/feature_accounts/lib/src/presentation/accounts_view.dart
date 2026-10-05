import 'dart:async';

import 'package:core_network/core_network.dart';
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

/// Pantalla de cuentas. Recibe los Cubits (no usa GetIt) para probarse sola.
///
/// [networkStatus] muestra "Reintentando…" mientras `RetryClient` reintenta, y
/// [connectivity] refresca los datos cuando vuelve la red. Ambos son opcionales.
class AccountsView extends StatefulWidget {
  final AccountsCubit cubit;
  final MovementsCubitFactory movementsCubitFactory;
  final String greetingName;
  final String segment;
  final VoidCallback onSignOut;
  final NetworkStatusNotifier? networkStatus;
  final ConnectivityMonitor? connectivity;

  const AccountsView({
    super.key,
    required this.cubit,
    required this.movementsCubitFactory,
    required this.greetingName,
    required this.segment,
    required this.onSignOut,
    this.networkStatus,
    this.connectivity,
  });

  @override
  State<AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends State<AccountsView> {
  StreamSubscription<void>? _reconnect;

  @override
  void initState() {
    super.initState();
    _reconnect = widget.connectivity?.onReconnected.listen(
      (_) => widget.cubit.recover(),
    );
  }

  @override
  void dispose() {
    _reconnect?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              greetingName: widget.greetingName,
              segment: widget.segment,
              onSignOut: widget.onSignOut,
            ),
            if (widget.networkStatus case final status?)
              _RetryingBar(status: status),
            Expanded(
              child: BlocBuilder<AccountsCubit, AccountsState>(
                bloc: widget.cubit,
                builder: (context, state) => switch (state.status) {
                  AccountsStatus.loading => const LoadingView(),
                  AccountsStatus.error => ErrorView(
                    message: state.message!,
                    onRetry: widget.cubit.load,
                  ),
                  AccountsStatus.loaded =>
                    state.accounts.isEmpty
                        ? const EmptyView(message: AccountsStrings.noAccounts)
                        : _AccountBody(
                            // Cambiar de cuenta crea un Cubit de movimientos nuevo.
                            key: ValueKey(state.selected!.id),
                            state: state,
                            cubit: widget.cubit,
                            movementsCubitFactory: widget.movementsCubitFactory,
                            connectivity: widget.connectivity,
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

/// Indicador discreto mientras hay peticiones reintentándose.
class _RetryingBar extends StatelessWidget {
  final NetworkStatusNotifier status;

  const _RetryingBar({required this.status});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: status,
      builder: (context, _) {
        if (!status.isRetrying) return const SizedBox.shrink();
        return Semantics(
          liveRegion: true,
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LinearProgressIndicator(minHeight: 2),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  AccountsStrings.retrying,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Saldo y movimientos de la cuenta seleccionada, en un solo scroll con
/// pull-to-refresh y carga de la página siguiente al acercarse al final.
class _AccountBody extends StatefulWidget {
  final AccountsState state;
  final AccountsCubit cubit;
  final MovementsCubitFactory movementsCubitFactory;
  final ConnectivityMonitor? connectivity;

  const _AccountBody({
    super.key,
    required this.state,
    required this.cubit,
    required this.movementsCubitFactory,
    required this.connectivity,
  });

  @override
  State<_AccountBody> createState() => _AccountBodyState();
}

class _AccountBodyState extends State<_AccountBody> {
  late final MovementsCubit _movements = widget.movementsCubitFactory(
    widget.state.selected!.id,
  );
  final _scroll = ScrollController();
  StreamSubscription<void>? _reconnect;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _movements.loadFirst();
    _reconnect = widget.connectivity?.onReconnected.listen(
      (_) => _movements.recover(),
    );
  }

  @override
  void dispose() {
    _reconnect?.cancel();
    _scroll.dispose();
    _movements.close();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) {
      _movements.loadMore();
    }
  }

  /// La fecha más antigua de los datos guardados que se están mostrando.
  DateTime? _staleSince(MovementsState movements) {
    final dates = [
      widget.state.cachedAt,
      movements.cachedAt,
    ].whereType<DateTime>().toList()..sort();
    return dates.isEmpty ? null : dates.first;
  }

  void _retryStale() {
    widget.cubit.refresh();
    _movements.refresh();
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
      builder: (context, movements) {
        final staleSince = _staleSince(movements);
        return RefreshIndicator(
          onRefresh: () async {
            widget.cubit.refresh();
            await _movements.refresh();
          },
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
                      if (staleSince != null) ...[
                        _StaleNotice(cachedAt: staleSince, onRetry: _retryStale),
                        const SizedBox(height: AppSpacing.lg),
                      ],
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
        );
      },
    );
  }
}

/// Aviso de datos servidos desde la caché: ícono, texto con la fecha y acción
/// (nunca solo color). Requiere `AppTheme`.
class _StaleNotice extends StatelessWidget {
  final DateTime cachedAt;
  final VoidCallback onRetry;

  const _StaleNotice({required this.cachedAt, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warning = theme.extension<AppSemanticColors>()!.warning;

    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: warning),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: Icon(Icons.history, color: warning)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      AccountsStrings.staleNotice(formatDateTimeEs(cachedAt)),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onRetry,
                  child: const Text(AccountsStrings.retry),
                ),
              ),
            ],
          ),
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
