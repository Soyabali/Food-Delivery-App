/// Every route path in one place. Use these instead of string literals.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  // Bottom-navigation tabs.
  static const home = '/home';
  static const search = '/search';
  static const orders = '/orders';
  static const cart = '/cart';
  static const profile = '/profile';

  // Full-screen details (pushed above the tab bar).
  static const changePassword = '/profile/change-password';
  static String restaurant(String id) => '/restaurant/$id';
  static String dish(int id, {String? restaurantId}) => Uri(
        path: '/dish/$id',
        queryParameters: restaurantId == null ? null : {'restaurant': restaurantId},
      ).toString();
  static String orderTracking(String id) => '/orders/$id';
  static String orderSuccess(String id) => '/order-success/$id';
  static String searchCategory(String category) =>
      Uri(path: search, queryParameters: {'category': category}).toString();

  /// Reachable without a session.
  static const public = {splash, login, register, forgotPassword};

  /// Signed-in users are bounced away from these.
  static const authOnly = {login, register};
}
