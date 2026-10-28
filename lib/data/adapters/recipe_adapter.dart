import '../../core/api/api_exception.dart';
import '../models.dart';

/// Converts DummyJSON recipe JSON into the app's [Dish] model.
///
/// DummyJSON is a *recipe* API: it has no prices, restaurants, portions or
/// descriptions. Those are derived here by documented demo rules so the
/// rest of the app can treat a recipe like a menu item. A real menu API
/// would return these fields directly and this adapter would shrink to a
/// field mapping (see docs/REAL_BACKEND_MIGRATION.md).
abstract final class RecipeAdapter {
  /// Parses `{"recipes": [...]}` list responses.
  static List<Map<String, dynamic>> recipeList(Object? json) {
    if (json is! Map || json['recipes'] is! List) {
      throw ApiException.invalidResponse;
    }
    return (json['recipes'] as List).cast<Map<String, dynamic>>();
  }

  static Map<String, dynamic> recipe(Object? json) {
    if (json is! Map<String, dynamic> || json['id'] is! num) {
      throw ApiException.invalidResponse;
    }
    return json;
  }

  static List<String> tags(Map<String, dynamic> recipe) =>
      (recipe['tags'] as List? ?? const []).map((e) => e.toString()).toList();

  static Dish toDish(Map<String, dynamic> r, Restaurant restaurant) {
    final ingredients = (r['ingredients'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final mealTypes = (r['mealType'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final tags = RecipeAdapter.tags(r);
    final cuisine = r['cuisine'] as String? ?? 'Global';
    final calories = (r['caloriesPerServing'] as num?)?.toInt();
    final prep = (r['prepTimeMinutes'] as num?)?.toInt() ?? 0;
    final cook = (r['cookTimeMinutes'] as num?)?.toInt() ?? 0;
    final rating = (r['rating'] as num?)?.toDouble() ?? 0;
    final reviews = (r['reviewCount'] as num?)?.toInt() ?? 0;
    final difficulty = r['difficulty'] as String?;
    final servings = (r['servings'] as num?)?.toInt();
    final price = PricingPolicy.basePrice(
      calories: calories ?? 300,
      totalMinutes: prep + cook,
      difficulty: difficulty,
    );
    final isLight = mealTypes.any(
      (m) => const {'beverage', 'dessert', 'snack', 'snacks'}
          .contains(m.toLowerCase()),
    );

    return Dish(
      id: (r['id'] as num).toInt(),
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      name: r['name'] as String,
      description: _describe(cuisine, ingredients, mealTypes, prep + cook),
      price: price,
      image: r['image'] as String,
      isVeg: VegClassifier.isVeg(ingredients, r['name'] as String),
      category: tags.isEmpty ? cuisine : tags.first,
      rating: rating,
      ratingCount: reviews,
      prepTime: '${prep + cook} mins',
      kcal: calories,
      tag: cuisine,
      badge: rating >= 4.8 ? 'Top Rated' : (reviews >= 90 ? 'Popular' : null),
      ingredients: ingredients,
      mealTypes: mealTypes,
      tags: tags,
      difficulty: difficulty,
      servings: servings,
      portions: isLight ? const [] : PricingPolicy.portions(price),
      spiceLevels: restaurant.hasSpiceLevels && !isLight
          ? const ['Mild', 'Medium', 'Extra Hot']
          : const [],
      addOns: isLight ? const [] : restaurant.addOns,
    );
  }

  /// DummyJSON has no description field, so one is composed from real data.
  static String _describe(
    String cuisine,
    List<String> ingredients,
    List<String> mealTypes,
    int minutes,
  ) {
    String clean(String s) => s.split(',').first.trim().toLowerCase();
    final named = ingredients.take(4).map(clean).toList();
    final list = named.length <= 1
        ? named.join()
        : '${named.sublist(0, named.length - 1).join(', ')} and ${named.last}';
    final meal = mealTypes.isEmpty ? 'dish' : mealTypes.first.toLowerCase();
    return 'A $cuisine $meal made with $list. Freshly prepared in about '
        '$minutes minutes.';
  }
}

/// DEMO PRICING. DummyJSON recipes have no price, so one is derived from the
/// recipe's calories, cooking time and difficulty, rounded to ₹10 and kept
/// between ₹100 and ₹550. Deterministic: the same recipe always costs the same.
abstract final class PricingPolicy {
  static int basePrice({
    required int calories,
    required int totalMinutes,
    String? difficulty,
  }) {
    final raw = 99 +
        calories * 0.45 +
        totalMinutes * 0.8 +
        (difficulty == 'Medium' ? 30 : 0);
    final rounded = (raw / 10).round() * 10;
    return rounded.clamp(100, 550);
  }

  /// "Regular" is included; "Large" costs 60% more (rounded to ₹10).
  static List<DishOption> portions(int base) => [
        const DishOption(
          id: 'regular',
          name: 'Regular (Serves 1)',
          subtitle: 'Standard single portion',
        ),
        DishOption(
          id: 'large',
          name: 'Large (Serves 2)',
          subtitle: 'Double portion for sharing',
          price: ((base * 0.6) / 10).round() * 10,
        ),
      ];
}

/// HEURISTIC. DummyJSON has no vegetarian flag; a recipe is treated as
/// non-veg when its name or ingredients mention meat, fish or egg.
abstract final class VegClassifier {
  static final _nonVeg = RegExp(
    r'\b(chicken|beef|pork|lamb|mutton|goat|bacon|ham|sausage|shrimp|prawns?|'
    r'fish|salmon|tuna|crab|lobster|anchov\w*|turkey|duck|eggs?|keema|meat)\b',
    caseSensitive: false,
  );

  static bool isVeg(List<String> ingredients, String name) =>
      !_nonVeg.hasMatch(name) && !ingredients.any(_nonVeg.hasMatch);
}
