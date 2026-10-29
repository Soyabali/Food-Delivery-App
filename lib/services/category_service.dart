import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/api/endpoints.dart';
import '../data/models.dart';

/// Food categories: the admin-managed categories (GET /categories) when a
/// real [backend] is configured, otherwise DummyJSON recipe tags
/// (GET /recipes/tags).
class CategoryService {
  CategoryService(this._foodApi, {this._backend});

  final ApiClient _foodApi;
  final ApiClient? _backend;
  List<FoodCategory>? _cache;

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

  Future<List<FoodCategory>> getCategories() async {
    if (_cache != null) return _cache!;
    final backend = _backend;
    if (backend != null) {
      final json = await backend.get(BackendEndpoints.categories);
      if (json is! List) throw ApiException.invalidResponse;
      return _cache = json
          .map((e) => FoodCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final json = await _foodApi.get(FoodEndpoints.tags);
    if (json is! List) throw ApiException.invalidResponse;
    return _cache = json.map((e) => FoodCategory(name: e.toString())).toList();
  }
}
