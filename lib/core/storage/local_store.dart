import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Small JSON key-value store on top of SharedPreferences. Used for the
/// session token and by the mock backend's "database".
///
/// SharedPreferences is NOT encrypted. Fine for a demo; a production app
/// should keep tokens in `flutter_secure_storage` (see
/// docs/REAL_BACKEND_MIGRATION.md).
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String? value) => value == null
      ? _prefs.remove(key)
      : _prefs.setString(key, value);

  dynamic readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null; // corrupted entry: treat as missing
    }
  }

  Future<void> writeJson(String key, Object? value) =>
      _prefs.setString(key, jsonEncode(value));

  Future<void> remove(String key) => _prefs.remove(key);

  Future<void> removeWithPrefix(String prefix) async {
    for (final key in _prefs.getKeys().where((k) => k.startsWith(prefix))) {
      await _prefs.remove(key);
    }
  }
}
