import 'package:flutter_test/flutter_test.dart';
import 'package:mobileapp/core/api/api_exception.dart';
import 'package:mobileapp/core/api/endpoints.dart';
import 'package:mobileapp/core/storage/local_store.dart';
import 'package:mobileapp/data/mock_backend/mock_backend.dart';
import 'package:mobileapp/data/mock_backend/mock_seed_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exercises the mock backend purely through its HTTP-like API.
class Session {
  Session(this.store, {DateTime Function()? clock}) {
    backend = MockBackend(
      store: store,
      tokenProvider: () => token,
      latency: Duration.zero,
      clock: clock,
    );
  }

  final LocalStore store;
  late final MockBackend backend;
  String? token;

  Future<void> login([
    String email = MockSeedData.demoEmail,
    String password = MockSeedData.demoPassword,
  ]) async {
    final json = await backend.post(
      BackendEndpoints.login,
      body: {'email': email, 'password': password},
    );
    token = json['token'] as String;
  }

  Future<Map<String, dynamic>> add({
    int recipeId = 11,
    String restaurantId = 'royal-biryani',
    int unitPrice = 400,
    int quantity = 1,
    bool replaceCart = false,
    String? portion,
  }) async =>
      (await backend.post(
        BackendEndpoints.cartItems,
        body: {
          'recipeId': recipeId,
          'restaurantId': restaurantId,
          'name': 'Dish $recipeId',
          'image': '',
          'isVeg': false,
          'unitPrice': unitPrice,
          'quantity': quantity,
          'portion': ?portion,
          'addOns': <String>[],
          'replaceCart': replaceCart,
        },
      )) as Map<String, dynamic>;
}

Future<ApiException> errorOf(Future<dynamic> f) async {
  try {
    await f;
  } on ApiException catch (e) {
    return e;
  }
  fail('expected ApiException');
}

