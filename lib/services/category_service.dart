import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/api/endpoints.dart';

/// Food categories are DummyJSON recipe tags (GET /recipes/tags).
class CategoryService {
  CategoryService(this._foodApi);

  final ApiClient _foodApi;
  List<String>? _cache;

  /// DummyJSON exposes no "list meal types" endpoint, so the meal types it
  /// supports for GET /recipes/meal-type/{type} are listed here.
  static const mealTypes = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
    'Dessert',
    'Beverage',
  ];

  Future<List<String>> getCategories() async {
    if (_cache != null) return _cache!;
    final json = await _foodApi.get(FoodEndpoints.tags);
    if (json is! List) throw ApiException.invalidResponse;
    return _cache = json.map((e) => e.toString()).toList();
  }
}
