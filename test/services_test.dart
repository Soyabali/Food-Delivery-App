import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobileapp/app/router/app_router.dart';
import 'package:mobileapp/app/router/app_routes.dart';
import 'package:mobileapp/core/api/api_client.dart';
import 'package:mobileapp/core/api/api_exception.dart';
import 'package:mobileapp/core/storage/local_store.dart';
import 'package:mobileapp/core/widgets/common.dart';
import 'package:mobileapp/data/mock_backend/mock_backend.dart';
import 'package:mobileapp/data/mock_backend/mock_seed_data.dart';
import 'package:mobileapp/data/models.dart';
import 'package:mobileapp/services/auth_service.dart';
import 'package:mobileapp/services/cart_service.dart';
import 'package:mobileapp/services/food_service.dart';
import 'package:mobileapp/services/restaurant_service.dart';
import 'package:mobileapp/services/session_store.dart';
import 'package:mobileapp/state/auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_food_api.dart';
import 'test_helpers.dart' show testConfig;

void main() {
  late LocalStore store;
  late SessionStore session;
  late MockBackend backend;
  late FakeFoodApi fake;
  late FoodService food;
  late RestaurantService restaurants;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.open();
    session = SessionStore(store);
    backend = MockBackend(
      store: store,
      tokenProvider: () => session.token,
      latency: Duration.zero,
    );
    fake = FakeFoodApi();
    restaurants = RestaurantService(backend);
    food = FoodService(
      HttpApiClient(
        baseUrl: 'https://dummyjson.test',
        timeout: const Duration(seconds: 2),
        httpClient: fake.client,
      ),
      restaurants,
    );
  });

  group('FoodService', () {
    test('top rated hits /recipes?sortBy=rating and assigns restaurants', () async {
      final dishes = await food.getTopRated(limit: 2);
      expect(fake.requests.last.queryParameters, containsPair('sortBy', 'rating'));
      expect(dishes.map((d) => d.name), ['Chicken Biryani', 'Chocolate Chip Cookies']);
      expect(dishes.first.restaurantId, 'royal-biryani');
      // Cookies match no specialist tags except Dessert -> catch-all kitchen.
      expect(dishes.last.restaurantId, 'apna-kitchen');
    });

    test('search and tag endpoints', () async {
      expect((await food.search('pizza')).single.id, 1);
      expect(fake.requests.last.path, '/recipes/search');
      expect((await food.byTag('Salad')).single.name, 'Quinoa Salad with Avocado');
      expect(fake.requests.last.path, '/recipes/tag/Salad');
      expect(await food.search('zzz'), isEmpty);
    });

    test('dish details keep the restaurant the user came from', () async {
      final dish = await food.getDish(6, restaurantId: 'green-bowl');
      expect(dish.restaurantId, 'green-bowl');
      expect(dish.isVeg, isTrue);
    });

    test('pure-veg menus drop non-veg recipes', () async {
      final greenBowl = await restaurants.getRestaurant('green-bowl');
      final menu = await food.menuFor(greenBowl);
      expect(menu.every((d) => d.isVeg), isTrue);
      expect(menu.map((d) => d.id), contains(6));
    });

    test('404 and outages surface as ApiException', () async {
      await expectLater(
        food.getDish(999),
        throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.notFound)),
      );
      fake.failure = FakeFailure.network;
      await expectLater(
        food.getTopRated(),
        throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.network)),
      );
      fake.failure = FakeFailure.invalidJson;
      await expectLater(
        food.search('x'),
        throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.invalidResponse)),
      );
    });
  });

  group('AuthService + CartService', () {
    test('login stores the token; restoreSession reads it back', () async {
      final auth = AuthService(backend, session);
      final user = await auth.login(
        email: MockSeedData.demoEmail,
        password: MockSeedData.demoPassword,
      );
      expect(user.firstName, 'Rahul');
      expect(store.getString('session.token'), isNotNull);

      final restored = await AuthService(backend, SessionStore(store)).restoreSession();
      expect(restored?.email, MockSeedData.demoEmail);

      await auth.logout();
      expect(store.getString('session.token'), isNull);
      expect(await auth.restoreSession(), isNull);
    });

    test('add to cart reports a restaurant conflict', () async {
      await AuthService(backend, session).login(
        email: MockSeedData.demoEmail,
        password: MockSeedData.demoPassword,
      );
      final cart = CartService(backend);
      final biryani = await food.getDish(11);
      final pizza = await food.getDish(1);

      final first = await cart.addItem(AddToCartRequest(dish: biryani, quantity: 1));
      expect(first, isA<AddedToCart>());
      expect((first as AddedToCart).cart.items.single.unitPrice, biryani.price);

      final conflict = await cart.addItem(AddToCartRequest(dish: pizza, quantity: 1));
      expect(conflict, isA<CartConflict>());
      final replaced = await cart.addItem(
        AddToCartRequest(dish: pizza, quantity: 1, replaceCart: true),
      );
      expect((replaced as AddedToCart).cart.restaurant?.id, 'pizza-roma');
    });
  });

  test('BACKEND_MODE=http: services work unchanged over real HTTP', () async {
    // A fake HTTP server that serves requests with the mock backend, so the
    // full JSON/headers/status-code path of HttpApiClient is exercised.
    String? bearer;
    final server = MockBackend(
      store: store,
      tokenProvider: () => bearer,
      latency: Duration.zero,
    );
    final httpBackend = HttpApiClient(
      baseUrl: 'http://10.0.2.2:8000/api',
      timeout: const Duration(seconds: 2),
      tokenProvider: () => session.token,
      httpClient: MockClient((request) async {
        expect(request.url.path, startsWith('/api/'));
        bearer = request.headers['Authorization']?.replaceFirst('Bearer ', '');
        final path = request.url.path.substring('/api'.length);
        final body = request.body.isEmpty ? null : jsonDecode(request.body);
        try {
          final result = switch (request.method) {
            'GET' => await server.get(path, query: request.url.queryParameters),
            'POST' => await server.post(path, body: body),
            'PATCH' => await server.patch(path, body: body),
            'PUT' => await server.put(path, body: body),
            _ => await server.delete(path),
          };
          return http.Response(jsonEncode(result), 200);
        } on ApiException catch (e) {
          return http.Response(jsonEncode({'message': e.message}), e.statusCode ?? 500);
        }
      }),
    );

    final auth = AuthService(httpBackend, session);
    await expectLater(
      auth.login(email: MockSeedData.demoEmail, password: 'wrong'),
      throwsA(isA<ApiException>().having((e) => e.type, 'type', ApiErrorType.unauthorized)),
    );
    await auth.login(email: MockSeedData.demoEmail, password: MockSeedData.demoPassword);

    final cart = CartService(httpBackend);
    final outcome = await cart.addItem(
      AddToCartRequest(dish: await food.getDish(11), quantity: 2),
    );
    expect((outcome as AddedToCart).cart.totalQuantity, 2);
    final pizza = await cart.addItem(
      AddToCartRequest(dish: await food.getDish(1), quantity: 1),
    );
    expect(pizza, isA<CartConflict>()); // 409 survives the HTTP round trip
  });

  group('authRedirect', () {
    AuthController controller() =>
        AuthController(AuthService(backend, session), testConfig);

    test('unknown session routes through splash, remembering target', () {
      final auth = controller();
      expect(authRedirect(auth, Uri.parse('/cart')), '/splash?from=%2Fcart');
      expect(authRedirect(auth, Uri.parse('/splash')), isNull);
    });

    test('signed-out users only reach public routes', () async {
      final auth = controller();
      await auth.restoreSession();
      expect(authRedirect(auth, Uri.parse(AppRoutes.home)), AppRoutes.login);
      expect(authRedirect(auth, Uri.parse(AppRoutes.forgotPassword)), isNull);
    });

    test('signed-in users are bounced off login/register', () async {
      final auth = controller();
      await auth.restoreSession();
      await auth.login(
        email: MockSeedData.demoEmail,
        password: MockSeedData.demoPassword,
      );
      expect(authRedirect(auth, Uri.parse(AppRoutes.login)), AppRoutes.home);
      expect(authRedirect(auth, Uri.parse(AppRoutes.cart)), isNull);
    });
  });

  test('uploaded image URLs point at the backend host on a device', () {
    final emulator = Uri.parse('http://10.0.2.2:8000/api');
    expect(
      AppImage.resolveUrl('http://localhost:8000/media/a.png', origin: emulator),
      'http://10.0.2.2:8000/media/a.png',
    );
    expect(
      AppImage.resolveUrl('http://127.0.0.1:8000/media/a.png', origin: emulator),
      'http://10.0.2.2:8000/media/a.png',
    );
    const cdn = 'https://cdn.dummyjson.com/recipe-images/1.webp';
    expect(AppImage.resolveUrl(cdn, origin: emulator), cdn);
    expect(AppImage.resolveUrl('http://localhost:8000/media/a.png'), 'http://localhost:8000/media/a.png');
  });
}