void main() {
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await LocalStore.open();
  });

  test('protected endpoints require a session', () async {
    final s = Session(store);
    expect((await errorOf(s.backend.get(BackendEndpoints.cart))).statusCode, 401);
    expect((await errorOf(s.backend.get(BackendEndpoints.me))).statusCode, 401);
  });

  test('demo login, wrong password, register and duplicate email', () async {
    final s = Session(store);
    expect(
      (await errorOf(s.login(MockSeedData.demoEmail, 'nope'))).message,
      'Incorrect email or password.',
    );
    await s.login();
    expect((await s.backend.get(BackendEndpoints.me))['name'], 'Rahul Sharma');

    final reg = await s.backend.post(BackendEndpoints.register, body: {
      'name': 'Asha',
      'email': 'ASHA@x.com',
      'phone': '9876543210',
      'password': 'longenough',
    });
    expect(reg['user']['email'], 'asha@x.com');
    final dup = await errorOf(s.backend.post(BackendEndpoints.register, body: {
      'name': 'Asha',
      'email': 'asha@x.com',
      'phone': '9876543210',
      'password': 'longenough',
    }));
    expect(dup.statusCode, 409);
  });

  test('passwords are stored hashed, never in plain text', () async {
    final s = Session(store);
    await s.login();
    final users = store.readJson('mockdb.users').toString();
    expect(users, isNot(contains(MockSeedData.demoPassword)));
  });

  test('cart totals: free delivery, tax, coupon rules', () async {
    final s = Session(store);
    await s.login();

    // ₹150 < ₹199 threshold: Royal Biryani has fee 0 -> standard ₹30 applies.
    var cart = await s.add(unitPrice: 150);
    var t = cart['totals'] as Map;
    expect(t['itemTotal'], 150);
    expect(t['deliveryFee'], 30);
    expect(t['taxes'], 7.5);
    expect(t['total'], 187.5);

    cart = (await s.backend.post(BackendEndpoints.cartCoupon, body: {'code': 'apna100'})) as Map<String, dynamic>;
    expect(cart['couponCode'], 'APNA100');
    expect(cart['couponMessage'], 'Add ₹150 more to use APNA100');
    expect((cart['totals'] as Map)['discount'], 0);

    // Same configuration merges into the existing line.
    cart = await s.add(unitPrice: 150);
    final items = cart['items'] as List;
    expect(items, hasLength(1));
    expect((items.first as Map)['quantity'], 2);
    t = cart['totals'] as Map;
    expect(t['itemTotal'], 300);
    expect(t['deliveryFee'], 0);
    expect(t['discount'], 100);
    expect(t['savings'], 130);
    expect(t['total'], 215.0); // 300 + 15 tax - 100

    // APNA50: 50% capped at ₹150.
    cart = (await s.backend.post(BackendEndpoints.cartCoupon, body: {'code': 'APNA50'})) as Map<String, dynamic>;
    expect((cart['totals'] as Map)['discount'], 150);

    expect(
      (await errorOf(s.backend.post(BackendEndpoints.cartCoupon, body: {'code': 'FAKE'}))).message,
      'Invalid coupon code.',
    );
  });

  test('one restaurant per cart (409 unless replaceCart)', () async {
    final s = Session(store);
    await s.login();
    await s.add();
    final e = await errorOf(s.add(recipeId: 1, restaurantId: 'pizza-roma'));
    expect(e.statusCode, 409);
    final cart = await s.add(recipeId: 1, restaurantId: 'pizza-roma', replaceCart: true);
    expect((cart['restaurant'] as Map)['id'], 'pizza-roma');
    expect(cart['items'], hasLength(1));
  });

  test('quantity update, removal and validation', () async {
    final s = Session(store);
    await s.login();
    final id = ((await s.add())['items'] as List).first['id'] as String;
    var cart = await s.backend.patch(BackendEndpoints.cartItem(id), body: {'quantity': 3});
    expect(cart['totals']['itemTotal'], 1200);
    expect(
      (await errorOf(s.backend.patch(BackendEndpoints.cartItem(id), body: {'quantity': 99}))).statusCode,
      400,
    );
    cart = await s.backend.patch(BackendEndpoints.cartItem(id), body: {'quantity': 0});
    expect(cart['items'], isEmpty);
  });

  test('placing an order validates, empties the cart and tracks status', () async {
    var now = DateTime(2026, 10, 28, 20, 0);
    final s = Session(store, clock: () => now);
    await s.login();

    expect(
      (await errorOf(s.backend.post(BackendEndpoints.orders, body: {'addressId': 'home', 'paymentMethod': 'upi'}))).message,
      'Your cart is empty.',
    );
    await s.add(unitPrice: 250);
    expect(
      (await errorOf(s.backend.post(BackendEndpoints.orders, body: {'addressId': 'nowhere', 'paymentMethod': 'upi'}))).message,
      'Please choose a delivery address.',
    );

    final order = await s.backend.post(
      BackendEndpoints.orders,
      body: {'addressId': 'home', 'paymentMethod': 'upi'},
    );
    expect(order['id'], matches(RegExp(r'^AF-\d{5}$')));
    expect(order['status'], 'placed');
    expect(order['amount'], 262.5);
    expect((await s.backend.get(BackendEndpoints.cart))['items'], isEmpty);

    now = now.add(const Duration(seconds: 61));
    var tracked = await s.backend.get(BackendEndpoints.order(order['id'] as String));
    expect(tracked['status'], 'outForDelivery');
    expect((tracked['statusTimes'] as Map).keys, containsAll(['placed', 'preparing', 'outForDelivery']));

    now = now.add(const Duration(minutes: 5));
    tracked = await s.backend.get(BackendEndpoints.order(order['id'] as String));
    expect(tracked['status'], 'delivered');
    expect(await s.backend.get(BackendEndpoints.orders), hasLength(1));
  });

  test('data persists across backend instances (app restart)', () async {
    final first = Session(store);
    await first.login();
    await first.add(quantity: 2);
    await first.backend.put(BackendEndpoints.favorite('restaurant', 'pizza-roma'));

    final second = Session(store)..token = first.token;
    final cart = await second.backend.get(BackendEndpoints.cart);
    expect(cart['items'].first['quantity'], 2);
    expect((await second.backend.get(BackendEndpoints.favorites))['restaurants'], ['pizza-roma']);
  });

  test('logout invalidates the token', () async {
    final s = Session(store);
    await s.login();
    await s.backend.post(BackendEndpoints.logout);
    expect((await errorOf(s.backend.get(BackendEndpoints.me))).statusCode, 401);
  });

  test('unknown endpoints return 404', () async {
    final s = Session(store);
    expect((await errorOf(s.backend.get('/nope'))).statusCode, 404);
  });
}
