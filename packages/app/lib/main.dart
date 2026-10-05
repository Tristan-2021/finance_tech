import 'package:core_network/core_network.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config_error_app.dart';
import 'di.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();

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

/// Firebase es una mejora (monitoreo, personalización), no un requisito: si no
/// se puede inicializar (plataforma sin configurar, sin servicios de Google…),
/// la app arranca igual.
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // La app funciona sin Firebase.
  }
}
