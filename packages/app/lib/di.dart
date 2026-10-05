import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_exchange/feature_exchange.dart';
import 'package:feature_notifications/feature_notifications.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:feature_personalization/feature_personalization.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

final sl = GetIt.instance;

/// Nombre bajo el que se registra el `DebugNetworkConfig` del servicio de tasas
/// (el de Supabase va sin nombre).
const ratesConfigName = 'rates';

/// Inicializa Supabase y registra las dependencias. [config] sale de los
/// `--dart-define` (`SupabaseConfig.fromEnvironment`).
///
/// Supabase y el servicio de tasas usan **dos clientes HTTP independientes**,
/// cada uno con su propia configuración de fallos: así se puede apagar un
/// servicio y comprobar que el otro sigue funcionando. La inyección de fallos
/// solo existe en depuración: en release no se crea ningún
/// `DebugNetworkConfig` ni `FaultInjectingClient`.
Future<void> setupDi(SupabaseConfig config) async {
  final networkStatus = NetworkStatusNotifier();

  DebugNetworkConfig? debugConfig;
  DebugNetworkConfig? ratesDebugConfig;
  http.Client? innerClient;
  http.Client ratesClient = http.Client();
  if (kDebugMode) {
    debugConfig = DebugNetworkConfig();
    innerClient = FaultInjectingClient(http.Client(), debugConfig);
    ratesDebugConfig = DebugNetworkConfig();
    ratesClient = FaultInjectingClient(http.Client(), ratesDebugConfig);
  }

  final client = await initSupabase(
    config,
    innerClient: innerClient,
    status: networkStatus,
  );

  // Sin caché la app sigue funcionando: solo pierde el modo sin conexión.
  CacheStore? cache;
  try {
    cache = await HiveCacheStore.open(
      keyProvider: EncryptionKeyProvider(FlutterSecretStore()),
    );
  } catch (_) {
    cache = null;
  }

  registerDependencies(
    client,
    cache: cache,
    networkStatus: networkStatus,
    connectivity: ConnectivityMonitor(),
    debugConfig: debugConfig,
    ratesHttpClient: ratesClient,
    ratesDebugConfig: ratesDebugConfig,
  );
}

/// Raíz de composición. Separada de [setupDi] para poder probarla sin red:
/// los tests registran un cliente de mentira y reemplazan los casos de uso.
///
/// La caché, el estado de red, la conectividad y el panel de depuración son
/// opcionales: los features los usan solo si están registrados.
/// [ratesHttpClient] es el cliente del servicio de tasas (por defecto, uno
/// normal).
void registerDependencies(
  SupabaseClient client, {
  CacheStore? cache,
  NetworkStatusNotifier? networkStatus,
  ConnectivityMonitor? connectivity,
  DebugNetworkConfig? debugConfig,
  http.Client? ratesHttpClient,
  DebugNetworkConfig? ratesDebugConfig,
}) {
  sl.registerSingleton<SupabaseClient>(client);
  if (cache != null) sl.registerSingleton<CacheStore>(cache);
  if (networkStatus != null) {
    sl.registerSingleton<NetworkStatusNotifier>(networkStatus);
  }
  if (connectivity != null) {
    sl.registerSingleton<ConnectivityMonitor>(connectivity);
  }
  if (debugConfig != null) {
    sl.registerSingleton<DebugNetworkConfig>(debugConfig);
  }
  if (ratesDebugConfig != null) {
    sl.registerSingleton<DebugNetworkConfig>(
      ratesDebugConfig,
      instanceName: ratesConfigName,
    );
  }
  registerOnboardingDependencies(sl);
  registerAccountsDependencies(sl);
  registerPersonalizationDependencies(sl);
  registerExchangeDependencies(sl, httpClient: ratesHttpClient ?? http.Client());
  registerNotificationsDependencies(sl);
}
