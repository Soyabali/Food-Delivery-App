import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/api/endpoints.dart';
import '../core/auth/auth_state.dart';
import 'session_store.dart';

/// Login, registration, session restore and password operations.
/// Talks to `BackendEndpoints` through [ApiClient] (mock or real).
class AuthService {
  AuthService(this._backend, this._session);

  final ApiClient _backend;
  final SessionStore _session;

  Future<AuthUser> _handleSession(Object? json) async {
    if (json is! Map || json['token'] is! String || json['user'] is! Map) {
      throw ApiException.invalidResponse;
    }
    await _session.save(json['token'] as String);
    return AuthUser.fromJson((json['user'] as Map).cast<String, dynamic>());
  }

  Future<AuthUser> login({required String email, required String password}) async {
    final json = await _backend.post(
      BackendEndpoints.login,
      body: {'email': email.trim(), 'password': password},
    );
    return _handleSession(json);
  }

  Future<AuthUser> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final json = await _backend.post(
      BackendEndpoints.register,
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
      },
    );
    return _handleSession(json);
  }

  /// Returns the signed-in user for a stored token, or null. An expired or
  /// rejected token is cleared; other errors (offline...) are rethrown so the
  /// splash screen can offer a retry instead of logging the user out.
  Future<AuthUser?> restoreSession() async {
    if (_session.token == null) return null;
    try {
      final json = await _backend.get(BackendEndpoints.me);
      return AuthUser.fromJson((json as Map).cast<String, dynamic>());
    } on ApiException catch (e) {
      if (e.type == ApiErrorType.unauthorized) {
        await _session.clear();
        return null;
      }
      rethrow;
    }
  }

  /// Ends the session locally even if the server call fails.
  Future<void> logout() async {
    try {
      await _backend.post(BackendEndpoints.logout);
    } on ApiException {
      // Token is discarded below regardless.
    } finally {
      await _session.clear();
    }
  }

  /// Asks the backend to email a 6-digit reset code. Returns the code only
  /// when the on-device mock backend is used (it has no email); a real
  /// server never returns it.
  Future<String?> requestPasswordReset(String email) async {
    final json = await _backend.post(
      BackendEndpoints.forgotPassword,
      body: {'email': email.trim()},
    );
    return json is Map ? json['demoCode'] as String? : null;
  }

  /// Sets a new password using the emailed code.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      _backend.post(
        BackendEndpoints.resetPassword,
        body: {'email': email.trim(), 'code': code.trim(), 'newPassword': newPassword},
      );

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _backend.post(
        BackendEndpoints.changePassword,
        body: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
}
