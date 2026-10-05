import 'package:core_errors/core_errors.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_telemetry/core_telemetry.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'app_strings.dart';
import 'home_shell.dart';
import 'shell_telemetry.dart';

/// Ruta de entrada tras autenticarse. Lee el perfil (feature_onboarding) y,
/// con el nombre y el segmento, muestra las pestañas Inicio y Cuenta: el shell
/// es el único que conoce a los features.
///
/// Si hay [cache], antes de cargar nada la asocia al usuario actual (descarta
/// la de otro usuario) y la limpia al cerrar sesión.
///
/// Si hay [notifications], tras cargar el perfil muestra el pre-aviso
/// ([prePrompt]) y, si el usuario acepta, las inicia; al cerrar sesión las
/// detiene **antes** de cerrar la sesión.
///
/// Mientras llega el perfil, o si falla, ofrece carga, reintento y cierre de
/// sesión.
class WelcomePage extends StatefulWidget {
  final GetCurrentUser getCurrentUser;
  final GetUserProfile getUserProfile;
  final SignOut signOut;
  final CacheStore? cache;
  final NotificationsController? notifications;
  final Future<bool> Function(BuildContext context) prePrompt;
  final VoidCallback onSignedOut;

  const WelcomePage({
    super.key,
    required this.getCurrentUser,
    required this.getUserProfile,
    required this.signOut,
    required this.onSignedOut,
    this.cache,
    this.notifications,
    this.prePrompt = showNotificationsPrePrompt,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _loading = true;
  UserProfile? _profile;
  String? _loadError;

  bool _signingOut = false;
  String? _signOutError;

  final _shell = ShellNavigator();
  bool _notificationsAsked = false;
  bool _notificationsStarted = false;

  @override
  void initState() {
    super.initState();
    _shell.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _shell.dispose();
    super.dispose();
  }

  void _onTabChanged() => trackEvent('screen_viewed', {
    'screen': _shell.tab == ShellTab.home ? 'home' : 'accounts',
  });

  /// La caché se asocia al usuario ANTES de pedir datos: así nada se guarda ni
  /// se sirve bajo otro dueño.
  Future<void> _bindCache() async {
    final cache = widget.cache;
    if (cache == null) return;
    final user = widget.getCurrentUser();
    if (user == null) return;
    try {
      await cache.bindOwner(user.id);
    } catch (_) {
      // Sin caché la app sigue funcionando.
    }
  }

  Future<void> _load() async {
    await _bindCache();
    final result = await widget.getUserProfile();
    if (!mounted) return;
    final profile = result.profile;
    if (profile != null) {
      if (GetIt.instance.isRegistered<Telemetry>()) {
        GetIt.instance<Telemetry>().setSegment(profile.segment);
      }
      trackEvent('screen_viewed', {'screen': 'home'});
      // El pre-aviso es un diálogo: se muestra con la pantalla ya dibujada.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startNotifications(),
      );
    }
    setState(() {
      _loading = false;
      _profile = profile;
      _loadError = profile != null
          ? null
          : messageForFailure(result.failure ?? const Failure('', 'unknown'));
    });
  }

  /// Una vez por sesión: pre-aviso y, si acepta, permiso y registro del token.
  Future<void> _startNotifications() async {
    final notifications = widget.notifications;
    if (notifications == null || _notificationsAsked || !mounted) return;
    _notificationsAsked = true;
    final accepted = await widget.prePrompt(context);
    if (!accepted || !mounted) return;
    _notificationsStarted = true;
    await notifications.start(onOpenAccounts: _shell.openAccounts);
  }

  void _retry() {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _load();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() {
      _signingOut = true;
      _signOutError = null;
    });

    // Antes de cerrar la sesión: el token del dispositivo se borra del backend
    // mientras la sesión sigue válida, para que el siguiente usuario del mismo
    // teléfono no reciba los avisos de este. Un fallo aquí no impide salir.
    final wasStarted = _notificationsStarted;
    _notificationsStarted = false;
    try {
      await widget.notifications?.stop();
    } catch (_) {}

    final failure = await widget.signOut();
    if (!mounted) return;
    if (failure != null) {
      final message = messageForFailure(failure);
      setState(() {
        _signingOut = false;
        _signOutError = message;
      });
      if (_profile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      // Sigue con la sesión abierta: se vuelven a activar los avisos.
      if (wasStarted) {
        _notificationsStarted = true;
        widget.notifications?.start(onOpenAccounts: _shell.openAccounts);
      }
      return;
    }
    trackEvent('sign_out');
    try {
      await widget.cache?.clear();
    } catch (_) {
      // Cerrar sesión no debe fallar por la caché.
    }
    if (!mounted) return;
    widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile != null) {
      return HomeShell(
        navigator: _shell,
        homeBuilder: (_) =>
            HomeTab(name: profile.fullName, segment: profile.segment),
        accountsBuilder: (_) => AccountsPage(
          greetingName: profile.fullName,
          segment: profile.segment,
          onSignOut: _signOut,
        ),
      );
    }

    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : ErrorView(message: _loadError!, onRetry: _retry),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_signOutError != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _signOutError!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AppButton(
                        label: AppStrings.signOutAction,
                        variant: AppButtonVariant.secondary,
                        isLoading: _signingOut,
                        onPressed: _signOut,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
