import 'dart:math';

import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/api/endpoints.dart';
import '../data/adapters/recipe_adapter.dart';
import '../data/models.dart';
import 'restaurant_service.dart';

/// Menu [Dish]es. With a real [backend] (BACKEND_MODE=http) they are the
/// menu items managed in the admin dashboard; otherwise they come from the
/// DummyJSON Recipes API (real HTTP), adapted with restaurant context and
/// demo prices.
class FoodService {
  FoodService(this._foodApi, this._restaurants, {this._backend});

  final ApiClient _foodApi;
  final RestaurantService _restaurants;
  final ApiClient? _backend;

  static List<Dish> _menuItems(Object? json) {
    if (json is! List) throw ApiException.invalidResponse;
    return json.map((e) => Dish.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Dish>> _backendItems(ApiClient backend, Map<String, String> query) async =>
      _menuItems(await backend.get(BackendEndpoints.menuItems, query: query));

  Future<List<Dish>> _toDishes(
    List<Map<String, dynamic>> recipes, {
    Restaurant? restaurant,
  }) async {
    final dishes = <Dish>[];
    for (final r in recipes) {
      final tags = RecipeAdapter.tags(r);
      final ingredients =
          (r['ingredients'] as List? ?? const []).map((e) => '$e').toList();
      final isVeg = VegClassifier.isVeg(ingredients, r['name'] as String);
      final owner =
          restaurant ?? await _restaurants.resolveForRecipe(tags, isVeg);
      dishes.add(RecipeAdapter.toDish(r, owner));
    }
    return dishes;
  }

  /// GET /recipes?sortBy=rating&order=desc
  Future<List<Dish>> getTopRated({int limit = 10}) async {
    final backend = _backend;
    if (backend != null) {
      return _backendItems(backend, {'sort': 'rating', 'limit': '$limit'});
    }
    final json = await _foodApi.get(
      FoodEndpoints.recipes,
      query: {'sortBy': 'rating', 'order': 'desc', 'limit': '$limit'},
    );
    return _toDishes(RecipeAdapter.recipeList(json));
  }

  /// GET /recipes/search?q=
  Future<List<Dish>> search(String query) async {
    final backend = _backend;
    if (backend != null) return _backendItems(backend, {'q': query});
    final json = await _foodApi.get(FoodEndpoints.search, query: {'q': query});
    return _toDishes(RecipeAdapter.recipeList(json));
  }

  /// GET /recipes/tag/{tag}. With the backend, [tag] is a category from
  /// [CategoryService] (or a dish tag when no category has that name).
  Future<List<Dish>> byTag(String tag) async {
    final backend = _backend;
    if (backend != null) {
      final inCategory = await _backendItems(backend, {'category': tag, 'limit': '100'});
      return inCategory.isNotEmpty
          ? inCategory
          : _backendItems(backend, {'tag': tag, 'limit': '100'});
    }
    return _toDishes(RecipeAdapter.recipeList(await _foodApi.get(FoodEndpoints.byTag(tag))));
  }

  /// GET /recipes/meal-type/{mealType}
  Future<List<Dish>> byMealType(String mealType) async {
    final backend = _backend;
    if (backend != null) {
      return _backendItems(backend, {'mealType': mealType, 'limit': '100'});
    }
    return _toDishes(
      RecipeAdapter.recipeList(await _foodApi.get(FoodEndpoints.byMealType(mealType))),
    );
  }

  /// GET /recipes/{id}. [restaurantId] keeps the restaurant the user came
  /// from (menus can overlap); otherwise the owner is resolved from tags.
  /// Backend menu items belong to exactly one restaurant.
  Future<Dish> getDish(int id, {String? restaurantId}) async {
    final backend = _backend;
    if (backend != null) {
      final json = await backend.get(BackendEndpoints.menuItem(id));
      if (json is! Map<String, dynamic>) throw ApiException.invalidResponse;
      return Dish.fromJson(json);
    }
    final json = RecipeAdapter.recipe(await _foodApi.get(FoodEndpoints.recipe(id)));
    final restaurant = restaurantId == null
        ? null
        : await _restaurants.getRestaurant(restaurantId);
    return (await _toDishes([json], restaurant: restaurant)).single;
  }

  /// Menu = recipes for each of the restaurant's tags (parallel requests),
  /// de-duplicated; pure-veg kitchens drop non-veg recipes. With the
  /// backend: GET /restaurants/{id}/menu.
  Future<List<Dish>> menuFor(Restaurant restaurant) async {
    final backend = _backend;
    if (backend != null) {
      return _menuItems(await backend.get(BackendEndpoints.restaurantMenu(restaurant.id)));
    }
    final responses = await Future.wait(
      restaurant.menuTags.map((t) => _foodApi.get(FoodEndpoints.byTag(t))),
    );
    final seen = <int>{};
    final recipes = [
      for (final json in responses)
        for (final r in RecipeAdapter.recipeList(json))
          if (seen.add((r['id'] as num).toInt())) r,
    ];
    final dishes = await _toDishes(recipes, restaurant: restaurant);
    return restaurant.isPureVeg ? dishes.where((d) => d.isVeg).toList() : dishes;
  }

  /// A random recipe: reads the total, then fetches one at a random offset.
  Future<Dish> getRandomDish() async {
    final backend = _backend;
    if (backend != null) {
      final dishes = await _backendItems(backend, {'limit': '100'});
      if (dishes.isEmpty) throw ApiException.invalidResponse;
      return dishes[Random().nextInt(dishes.length)];
    }
    final head = await _foodApi.get(
      FoodEndpoints.recipes,
      query: {'limit': '1', 'select': 'id'},
    );
    final total = (head as Map)['total'] as int? ?? 1;
    final json = await _foodApi.get(
      FoodEndpoints.recipes,
      query: {'limit': '1', 'skip': '${Random().nextInt(max(total, 1))}'},
    );
    return (await _toDishes(RecipeAdapter.recipeList(json))).first;
  }
}
