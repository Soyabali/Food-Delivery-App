import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../core/auth/auth_state.dart';
import '../core/config/app_config.dart';
import '../data/mock_backend/mock_seed_data.dart';
import '../services/auth_service.dart';

/// UI-facing authentication state. Delegates to [AuthService]; converts
/// [ApiException]s into [AuthResult]s the screens already understand.
class AuthController extends ChangeNotifier {
  AuthController(this._service, this._config);

  final AuthService _service;
  final AppConfig _config;

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;

  AuthStatus get status => _status;
  AuthUser? get currentUser => _user;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Login is prefilled with the seeded demo account in mock mode only.
  ({String email, String password})? get demoCredentials => _config.isMockBackend
      ? (email: MockSeedData.demoEmail, password: MockSeedData.demoPassword)
      : null;

  bool get isDemoMode => _config.isMockBackend;

  void _set(AuthStatus status, AuthUser? user) {
    _status = status;
    _user = user;
    notifyListeners();
  }

  /// Splash-screen check. Throws [ApiException] when the session can't be
  /// verified (e.g. offline) so the splash can offer a retry.
  Future<void> restoreSession() async {
    if (_status != AuthStatus.unknown) return;
    final user = await _service.restoreSession();
    _set(
      user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated,
      user,
    );
  }

  Future<AuthResult> _run(Future<AuthUser> Function() action, [String? ok]) async {
    try {
      _set(AuthStatus.authenticated, await action());
      return AuthResult.success(ok);
    } catch (e) {
      return AuthResult.failure(toApiException(e).message);
    }
  }

  Future<AuthResult> login({required String email, required String password}) =>
      _run(() => _service.login(email: email, password: password));

  Future<AuthResult> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) =>
      _run(
        () => _service.register(
          name: name,
          email: email,
          phone: phone,
          password: password,
        ),
      );

  /// SIMULATED: no Google/Apple SDK is integrated. In mock mode this signs
  /// in the demo account; with a real backend it reports "not configured".
  Future<AuthResult> socialLogin(String provider) async {
    final demo = demoCredentials;
    if (demo == null) {
      return AuthResult.failure('$provider sign-in is not configured yet.');
    }
    return _run(
      () => _service.login(email: demo.email, password: demo.password),
      'Signed in with $provider (demo account)',
    );
  }

  Future<AuthResult> requestPasswordReset(String email) async {
    try {
      await _service.requestPasswordReset(email);
      return const AuthResult.success();
    } catch (e) {
      return AuthResult.failure(toApiException(e).message);
    }
  }

  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _service.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return const AuthResult.success();
    } catch (e) {
      final error = toApiException(e);
      if (error.type == ApiErrorType.unauthorized) await expireSession();
      return AuthResult.failure(error.message);
    }
  }

  Future<void> logout() async {
    await _service.logout();
    _set(AuthStatus.unauthenticated, null);
  }

  /// Called when any request returns 401: drop the session so the router
  /// sends the user to login.
  Future<void> expireSession() async {
    if (_status != AuthStatus.authenticated) return;
    await _service.logout();
    _set(AuthStatus.unauthenticated, null);
  }
}
