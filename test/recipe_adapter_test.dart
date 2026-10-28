import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/api/api_exception.dart';
import 'package:mobileapp/data/adapters/recipe_adapter.dart';
import 'package:mobileapp/data/mock_backend/mock_seed_data.dart';
import 'package:mobileapp/data/models.dart';

import 'support/fake_food_api.dart';

void main() {
  final royal = Restaurant.fromJson(MockSeedData.restaurants().first);

  test('maps DummyJSON fields onto Dish', () {
    final dish = RecipeAdapter.toDish(fixtureRecipes.first, royal);
    expect(dish.id, 11);
    expect(dish.name, 'Chicken Biryani');
    expect(dish.restaurantId, 'royal-biryani');
    expect(dish.restaurantName, 'Royal Biryani House');
    expect(dish.image, 'https://cdn.dummyjson.com/recipe-images/11.webp');
    expect(dish.rating, 5);
    expect(dish.kcal, 550);
    expect(dish.tag, 'Pakistani');
    expect(dish.prepTime, '35 mins');
    expect(dish.ingredients, contains('Basmati rice'));
    expect(dish.description, startsWith('A Pakistani dinner made with basmati rice'));
    expect(dish.badge, 'Top Rated');
  });

  test('demo pricing is deterministic, rounded and clamped', () {
    // 99 + 550*0.45 + 35*0.8 + 30 (Medium) = 404.5 -> 400
    expect(PricingPolicy.basePrice(calories: 550, totalMinutes: 35, difficulty: 'Medium'), 400);
    expect(PricingPolicy.basePrice(calories: 0, totalMinutes: 0), 100);
    expect(PricingPolicy.basePrice(calories: 5000, totalMinutes: 300), 550);
    expect(PricingPolicy.portions(400)[1].price, 240);
  });

  test('veg heuristic flags meat, fish and egg', () {
    expect(VegClassifier.isVeg(['Quinoa', 'Avocado'], 'Quinoa Salad'), isTrue);
    expect(VegClassifier.isVeg(['Chicken, cut into pieces'], 'Biryani'), isFalse);
    expect(VegClassifier.isVeg(['Flour', 'Eggs'], 'Cookies'), isFalse);
    expect(VegClassifier.isVeg(['Rice'], 'Shrimp Fried Rice'), isFalse);
  });

  test('light items get no portions, spice levels or add-ons', () {
    final cookies = RecipeAdapter.toDish(fixtureRecipes.last, royal);
    expect(cookies.portions, isEmpty);
    expect(cookies.spiceLevels, isEmpty);
    expect(cookies.addOns, isEmpty);
    final biryani = RecipeAdapter.toDish(fixtureRecipes.first, royal);
    expect(biryani.portions, hasLength(2));
    expect(biryani.spiceLevels, ['Mild', 'Medium', 'Extra Hot']);
    expect(biryani.addOns, isNotEmpty);
  });

  test('rejects unexpected response shapes', () {
    expect(
      () => RecipeAdapter.recipeList({'items': []}),
      throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.invalidResponse)),
    );
    expect(() => RecipeAdapter.recipe(['x']), throwsA(isA<ApiException>()));
  });
}
