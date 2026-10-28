import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/api/endpoints.dart';
import '../data/models.dart';

/// Restaurants come from the backend (mock today); their menus are built by
/// `FoodService` from DummyJSON tags.
class RestaurantService {
  RestaurantService(this._backend);

  final ApiClient _backend;
  List<Restaurant>? _all;

  List<Restaurant> _parse(Object? json) {
    if (json is! List) throw ApiException.invalidResponse;
    return json
        .map((e) => Restaurant.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<Restaurant>> getRestaurants({
    bool popularOnly = false,
    bool sortByDistance = false,
    String? query,
  }) async {
    final list = _parse(
      await _backend.get(
        BackendEndpoints.restaurants,
        query: {
          if (popularOnly) 'popular': 'true',
          if (sortByDistance) 'sort': 'distance',
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        },
      ),
    );
    if (!popularOnly && (query == null || query.trim().isEmpty)) _all = list;
    return list;
  }

  Future<Restaurant> getRestaurant(String id) async {
    final cached = _all?.where((r) => r.id == id).firstOrNull;
    if (cached != null) return cached;
    final json = await _backend.get(BackendEndpoints.restaurant(id));
    if (json is! Map) throw ApiException.invalidResponse;
    return Restaurant.fromJson(json.cast<String, dynamic>());
  }

  /// All restaurants, fetched once per app session.
  Future<List<Restaurant>> all() async => _all ?? await getRestaurants();

  /// Picks the restaurant that serves a recipe: the first whose menu tags
  /// match the recipe's tags (pure-veg kitchens only take veg dishes),
  /// otherwise the catch-all kitchen.
  Future<Restaurant> resolveForRecipe(List<String> recipeTags, bool isVeg) async {
    final restaurants = await all();
    final tags = recipeTags.map((t) => t.toLowerCase()).toSet();
    for (final r in restaurants) {
      if (r.servesAllRecipes || (r.isPureVeg && !isVeg)) continue;
      if (r.menuTags.any((t) => tags.contains(t.toLowerCase()))) return r;
    }
    return restaurants.firstWhere(
      (r) => r.servesAllRecipes,
      orElse: () => restaurants.first,
    );
  }
}
