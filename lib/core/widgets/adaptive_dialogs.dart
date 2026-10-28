import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

bool _isCupertino(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

/// Platform-adaptive yes/no dialog. Resolves to `true` only when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showAdaptiveDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      Widget action(String label, bool value, {bool isDestructive = false}) {
        void onPressed() => Navigator.of(dialogContext).pop(value);
        if (_isCupertino(dialogContext)) {
          return CupertinoDialogAction(
            onPressed: onPressed,
            isDestructiveAction: isDestructive,
            isDefaultAction: !value,
            child: Text(label),
          );
        }
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: isDestructive
                ? AppColors.secondary
                : AppColors.primaryContainer,
          ),
          child: Text(label),
        );
      }

      return AlertDialog.adaptive(
        title: Text(title),
        content: Text(message),
        actions: [
          action(cancelLabel, false),
          action(confirmLabel, true, isDestructive: destructive),
        ],
      );
    },
  );
  return result ?? false;
}

/// Platform-adaptive dialog with a single acknowledgement button.
Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  String buttonLabel = 'OK',
}) {
  return showAdaptiveDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(message),
      actions: [
        if (_isCupertino(dialogContext))
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(buttonLabel),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(buttonLabel),
          ),
      ],
    ),
  );
}

void showAppSnackBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
}
