import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../core/api/api_client.dart';
import '../core/auth/auth_state.dart';
import '../core/config/app_config.dart';
import '../core/connectivity/connectivity_service.dart';
import '../core/connectivity/offline_banner.dart';
import '../core/storage/local_store.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/common.dart';
import '../data/mock_backend/mock_backend.dart';
import '../services/address_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/category_service.dart';
import '../services/food_service.dart';
import '../services/offer_service.dart';
import '../services/order_service.dart';
import '../services/restaurant_service.dart';
import '../services/session_store.dart';
import '../services/user_service.dart';
import '../state/auth_controller.dart';
import '../state/cart_controller.dart';
import '../state/orders_controller.dart';
import '../state/preferences_controller.dart';
import 'router/app_router.dart';

/// Composition root: builds the API clients, services and controllers.
/// This is the only place that decides mock vs. real backend.
class AppServices {
  AppServices._({
    required this.config,
    required this.foodApi,
    required this.backend,
    required this.connectivity,
    required this.auth,
    required this.cart,
    required this.orders,
    required this.preferences,
    required this.food,
    required this.restaurants,
    required this.categories,
    required this.offers,
  });

  static Future<AppServices> create({
    AppConfig? config,
    LocalStore? store,
    http.Client? httpClient,
    ConnectivityService? connectivity,
    MockBackend Function(LocalStore store, TokenProvider token)? mockBackend,
  }) async {
    final cfg = config ?? AppConfig.fromEnvironment();
    AppImage.backendOrigin =
        cfg.isMockBackend ? null : Uri.parse(cfg.backendBaseUrl);
    final local = store ?? await LocalStore.open();
    final session = SessionStore(local);

    // Real HTTP: DummyJSON for food data.
    final foodApi = HttpApiClient(
      baseUrl: cfg.foodApiBaseUrl,
      timeout: cfg.requestTimeout,
      httpClient: httpClient,
    );
    // Backend: on-device mock, or the same endpoints over HTTP.
    final ApiClient backend = cfg.isMockBackend
        ? (mockBackend?.call(local, () => session.token) ??
            MockBackend(
              store: local,
              tokenProvider: () => session.token,
              latency: cfg.mockLatency,
            ))
        : HttpApiClient(
            baseUrl: cfg.backendBaseUrl,
            timeout: cfg.requestTimeout,
            httpClient: httpClient,
            tokenProvider: () => session.token,
          );

    final catalog = cfg.isMockBackend ? null : backend;
    final restaurants = RestaurantService(backend);
    final auth = AuthController(AuthService(backend, session), cfg);
    Future<void> expire() => auth.expireSession();

    return AppServices._(
      config: cfg,
      foodApi: foodApi,
      backend: backend,
      connectivity: connectivity ?? ConnectivityService(),
      auth: auth,
      cart: CartController(CartService(backend), onUnauthorized: expire),
      orders: OrdersController(OrderService(backend), onUnauthorized: expire),
      preferences: PreferencesController(
        AddressService(backend),
        UserService(backend),
        onUnauthorized: expire,
      ),
      // Real backend: dishes and categories are the ones managed in the
      // admin dashboard. Mock backend: DummyJSON recipes.
      food: FoodService(foodApi, restaurants, backend: catalog),
      restaurants: restaurants,
      categories: CategoryService(foodApi, backend: catalog),
      offers: OfferService(backend),
    );
  }

  final AppConfig config;
  final ApiClient foodApi;
  final ApiClient backend;
  final ConnectivityService connectivity;
  final AuthController auth;
  final CartController cart;
  final OrdersController orders;
  final PreferencesController preferences;
  final FoodService food;
  final RestaurantService restaurants;
  final CategoryService categories;
  final OfferService offers;

  /// Non-null only in mock mode (used by "Reset demo data").
  MockBackend? get mockBackend => backend is MockBackend ? backend as MockBackend : null;
}

class ApnaFoodApp extends StatefulWidget {
  const ApnaFoodApp({super.key, required this.services});

  final AppServices services;

  @override
  State<ApnaFoodApp> createState() => _ApnaFoodAppState();
}

class _ApnaFoodAppState extends State<ApnaFoodApp> {
  late final GoRouter _router = createAppRouter(widget.services.auth);
  AuthStatus _lastStatus = AuthStatus.unknown;

  AppServices get _s => widget.services;

  @override
  void initState() {
    super.initState();
    _s.auth.addListener(_onAuthChanged);
    _s.connectivity.init();
  }

  /// Loads the user's cart/orders/addresses on sign-in and clears local
  /// copies on sign-out (server data is kept).
  void _onAuthChanged() {
    final status = _s.auth.status;
    if (status == _lastStatus) return;
    if (status == AuthStatus.authenticated) {
      _s.cart.load();
      _s.orders.load();
      _s.preferences.load();
    } else if (_lastStatus == AuthStatus.authenticated) {
      _s.cart.reset();
      _s.orders.reset();
      _s.preferences.reset();
    }
    _lastStatus = status;
  }

  @override
  void dispose() {
    _s.auth.removeListener(_onAuthChanged);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: _s),
        Provider.value(value: _s.config),
        Provider.value(value: _s.food),
        Provider.value(value: _s.restaurants),
        Provider.value(value: _s.categories),
        Provider.value(value: _s.offers),
        ChangeNotifierProvider.value(value: _s.auth),
        ChangeNotifierProvider.value(value: _s.connectivity),
        ChangeNotifierProvider.value(value: _s.cart),
        ChangeNotifierProvider.value(value: _s.orders),
        ChangeNotifierProvider.value(value: _s.preferences),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: MaterialApp.router(
          title: 'Apna Food',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          themeMode: ThemeMode.light,
          routerConfig: _router,
          builder: (context, child) => OfflineBanner(
            connectivity: _s.connectivity,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
