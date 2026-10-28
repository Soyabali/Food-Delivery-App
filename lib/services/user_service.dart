import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/api/endpoints.dart';
import '../core/auth/auth_state.dart';
import '../data/models.dart';

enum FavoriteType { restaurant, dish }

/// Profile and favourites for the signed-in user (backend).
class UserService {
  UserService(this._backend);

  final ApiClient _backend;

  Future<AuthUser> getProfile() async {
    final json = await _backend.get(BackendEndpoints.me);
    if (json is! Map) throw ApiException.invalidResponse;
    return AuthUser.fromJson(json.cast<String, dynamic>());
  }

  Favorites _parse(Object? json) {
    if (json is! Map) throw ApiException.invalidResponse;
    return Favorites.fromJson(json.cast<String, dynamic>());
  }

  Future<Favorites> getFavorites() async =>
      _parse(await _backend.get(BackendEndpoints.favorites));

  Future<Favorites> setFavorite(FavoriteType type, String id, bool favorite) async {
    final path = BackendEndpoints.favorite(type.name, id);
    return _parse(
      favorite ? await _backend.put(path) : await _backend.delete(path),
    );
  }
}
