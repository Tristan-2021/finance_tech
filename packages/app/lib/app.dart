import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_telemetry/core_telemetry.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_strings.dart';
import 'debug/debug_panel.dart';
import 'di.dart';
import 'routes.dart';
import 'session_gate.dart';
import 'shell_telemetry.dart';
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
      // El panel de depuración solo existe en depuración: en release
      // `kDebugMode` es falso y esta rama se elimina al compilar.
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (kDebugMode && sl.isRegistered<DebugNetworkConfig>()) {
          return DebugPanelOverlay(
            config: sl<DebugNetworkConfig>(),
            ratesConfig:
                sl.isRegistered<DebugNetworkConfig>(
                  instanceName: ratesConfigName,
                )
                ? sl<DebugNetworkConfig>(instanceName: ratesConfigName)
                : null,
            telemetry: sl.isRegistered<Telemetry>() ? sl<Telemetry>() : null,
            cache: sl.isRegistered<CacheStore>() ? sl<CacheStore>() : null,
            child: content,
          );
        }
        return content;
      },
      navigatorObservers: [ScreenViewObserver()],
      initialRoute: AppRoutes.gate,
      routes: {
        AppRoutes.gate: (context) => SessionGate(
          getCurrentUser: sl<GetCurrentUser>(),
          onResolved: (hasUser) => Navigator.of(context).pushReplacementNamed(
            hasUser ? AppRoutes.welcome : AppRoutes.login,
          ),
        ),
        AppRoutes.login: (context) => LoginPage(
          onAuthenticated: () {
            trackEvent('login_success');
            Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
          },
          onGoToRegister: () =>
              Navigator.of(context).pushReplacementNamed(AppRoutes.register),
        ),
        AppRoutes.register: (context) => RegisterPage(
          onRegistered: () {
            trackEvent('register_completed');
            Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
          },
          onGoToLogin: () =>
              Navigator.of(context).pushReplacementNamed(AppRoutes.login),
        ),
        AppRoutes.welcome: (context) => WelcomePage(
          getCurrentUser: sl<GetCurrentUser>(),
          getUserProfile: sl<GetUserProfile>(),
          signOut: sl<SignOut>(),
          cache: sl.isRegistered<CacheStore>() ? sl<CacheStore>() : null,
          notifications: sl.isRegistered<NotificationsController>()
              ? sl<NotificationsController>()
              : null,
          onSignedOut: () => Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false),
        ),
      },
    );
  }
}
