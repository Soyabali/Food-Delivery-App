import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../widgets/adaptive_dialogs.dart';
import 'connectivity_service.dart';

bool _dialogOpen = false;

/// Call before an action that genuinely needs the internet (payment, social
/// sign-in). Returns `true` when the device is online; otherwise shows a single
/// explanatory dialog and returns `false`. Local navigation never calls this.
Future<bool> requireOnline(BuildContext context, {String? action}) async {
  final connectivity = context.read<ConnectivityService>();
  if (connectivity.isOnline) return true;
  if (_dialogOpen) return false;

  _dialogOpen = true;
  try {
    await showInfoDialog(
      context,
      title: 'No internet connection',
      message:
          '${action ?? 'This action'} needs an internet connection. '
          'Check your Wi-Fi or mobile data and try again.',
    );
  } finally {
    _dialogOpen = false;
  }
  return false;
}
