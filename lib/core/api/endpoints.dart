/// Every endpoint path the app calls. Base URLs live in `AppConfig`.
///
/// [FoodEndpoints] are real DummyJSON routes. [BackendEndpoints] are served by
/// the on-device mock backend today and by your real server once
/// `BACKEND_MODE=http`.
abstract final class FoodEndpoints {
  static const recipes = '/recipes';
  static String recipe(int id) => '/recipes/$id';
  static const search = '/recipes/search';
  static const tags = '/recipes/tags';
  static String byTag(String tag) => '/recipes/tag/${Uri.encodeComponent(tag)}';
  static String byMealType(String mealType) =>
      '/recipes/meal-type/${Uri.encodeComponent(mealType.toLowerCase())}';
}

abstract final class BackendEndpoints {
  // Auth
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const logout = '/auth/logout';
  static const me = '/auth/me';
  static const forgotPassword = '/auth/forgot-password';
  static const changePassword = '/auth/change-password';

  // Catalogue
  static const restaurants = '/restaurants';
  static String restaurant(String id) => '/restaurants/$id';
  static const offers = '/offers';
  static const notifications = '/notifications';

  // User data
  static const addresses = '/addresses';
  static String selectAddress(String id) => '/addresses/$id/select';
  static const favorites = '/favorites';
  static String favorite(String type, String id) => '/favorites/$type/$id';

  // Cart
  static const cart = '/cart';
  static const cartItems = '/cart/items';
  static String cartItem(String id) => '/cart/items/$id';
  static const cartCoupon = '/cart/coupon';
  static const cartInstructions = '/cart/instructions';

  // Orders
  static const orders = '/orders';
  static String order(String id) => '/orders/$id';
}
