import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'app_strings.dart';

/// Se muestra en lugar de la app cuando faltan los `--dart-define`.
class ConfigErrorApp extends StatelessWidget {
  final String message;

  const ConfigErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.configErrorTitle,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SelectableText(
                          message,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
