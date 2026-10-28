import 'dart:math';

import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';
import '../data/adapters/recipe_adapter.dart';
import '../data/models.dart';
import 'restaurant_service.dart';

/// Food items from the DummyJSON Recipes API (real HTTP), adapted into
/// menu [Dish]es with restaurant context and demo prices.
class FoodService {
  FoodService(this._foodApi, this._restaurants);

  final ApiClient _foodApi;
  final RestaurantService _restaurants;

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
    final json = await _foodApi.get(
      FoodEndpoints.recipes,
      query: {'sortBy': 'rating', 'order': 'desc', 'limit': '$limit'},
    );
    return _toDishes(RecipeAdapter.recipeList(json));
  }

  /// GET /recipes/search?q=
  Future<List<Dish>> search(String query) async {
    final json = await _foodApi.get(FoodEndpoints.search, query: {'q': query});
    return _toDishes(RecipeAdapter.recipeList(json));
  }

  /// GET /recipes/tag/{tag}
  Future<List<Dish>> byTag(String tag) async =>
      _toDishes(RecipeAdapter.recipeList(await _foodApi.get(FoodEndpoints.byTag(tag))));

  /// GET /recipes/meal-type/{mealType}
  Future<List<Dish>> byMealType(String mealType) async => _toDishes(
        RecipeAdapter.recipeList(
          await _foodApi.get(FoodEndpoints.byMealType(mealType)),
        ),
      );

  /// GET /recipes/{id}. [restaurantId] keeps the restaurant the user came
  /// from (menus can overlap); otherwise the owner is resolved from tags.
  Future<Dish> getDish(int id, {String? restaurantId}) async {
    final json = RecipeAdapter.recipe(await _foodApi.get(FoodEndpoints.recipe(id)));
    final restaurant = restaurantId == null
        ? null
        : await _restaurants.getRestaurant(restaurantId);
    return (await _toDishes([json], restaurant: restaurant)).single;
  }

  /// Menu = recipes for each of the restaurant's tags (parallel requests),
  /// de-duplicated; pure-veg kitchens drop non-veg recipes.
  Future<List<Dish>> menuFor(Restaurant restaurant) async {
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
