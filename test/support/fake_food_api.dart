import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Recipes in DummyJSON's exact response shape (fields copied from
/// https://dummyjson.com/recipes, trimmed to a few entries).
Map<String, dynamic> recipe({
  required int id,
  required String name,
  required String cuisine,
  required List<String> tags,
  required List<String> ingredients,
  List<String> mealType = const ['Dinner'],
  int calories = 300,
  double rating = 4.6,
  String difficulty = 'Easy',
}) =>
    {
      'id': id,
      'name': name,
      'ingredients': ingredients,
      'instructions': ['Cook.', 'Serve.'],
      'prepTimeMinutes': 20,
      'cookTimeMinutes': 15,
      'servings': 4,
      'difficulty': difficulty,
      'cuisine': cuisine,
      'caloriesPerServing': calories,
      'tags': tags,
      'userId': 1,
      'image': 'https://cdn.dummyjson.com/recipe-images/$id.webp',
      'rating': rating,
      'reviewCount': 50,
      'mealType': mealType,
    };

final fixtureRecipes = [
  recipe(
    id: 11,
    name: 'Chicken Biryani',
    cuisine: 'Pakistani',
    tags: ['Biryani', 'Chicken', 'Main course', 'Indian', 'Pakistani', 'Asian'],
    ingredients: ['Basmati rice', 'Chicken, cut into pieces', 'Onions', 'Yogurt'],
    calories: 550,
    rating: 5,
    difficulty: 'Medium',
  ),
  recipe(
    id: 1,
    name: 'Classic Margherita Pizza',
    cuisine: 'Italian',
    tags: ['Pizza', 'Italian'],
    ingredients: ['Pizza dough', 'Tomato sauce', 'Fresh mozzarella cheese'],
    rating: 4.6,
  ),
  recipe(
    id: 6,
    name: 'Quinoa Salad with Avocado',
    cuisine: 'Mediterranean',
    tags: ['Salad', 'Quinoa'],
    ingredients: ['Quinoa', 'Avocado', 'Cherry tomatoes'],
    calories: 220,
    rating: 4.4,
  ),
  recipe(
    id: 3,
    name: 'Chocolate Chip Cookies',
    cuisine: 'American',
    tags: ['Cookies', 'Dessert', 'Baking'],
    ingredients: ['All-purpose flour', 'Butter', 'Eggs', 'Chocolate chips'],
    mealType: ['Snack', 'Dessert'],
    calories: 150,
    rating: 4.9,
  ),
];

enum FakeFailure { none, network, server, invalidJson }

/// A [MockClient] that answers the DummyJSON recipe endpoints from
/// [fixtureRecipes]. Set [failure] to simulate outages.
class FakeFoodApi {
  FakeFoodApi({List<Map<String, dynamic>>? recipes})
      : recipes = recipes ?? fixtureRecipes;

  final List<Map<String, dynamic>> recipes;
  FakeFailure failure = FakeFailure.none;
  final List<Uri> requests = [];

  late final http.Client client = MockClient(_handle);

  http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  Map<String, dynamic> _list(Iterable<Map<String, dynamic>> items) {
    final l = items.toList();
    return {'recipes': l, 'total': l.length, 'skip': 0, 'limit': l.length};
  }

  bool _hasTag(Map<String, dynamic> r, String tag) =>
      (r['tags'] as List).any((t) => '$t'.toLowerCase() == tag.toLowerCase());

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request.url);
    switch (failure) {
      case FakeFailure.network:
        throw http.ClientException('Failed host lookup', request.url);
      case FakeFailure.server:
        return _json({'message': 'boom'}, 500);
      case FakeFailure.invalidJson:
        return http.Response('<html>not json</html>', 200);
      case FakeFailure.none:
        break;
    }

    final seg = request.url.pathSegments;
    final q = request.url.queryParameters;
    if (seg.isEmpty || seg.first != 'recipes') return _json({'message': 'nope'}, 404);

    if (seg.length == 1) {
      var list = [...recipes];
      if (q['sortBy'] == 'rating') {
        list.sort((a, b) => (b['rating'] as num).compareTo(a['rating'] as num));
      }
      final skip = int.tryParse(q['skip'] ?? '') ?? 0;
      final limit = int.tryParse(q['limit'] ?? '') ?? list.length;
      final page = list.skip(skip).take(limit == 0 ? list.length : limit);
      return _json({...(_list(page)), 'total': recipes.length});
    }
    switch (seg[1]) {
      case 'search':
        final term = (q['q'] ?? '').toLowerCase();
        return _json(_list(
          recipes.where((r) => '${r['name']}'.toLowerCase().contains(term)),
        ));
      case 'tags':
        return _json({
          for (final r in recipes) ...(r['tags'] as List).cast<String>(),
        }.toList());
      case 'tag':
        return _json(_list(recipes.where((r) => _hasTag(r, seg[2]))));
      case 'meal-type':
        return _json(_list(recipes.where(
          (r) => (r['mealType'] as List)
              .any((m) => '$m'.toLowerCase() == seg[2].toLowerCase()),
        )));
      default:
        final id = int.tryParse(seg[1]);
        final match = recipes.where((r) => r['id'] == id);
        return match.isEmpty
            ? _json({'message': "Recipe with id '${seg[1]}' not found"}, 404)
            : _json(match.first);
    }
  }
}
