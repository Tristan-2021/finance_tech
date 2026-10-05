import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'notifications_strings.dart';

/// Diálogo previo al permiso del sistema. Devuelve `true` si el usuario acepta;
/// cerrarlo o rechazar devuelve `false` y el shell no debe pedir el permiso.
Future<bool> showNotificationsPrePrompt(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(NotificationsStrings.prePromptTitle),
      content: const Text(NotificationsStrings.prePromptMessage),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: NotificationsStrings.accept,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: NotificationsStrings.decline,
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ],
    ),
  );
  return accepted ?? false;
}
