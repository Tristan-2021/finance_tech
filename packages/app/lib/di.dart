import 'package:core_network/core_network.dart';
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> setupDi() async {
  final config = SupabaseConfig.fromEnvironment();
  final client = await initSupabase(config);
  sl.registerSingleton<SupabaseClient>(client);
}
