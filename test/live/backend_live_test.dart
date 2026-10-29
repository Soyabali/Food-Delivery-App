// Checks that the app's real services and models understand the FastAPI
// backend (backend/). Needs the server running with seeded data:
//
//   cd backend && uvicorn app.main:app --port 8000
//   flutter test test/live/backend_live_test.dart --dart-define=BACKEND_URL=http://localhost:8000/api
@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/api/api_client.dart';
import 'package:mobileapp/core/api/api_exception.dart';
import 'package:mobileapp/core/storage/local_store.dart';
import 'package:mobileapp/data/models.dart';
import 'package:mobileapp/services/address_service.dart';
import 'package:mobileapp/services/auth_service.dart';
import 'package:mobileapp/services/cart_service.dart';
import 'package:mobileapp/services/category_service.dart';
import 'package:mobileapp/services/food_service.dart';
import 'package:mobileapp/services/offer_service.dart';
import 'package:mobileapp/services/order_service.dart';
import 'package:mobileapp/services/restaurant_service.dart';
import 'package:mobileapp/services/session_store.dart';
import 'package:mobileapp/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const backendUrl = String.fromEnvironment('BACKEND_URL');

void main() {
  late HttpApiClient api;
  late SessionStore session;

  setUpAll(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    session = SessionStore(await LocalStore.open());
    api = HttpApiClient(
      baseUrl: backendUrl,
      timeout: const Duration(seconds: 15),
      tokenProvider: () => session.token,
    );
  });

  group('FastAPI backend (live)', skip: backendUrl.isEmpty ? 'set BACKEND_URL' : false, () {
    test('auth', () async {
      final auth = AuthService(api, session);
      await expectLater(
        auth.login(email: 'rahul.sharma@example.com', password: 'wrong'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Incorrect email or password.')),
      );
      final user = await auth.login(email: 'rahul.sharma@example.com', password: 'supersecret123');
      expect(user.firstName, 'Rahul');
      expect((await auth.restoreSession())?.email, 'rahul.sharma@example.com');
    });

    test('catalogue models parse', () async {
      final restaurants = await RestaurantService(api).getRestaurants(sortByDistance: true);
      expect(restaurants, hasLength(greaterThanOrEqualTo(8)));
      expect(restaurants.first.distanceKm, lessThanOrEqualTo(restaurants.last.distanceKm));
      final royal = restaurants.firstWhere((r) => r.id == 'royal-biryani');
      expect(royal.addOns, isNotEmpty);
      expect((await OfferService(api).getFeaturedOffer())?.code, 'APNA50');
      expect(await OfferService(api).getNotifications(), isNotEmpty);
    });

    test('dishes and categories come from the backend', () async {
      // DummyJSON must not be called when a backend is configured.
      final unused = HttpApiClient(
        baseUrl: 'http://unused.invalid',
        timeout: const Duration(seconds: 1),
      );
      final food = FoodService(unused, RestaurantService(api), backend: api);
      final categories = await CategoryService(unused, backend: api).getCategories();
      final desserts = categories.firstWhere((c) => c.name == 'Desserts');
      expect(desserts.emoji, isNotNull);

      final top = await food.getTopRated(limit: 5);
      expect(top, hasLength(5));
      expect(top.first.rating, greaterThanOrEqualTo(top.last.rating));
      final biryani = await food.getDish(11);
      expect(biryani.name, 'Chicken Biryani');
      expect(biryani.portions, isNotEmpty);
      expect((await food.byTag('Desserts')).every((d) => d.category == 'Desserts'), isTrue);
      final menu = await food.menuFor(
        (await RestaurantService(api).getRestaurants()).firstWhere((r) => r.id == 'royal-biryani'),
      );
      expect(menu.map((d) => d.id), contains(11));
      expect(await food.search('biryani'), isNotEmpty);
    });

    test('addresses and favourites parse', () async {
      final book = await AddressService(api).getAddresses();
      expect(book.items, isNotEmpty);
      final favs = await UserService(api).setFavorite(FavoriteType.restaurant, 'pizza-roma', true);
      expect(favs.restaurants, contains('pizza-roma'));
      await UserService(api).setFavorite(FavoriteType.restaurant, 'pizza-roma', false);
    });

    test('cart and order round trip with app payloads', () async {
      final cart = CartService(api);
      await cart.clear();
      // Exactly what the app sends today (DummyJSON-based dish, own price).
      const dish = Dish(
        id: 11,
        restaurantId: 'royal-biryani',
        restaurantName: 'Royal Biryani House',
        name: 'Chicken Biryani',
        description: '',
        price: 1, // server must ignore this
        image: '',
        isVeg: false,
        category: 'Biryani',
      );
      final added = await cart.addItem(
        const AddToCartRequest(
          dish: dish,
          quantity: 2,
          portion: DishOption(id: 'regular', name: 'Regular (Serves 1)'),
          spiceLevel: 'Medium',
          addOns: [DishOption(id: 'raita', name: 'Mint Raita', price: 25)],
        ),
      );
      final c = (added as AddedToCart).cart;
      expect(c.items.single.unitPrice, greaterThan(100));
      expect(c.items.single.addOns, ['Mint Raita']);
      expect(c.restaurant?.id, 'royal-biryani');

      final withCoupon = await cart.applyCoupon('APNA100');
      expect(withCoupon.couponCode, 'APNA100');

      final address = (await AddressService(api).getAddresses()).selectedId;
      final order = await OrderService(api).placeOrder(addressId: address, payment: PaymentMethod.upi);
      expect(order.id, startsWith('AF-'));
      expect(order.status, OrderStatus.placed);
      expect((await OrderService(api).getOrder(order.id)).items, hasLength(1));
      expect((await cart.getCart()).isEmpty, isTrue);
    });
  });
}
