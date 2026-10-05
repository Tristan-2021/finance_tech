import 'package:core_network/core_network.dart';
import 'package:feature_onboarding/feature_onboarding.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

/// Inicializa Supabase y registra las dependencias. [config] sale de los
/// `--dart-define` (`SupabaseConfig.fromEnvironment`).
Future<void> setupDi(SupabaseConfig config) async {
  final client = await initSupabase(config);
  registerDependencies(client);
}

/// Raíz de composición. Separada de [setupDi] para poder probarla sin red:
/// los tests registran un cliente de mentira y reemplazan los casos de uso.
void registerDependencies(SupabaseClient client) {
  sl.registerSingleton<SupabaseClient>(client);
  registerOnboardingDependencies(sl);
}
