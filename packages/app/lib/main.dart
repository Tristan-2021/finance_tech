import 'package:core_network/core_network.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config_error_app.dart';
import 'di.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SupabaseConfig config;
  try {
    config = SupabaseConfig.fromEnvironment();
  } on StateError catch (e) {
    // Faltan los --dart-define: se explica en pantalla en lugar de crashear.
    runApp(ConfigErrorApp(message: e.message));
    return;
  }

  await setupDi(config);
  runApp(const BancoApp());
}
