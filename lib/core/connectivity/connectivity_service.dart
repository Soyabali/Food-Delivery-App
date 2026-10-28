import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device has a network interface.
///
/// Note: being "online" here only means a network is attached. It does not
/// prove that any particular server is reachable.
class ConnectivityService extends ChangeNotifier {
  /// Pass [changes] and [check] to fake connectivity in tests; otherwise the
  /// connectivity_plus plugin is used.
  ConnectivityService({
    Stream<List<ConnectivityResult>>? changes,
    Future<List<ConnectivityResult>> Function()? check,
  })  : _changes = changes, // ignore: prefer_initializing_formals
        _check = check; // ignore: prefer_initializing_formals

  final Stream<List<ConnectivityResult>>? _changes;
  final Future<List<ConnectivityResult>> Function()? _check;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Future<void> init() async {
    final connectivity =
        (_changes == null || _check == null) ? Connectivity() : null;
    try {
      _update(await (_check ?? connectivity!.checkConnectivity)());
      _subscription = (_changes ?? connectivity!.onConnectivityChanged)
          .listen(_update, onError: (_) {});
    } catch (e) {
      // Plugin unavailable (e.g. unsupported platform): assume online so
      // the app stays usable.
      debugPrint('Connectivity monitoring unavailable: $e');
    }
  }

  void _update(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online == _isOnline) return;
    _isOnline = online;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
