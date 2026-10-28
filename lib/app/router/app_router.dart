import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_state.dart';
import '../../features/authentication/forgot_password/forgot_password_screen.dart';
import '../../features/authentication/login/login_screen.dart';
import '../../features/authentication/registration/registration_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/common/not_found_screen.dart';
import '../../features/food_details/food_details_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/orders/order_tracking_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/profile/change_password_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/restaurant/restaurant_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../state/auth_controller.dart';
import 'app_routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter createAppRouter(AuthController auth) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
    redirect: (context, state) => authRedirect(auth, state.uri),
    errorBuilder: (context, state) => NotFoundScreen(location: state.uri),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) =>
            SplashScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.search,
                builder: (context, state) => SearchScreen(
                  category: state.uri.queryParameters['category'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.orders,
                builder: (context, state) => const OrdersScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => OrderTrackingScreen(
                      orderId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.cart,
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'change-password',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const ChangePasswordScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/restaurant/:id',
        builder: (context, state) =>
            RestaurantScreen(restaurantId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/dish/:id',
        builder: (context, state) => FoodDetailsScreen(
          dishId: state.pathParameters['id']!,
          restaurantId: state.uri.queryParameters['restaurant'],
        ),
      ),
      GoRoute(
        path: '/order-success/:id',
        builder: (context, state) => OrderTrackingScreen(
          orderId: state.pathParameters['id']!,
          justPlaced: true,
        ),
      ),
    ],
  );
}

/// Pure redirect logic, exposed for unit tests.
String? authRedirect(AuthController auth, Uri uri) {
  final path = uri.path;

  // Session not checked yet: everything goes through the splash screen,
  // remembering where the user was headed (e.g. a web deep link).
  if (auth.status == AuthStatus.unknown) {
    if (path == AppRoutes.splash) return null;
    return Uri(
      path: AppRoutes.splash,
      queryParameters: {'from': uri.toString()},
    ).toString();
  }

  if (!auth.isAuthenticated && !AppRoutes.public.contains(path)) {
    return AppRoutes.login;
  }
  if (auth.isAuthenticated && AppRoutes.authOnly.contains(path)) {
    return AppRoutes.home;
  }
  if (path == '/') {
    return auth.isAuthenticated ? AppRoutes.home : AppRoutes.login;
  }
  return null;
}
