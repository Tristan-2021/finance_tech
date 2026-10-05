import 'package:core_ui/core_ui.dart';
import 'package:feature_exchange/feature_exchange.dart';
import 'package:feature_personalization/feature_personalization.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'app_strings.dart';

enum ShellTab { home, accounts }

/// Estado de la navegación por pestañas. Lo comparten el shell y quien necesite
/// moverlo (p. ej. el toque de una notificación).
class ShellNavigator extends ChangeNotifier {
  ShellTab _tab = ShellTab.home;
  int _accountsVersion = 0;

  ShellTab get tab => _tab;

  /// Cambia cada vez que la pestaña Cuenta debe recargar sus datos.
  int get accountsVersion => _accountsVersion;

  void select(ShellTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }

  /// Va a la pestaña Cuenta y fuerza que recargue el saldo y los movimientos.
  void openAccounts() {
    _tab = ShellTab.accounts;
    _accountsVersion++;
    notifyListeners();
  }
}

/// Barra inferior con dos pestañas: Inicio y Cuenta. Ambas siguen montadas
/// (`IndexedStack`), así que cambiar de pestaña conserva su estado.
class HomeShell extends StatelessWidget {
  final ShellNavigator navigator;
  final WidgetBuilder homeBuilder;
  final WidgetBuilder accountsBuilder;

  const HomeShell({
    super.key,
    required this.navigator,
    required this.homeBuilder,
    required this.accountsBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: navigator,
      builder: (context, _) => Scaffold(
        body: IndexedStack(
          index: navigator.tab.index,
          children: [
            homeBuilder(context),
            KeyedSubtree(
              key: ValueKey(navigator.accountsVersion),
              child: accountsBuilder(context),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigator.tab.index,
          onDestinationSelected: (i) => navigator.select(ShellTab.values[i]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: AppStrings.tabHome,
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: AppStrings.tabAccount,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pestaña Inicio: saludo y los bloques personalizados del segmento. El tipo
/// `exchange_rate` se dibuja con el conversor de `feature_exchange`: solo el
/// shell conoce a los dos features.
class HomeTab extends StatelessWidget {
  final String name;
  final String segment;

  const HomeTab({super.key, required this.name, required this.segment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final personalization = GetIt.instance.isRegistered<HomeCubit>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(AppStrings.greeting(name), style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            if (personalization)
              PersonalizedHome(
                segment: segment,
                blockOverrides: {
                  BlockType.exchangeRate: (_, _) => const ExchangeCard(),
                },
              ),
          ],
        ),
      ),
    );
  }
}
