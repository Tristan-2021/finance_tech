import 'package:core_ui/core_ui.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_strings.dart';
import 'di.dart';
import 'routes.dart';
import 'session_gate.dart';
import 'welcome_page.dart';

/// El shell es el único lugar que conoce a varios features: aquí se conectan
/// las pantallas por callbacks y rutas.
class BancoApp extends StatelessWidget {
  const BancoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      initialRoute: AppRoutes.gate,
      routes: {
        AppRoutes.gate: (context) => SessionGate(
          getCurrentUser: sl<GetCurrentUser>(),
          onResolved: (hasUser) => Navigator.of(context).pushReplacementNamed(
            hasUser ? AppRoutes.welcome : AppRoutes.login,
          ),
        ),
        AppRoutes.login: (context) => LoginPage(
          onAuthenticated: () =>
              Navigator.of(context).pushReplacementNamed(AppRoutes.welcome),
          // El registro se conecta en la siguiente pieza.
          onGoToRegister: () {},
        ),
        AppRoutes.welcome: (context) => WelcomePage(
          signOut: sl<SignOut>(),
          onSignedOut: () => Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false),
        ),
      },
    );
  }
}
