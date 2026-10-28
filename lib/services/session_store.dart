import '../core/storage/local_store.dart';

/// Holds the bearer token in memory (for synchronous header building) and
/// persists it so the session survives app restarts.
class SessionStore {
  SessionStore(this._store) : _token = _store.getString(_key);

  static const _key = 'session.token';
  final LocalStore _store;
  String? _token;

  String? get token => _token;

  Future<void> save(String token) async {
    _token = token;
    await _store.setString(_key, token);
  }

  Future<void> clear() async {
    _token = null;
    await _store.setString(_key, null);
  }
}
