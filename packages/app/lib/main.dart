import 'package:core_api/core_api.dart';
import 'package:core_family/core_family.dart';
import 'package:core_shell/core_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'shell/feedback_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();
  final config = ApiConfig.fromEnvironment();
  final repository = ApiFamilyRepository(FingerBellApi(config));
  final family = FamilyCubit(repository)..start();
  final shell = ShellCubit(const ShellState(), MethodChannelPrefsStore());
  await shell.loadPrefs();
  runApp(
    FingerBellApp(
      family: family,
      shell: shell,
      feedback: DeviceFeedback(),
      serverAddress: config.toString(),
    ),
  );
}
