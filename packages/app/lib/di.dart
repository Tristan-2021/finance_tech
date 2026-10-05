import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:feature_accounts/feature_accounts.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

final sl = GetIt.instance;

/// Inicializa Supabase y registra las dependencias. [config] sale de los
/// `--dart-define` (`SupabaseConfig.fromEnvironment`).
///
/// La inyección de fallos solo existe en depuración: en release no se crea el
/// `DebugNetworkConfig` ni el `FaultInjectingClient`.
Future<void> setupDi(SupabaseConfig config) async {
  final networkStatus = NetworkStatusNotifier();

  DebugNetworkConfig? debugConfig;
  http.Client? innerClient;
  if (kDebugMode) {
    debugConfig = DebugNetworkConfig();
    innerClient = FaultInjectingClient(http.Client(), debugConfig);
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
  );
}

/// Raíz de composición. Separada de [setupDi] para poder probarla sin red:
/// los tests registran un cliente de mentira y reemplazan los casos de uso.
///
/// La caché, el estado de red, la conectividad y el panel de depuración son
/// opcionales: los features los usan solo si están registrados.
void registerDependencies(
  SupabaseClient client, {
  CacheStore? cache,
  NetworkStatusNotifier? networkStatus,
  ConnectivityMonitor? connectivity,
  DebugNetworkConfig? debugConfig,
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
  registerOnboardingDependencies(sl);
  registerAccountsDependencies(sl);
}
