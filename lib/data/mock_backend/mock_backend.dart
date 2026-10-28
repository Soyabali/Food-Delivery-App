import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/storage/local_store.dart';
import 'mock_seed_data.dart';

/// DEMO ONLY. An in-app stand-in for the Apna Food backend.
///
/// It implements [ApiClient], answering the same REST paths
/// (`BackendEndpoints`) a real server would, with simulated latency, JSON
/// round-tripping, status codes and bearer-token auth. Data is stored on
/// this device with SharedPreferences, so it survives app restarts but is
/// never shared between devices or users. Switch to a real server with
/// `BACKEND_MODE=http` without touching services or screens.
class MockBackend implements ApiClient {
  MockBackend({
    required LocalStore store,
    required TokenProvider tokenProvider,
    this.latency = const Duration(milliseconds: 600),
    DateTime Function()? clock,
    this.preparingAfter = MockSeedData.preparingAfter,
    this.outForDeliveryAfter = MockSeedData.outForDeliveryAfter,
    this.deliveredAfter = MockSeedData.deliveredAfter,
  })  : _store = store, // ignore: prefer_initializing_formals
        _token = tokenProvider,
        _clock = clock ?? DateTime.now;

  final LocalStore _store;
  final TokenProvider _token;
  final DateTime Function() _clock;
  final Duration latency;
  final Duration preparingAfter;
  final Duration outForDeliveryAfter;
  final Duration deliveredAfter;
  final _random = Random.secure();

  static const _prefix = 'mockdb.';

  // ---------------------------------------------------------------- ApiClient

  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _request('GET', path, query: query);

  @override
  Future<dynamic> post(String path, {Object? body}) =>
      _request('POST', path, body: body);

  @override
  Future<dynamic> put(String path, {Object? body}) =>
      _request('PUT', path, body: body);

  @override
  Future<dynamic> patch(String path, {Object? body}) =>
      _request('PATCH', path, body: body);

  @override
  Future<dynamic> delete(String path) => _request('DELETE', path);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    await _ensureSeeded();
    // Round-trip through JSON like a real network call would.
    final decodedBody = body == null ? null : jsonDecode(jsonEncode(body));
    final result = await _route(
      method,
      Uri.parse(path).pathSegments,
      query ?? const {},
      decodedBody is Map<String, dynamic> ? decodedBody : const {},
    );
    debugPrint('[mock-backend] $method $path');
    return result == null ? null : jsonDecode(jsonEncode(result));
  }

  /// Deletes every mock record (users, carts, orders...) and re-seeds.
  Future<void> resetAll() async {
    await _store.removeWithPrefix(_prefix);
    await _ensureSeeded();
  }

  // ------------------------------------------------------------------ routing

  Future<Object?> _route(
    String method,
    List<String> s,
    Map<String, String> q,
    Map<String, dynamic> body,
  ) async {
    switch ((method, s)) {
      case ('POST', ['auth', 'login']):
        return _login(body);
      case ('POST', ['auth', 'register']):
        return _register(body);
      case ('POST', ['auth', 'logout']):
        return _logout();
      case ('GET', ['auth', 'me']):
        return _publicUser(_requireUser());
      case ('POST', ['auth', 'forgot-password']):
        return _forgotPassword(body);
      case ('POST', ['auth', 'change-password']):
        return _changePassword(body);

      case ('GET', ['restaurants']):
        return _restaurants(q);
      case ('GET', ['restaurants', final id]):
        return _restaurant(id);
      case ('GET', ['offers']):
        return MockSeedData.offers();
      case ('GET', ['notifications']):
        return MockSeedData.notifications(_clock());

      case ('GET', ['addresses']):
        return _addresses(_requireUser()['id'] as String);
      case ('POST', ['addresses', final id, 'select']):
        return _selectAddress(id);

      case ('GET', ['favorites']):
        return _favorites(_requireUser()['id'] as String);
      case ('PUT', ['favorites', final type, final id]):
        return _setFavorite(type, id, true);
      case ('DELETE', ['favorites', final type, final id]):
        return _setFavorite(type, id, false);

      case ('GET', ['cart']):
        return _cartResponse(_requireUser()['id'] as String);
      case ('DELETE', ['cart']):
        return _clearCart();
      case ('POST', ['cart', 'items']):
        return _addCartItem(body);
      case ('PATCH', ['cart', 'items', final id]):
        return _updateCartItem(id, body);
      case ('DELETE', ['cart', 'items', final id]):
        return _removeCartItem(id);
      case ('POST', ['cart', 'coupon']):
        return _applyCoupon(body);
      case ('DELETE', ['cart', 'coupon']):
        return _removeCoupon();
      case ('PUT', ['cart', 'instructions']):
        return _setInstructions(body);

      case ('GET', ['orders']):
        return _orders();
      case ('POST', ['orders']):
        return _placeOrder(body);
      case ('GET', ['orders', final id]):
        return _order(id);
    }
    throw ApiException.fromStatus(404, 'No mock endpoint for $method /${s.join('/')}');
  }

  Never _fail(int status, String message) =>
      throw ApiException.fromStatus(status, message);

  // --------------------------------------------------------------------- auth

  Future<void> _ensureSeeded() async {
    if (_store.getString('${_prefix}seeded') != null) return;
    await _createUser(
      name: MockSeedData.demoName,
      email: MockSeedData.demoEmail,
      phone: MockSeedData.demoPhone,
      password: MockSeedData.demoPassword,
    );
    await _store.setString('${_prefix}seeded', '1');
  }

  Map<String, dynamic> get _users =>
      (_store.readJson('${_prefix}users') as Map<String, dynamic>?) ?? {};

  Map<String, dynamic> get _sessions =>
      (_store.readJson('${_prefix}sessions') as Map<String, dynamic>?) ?? {};

  String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  String _randomHex(int bytes) => List.generate(
        bytes,
        (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();

  Future<Map<String, dynamic>> _createUser({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final users = _users;
    final salt = _randomHex(16);
    final user = {
      'id': 'u_${_randomHex(6)}',
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'salt': salt,
      // Salted SHA-256: keeps plain passwords off disk in the demo. A real
      // backend must use a slow hash (bcrypt/argon2) on the server.
      'passwordHash': _hash(salt, password),
      'createdAt': _clock().toIso8601String(),
    };
    users[user['email']!] = user;
    await _store.writeJson('${_prefix}users', users);
    await _store.writeJson(
      '${_prefix}addresses.${user['id']}',
      {'selectedId': 'home', 'items': MockSeedData.defaultAddresses()},
    );
    return user;
  }

  Map<String, dynamic> _publicUser(Map<String, dynamic> u) => {
        'id': u['id'],
        'name': u['name'],
        'email': u['email'],
        'phone': u['phone'],
      };

  Future<Map<String, dynamic>> _session(Map<String, dynamic> user) async {
    final token = _randomHex(24);
    final sessions = _sessions..[token] = user['email'];
    await _store.writeJson('${_prefix}sessions', sessions);
    return {'token': token, 'user': _publicUser(user)};
  }

  Map<String, dynamic> _requireUser() {
    final token = _token();
    final email = token == null ? null : _sessions[token] as String?;
    final user = email == null ? null : _users[email] as Map<String, dynamic>?;
    if (user == null) _fail(401, 'Please log in to continue.');
    return user;
  }

  String _str(Map<String, dynamic> body, String key) {
    final v = body[key];
    if (v is! String || v.trim().isEmpty) _fail(400, '$key is required.');
    return v;
  }

  Future<Object?> _login(Map<String, dynamic> body) async {
    final email = _str(body, 'email').trim().toLowerCase();
    final password = _str(body, 'password');
    final user = _users[email] as Map<String, dynamic>?;
    if (user == null ||
        user['passwordHash'] != _hash(user['salt'] as String, password)) {
      _fail(401, 'Incorrect email or password.');
    }
    return _session(user);
  }

  Future<Object?> _register(Map<String, dynamic> body) async {
    final email = _str(body, 'email').trim().toLowerCase();
    final password = _str(body, 'password');
    if (password.length < 8) _fail(400, 'Password must be at least 8 characters.');
    if (_users.containsKey(email)) {
      _fail(409, 'An account with this email already exists. Try logging in.');
    }
    final user = await _createUser(
      name: _str(body, 'name'),
      email: email,
      phone: _str(body, 'phone'),
      password: password,
    );
    return _session(user);
  }

  Future<Object?> _logout() async {
    final token = _token();
    if (token != null) {
      await _store.writeJson('${_prefix}sessions', _sessions..remove(token));
    }
    return null;
  }

  Future<Object?> _forgotPassword(Map<String, dynamic> body) async {
    _str(body, 'email');
    // Same response whether or not the account exists. No email is sent.
    return {'message': 'If an account exists, a reset link has been sent.'};
  }

  Future<Object?> _changePassword(Map<String, dynamic> body) async {
    final user = _requireUser();
    final current = _str(body, 'currentPassword');
    final next = _str(body, 'newPassword');
    if (user['passwordHash'] != _hash(user['salt'] as String, current)) {
      _fail(400, 'Current password is incorrect.');
    }
    if (current == next) {
      _fail(400, 'New password must be different from the current one.');
    }
    if (next.length < 8) _fail(400, 'Password must be at least 8 characters.');
    final salt = _randomHex(16);
    final users = _users;
    users[user['email'] as String] = {
      ...user,
      'salt': salt,
      'passwordHash': _hash(salt, next),
    };
    await _store.writeJson('${_prefix}users', users);
    return {'message': 'Password updated.'};
  }

  // --------------------------------------------------------------- catalogue

  List<Map<String, dynamic>> _restaurants(Map<String, String> q) {
    var list = MockSeedData.restaurants();
    if (q['popular'] == 'true') {
      list = list.where((r) => r['popular'] == true).toList();
    }
    final query = q['q']?.trim().toLowerCase();
    if (query != null && query.isNotEmpty) {
      list = list.where((r) {
        final text = [r['name'], ...(r['cuisines'] as List)]
            .join(' ')
            .toLowerCase();
        return text.contains(query);
      }).toList();
    }
    if (q['sort'] == 'distance') {
      list.sort(
        (a, b) => (a['distanceKm'] as num).compareTo(b['distanceKm'] as num),
      );
    }
    return list;
  }

  Map<String, dynamic> _restaurant(String id) =>
      MockSeedData.restaurants().firstWhere(
        (r) => r['id'] == id,
        orElse: () => _fail(404, 'This restaurant is no longer available.'),
      );

  // --------------------------------------------------------------- user data

  Map<String, dynamic> _addresses(String uid) =>
      (_store.readJson('${_prefix}addresses.$uid') as Map<String, dynamic>?) ??
      {'selectedId': 'home', 'items': MockSeedData.defaultAddresses()};

  Future<Object?> _selectAddress(String id) async {
    final uid = _requireUser()['id'] as String;
    final data = _addresses(uid);
    final exists = (data['items'] as List).any((a) => (a as Map)['id'] == id);
    if (!exists) _fail(404, 'Address not found.');
    data['selectedId'] = id;
    await _store.writeJson('${_prefix}addresses.$uid', data);
    return data;
  }

  Map<String, dynamic> _favorites(String uid) =>
      (_store.readJson('${_prefix}favorites.$uid') as Map<String, dynamic>?) ??
      {'restaurants': <String>[], 'dishes': <String>[]};

  Future<Object?> _setFavorite(String type, String id, bool on) async {
    final uid = _requireUser()['id'] as String;
    final key = switch (type) {
      'restaurant' => 'restaurants',
      'dish' => 'dishes',
      _ => _fail(400, 'Unknown favourite type "$type".'),
    };
    final data = _favorites(uid);
    final set = {...(data[key] as List).cast<String>()};
    on ? set.add(id) : set.remove(id);
    data[key] = set.toList();
    await _store.writeJson('${_prefix}favorites.$uid', data);
    return data;
  }

  // -------------------------------------------------------------------- cart

  String _cartKey(String uid) => '${_prefix}cart.$uid';

  Map<String, dynamic> _cart(String uid) =>
      (_store.readJson(_cartKey(uid)) as Map<String, dynamic>?) ??
      {'items': <Map<String, dynamic>>[], 'couponCode': null, 'instructions': ''};

  Future<void> _saveCart(String uid, Map<String, dynamic> cart) =>
      _store.writeJson(_cartKey(uid), cart);

  static double _round2(num v) => (v * 100).round() / 100;

  ({int discount, String? message}) _couponDiscount(
    String uid,
    String? code,
    int itemTotal,
  ) {
    if (code == null || itemTotal == 0) return (discount: 0, message: null);
    final offer = MockSeedData.offers().firstWhere(
      (o) => o['code'] == code,
      orElse: () => const {},
    );
    if (offer.isEmpty) return (discount: 0, message: '$code is no longer valid.');
    final minOrder = offer['minOrder'] as int? ?? 0;
    if (itemTotal < minOrder) {
      return (
        discount: 0,
        message: 'Add ₹${minOrder - itemTotal} more to use $code',
      );
    }
    final maxOrders = offer['maxOrdersPerUser'] as int?;
    if (maxOrders != null && _orderList(uid).length >= maxOrders) {
      return (
        discount: 0,
        message: '$code is only valid on your first $maxOrders orders',
      );
    }
    final value = offer['value'] as int;
    final discount = offer['type'] == 'percent'
        ? min((itemTotal * value / 100).floor(), offer['maxDiscount'] as int? ?? itemTotal)
        : min(value, itemTotal);
    return (discount: discount, message: null);
  }

  Map<String, dynamic> _cartResponse(String uid) {
    final cart = _cart(uid);
    final items = (cart['items'] as List).cast<Map<String, dynamic>>();
    final restaurant = items.isEmpty
        ? null
        : MockSeedData.restaurants().firstWhere(
            (r) => r['id'] == items.first['restaurantId'],
            orElse: () => const {},
          );
    final itemTotal = items.fold<int>(
      0,
      (sum, i) => sum + (i['unitPrice'] as int) * (i['quantity'] as int),
    );
    final fee = restaurant?['deliveryFee'] as int? ?? 0;
    final standardFee = fee == 0 ? MockSeedData.standardDeliveryFee : fee;
    final free = itemTotal >= MockSeedData.freeDeliveryThreshold;
    final deliveryFee = items.isEmpty || free ? 0 : standardFee;
    final taxes = _round2(itemTotal * MockSeedData.taxRatePercent / 100);
    final coupon = _couponDiscount(uid, cart['couponCode'] as String?, itemTotal);
    final total = max(0, _round2(itemTotal + deliveryFee + taxes - coupon.discount));

    return {
      'items': items,
      'restaurant': restaurant == null || restaurant.isEmpty
          ? null
          : {
              'id': restaurant['id'],
              'name': restaurant['name'],
              'distanceKm': restaurant['distanceKm'],
            },
      'couponCode': cart['couponCode'],
      'couponMessage': coupon.message,
      'instructions': cart['instructions'] ?? '',
      'totals': {
        'itemTotal': itemTotal,
        'deliveryFee': deliveryFee,
        'standardDeliveryFee': items.isEmpty ? 0 : standardFee,
        'freeDeliveryThreshold': MockSeedData.freeDeliveryThreshold,
        'taxes': taxes,
        'taxRatePercent': MockSeedData.taxRatePercent,
        'discount': coupon.discount,
        'total': total,
        'savings': coupon.discount + (free && items.isNotEmpty ? standardFee : 0),
      },
    };
  }

  Future<Object?> _clearCart() async {
    final uid = _requireUser()['id'] as String;
    final cart = _cart(uid)
      ..['items'] = <Map<String, dynamic>>[]
      ..['instructions'] = '';
    await _saveCart(uid, cart);
    return _cartResponse(uid);
  }

  Future<Object?> _addCartItem(Map<String, dynamic> body) async {
    final uid = _requireUser()['id'] as String;
    final restaurantId = _str(body, 'restaurantId');
    _restaurant(restaurantId); // 404 if unknown
    final quantity = body['quantity'];
    if (quantity is! int || quantity < 1 || quantity > 20) {
      _fail(400, 'Quantity must be between 1 and 20.');
    }
    if (body['unitPrice'] is! int || body['recipeId'] is! int) {
      _fail(400, 'recipeId and unitPrice are required.');
    }

    final cart = _cart(uid);
    var items = (cart['items'] as List).cast<Map<String, dynamic>>();
    if (items.isNotEmpty && items.first['restaurantId'] != restaurantId) {
      if (body['replaceCart'] != true) {
        _fail(409, 'Your cart has items from another restaurant.');
      }
      items = [];
      cart['instructions'] = '';
    }

    final line = {
      'recipeId': body['recipeId'],
      'restaurantId': restaurantId,
      'name': _str(body, 'name'),
      'image': body['image'] ?? '',
      'isVeg': body['isVeg'] == true,
      'unitPrice': body['unitPrice'],
      'quantity': quantity,
      'portion': body['portion'],
      'spiceLevel': body['spiceLevel'],
      'addOns': body['addOns'] ?? <String>[],
      'note': body['note'],
    };
    String config(Map<String, dynamic> l) => [
          l['recipeId'],
          l['portion'],
          l['spiceLevel'],
          ...(l['addOns'] as List),
          l['note'],
        ].join('|');

    final existing = items.where((i) => config(i) == config(line));
    if (existing.isNotEmpty) {
      final merged = existing.first;
      merged['quantity'] = min(20, (merged['quantity'] as int) + quantity);
    } else {
      items.add({'id': 'l_${_randomHex(5)}', ...line});
    }
    cart['items'] = items;
    await _saveCart(uid, cart);
    return _cartResponse(uid);
  }

  Future<Object?> _updateCartItem(String id, Map<String, dynamic> body) async {
    final uid = _requireUser()['id'] as String;
    final quantity = body['quantity'];
    if (quantity is! int || quantity < 0 || quantity > 20) {
      _fail(400, 'Quantity must be between 0 and 20.');
    }
    final cart = _cart(uid);
    final items = (cart['items'] as List).cast<Map<String, dynamic>>();
    final index = items.indexWhere((i) => i['id'] == id);
    if (index < 0) _fail(404, 'That item is no longer in your cart.');
    if (quantity == 0) {
      items.removeAt(index);
    } else {
      items[index]['quantity'] = quantity;
    }
    await _saveCart(uid, cart);
    return _cartResponse(uid);
  }

  Future<Object?> _removeCartItem(String id) async {
    final uid = _requireUser()['id'] as String;
    final cart = _cart(uid);
    (cart['items'] as List).removeWhere((i) => (i as Map)['id'] == id);
    await _saveCart(uid, cart);
    return _cartResponse(uid);
  }

  Future<Object?> _applyCoupon(Map<String, dynamic> body) async {
    final uid = _requireUser()['id'] as String;
    final code = _str(body, 'code').trim().toUpperCase();
    final known = MockSeedData.offers().any((o) => o['code'] == code);
    if (!known) _fail(400, 'Invalid coupon code.');
    await _saveCart(uid, _cart(uid)..['couponCode'] = code);
    return _cartResponse(uid);
  }

  Future<Object?> _removeCoupon() async {
    final uid = _requireUser()['id'] as String;
    await _saveCart(uid, _cart(uid)..['couponCode'] = null);
    return _cartResponse(uid);
  }

  Future<Object?> _setInstructions(Map<String, dynamic> body) async {
    final uid = _requireUser()['id'] as String;
    final text = (body['instructions'] as String? ?? '').trim();
    if (text.length > 150) _fail(400, 'Instructions are limited to 150 characters.');
    await _saveCart(uid, _cart(uid)..['instructions'] = text);
    return _cartResponse(uid);
  }

  // ------------------------------------------------------------------ orders

  List<Map<String, dynamic>> _orderList(String uid) =>
      ((_store.readJson('${_prefix}orders.$uid') as List?) ?? const [])
          .cast<Map<String, dynamic>>();

  /// Status is derived from elapsed time, so tracking keeps advancing even
  /// across app restarts (on an accelerated demo timeline).
  Map<String, dynamic> _withStatus(Map<String, dynamic> order) {
    final placed = DateTime.parse(order['placedAt'] as String);
    final elapsed = _clock().difference(placed);
    final steps = [
      ('preparing', preparingAfter),
      ('outForDelivery', outForDeliveryAfter),
      ('delivered', deliveredAfter),
    ];
    var status = 'placed';
    final times = {'placed': order['placedAt']};
    for (final (name, after) in steps) {
      if (elapsed >= after) {
        status = name;
        times[name] = placed.add(after).toIso8601String();
      }
    }
    return {...order, 'status': status, 'statusTimes': times};
  }

  List<Map<String, dynamic>> _orders() {
    final uid = _requireUser()['id'] as String;
    final list = _orderList(uid).map(_withStatus).toList()
      ..sort((a, b) => (b['placedAt'] as String).compareTo(a['placedAt'] as String));
    return list;
  }

  Map<String, dynamic> _order(String id) {
    final uid = _requireUser()['id'] as String;
    final order = _orderList(uid).firstWhere(
      (o) => o['id'] == id,
      orElse: () => _fail(404, 'We couldn’t find this order.'),
    );
    return _withStatus(order);
  }

  Future<Object?> _placeOrder(Map<String, dynamic> body) async {
    final user = _requireUser();
    final uid = user['id'] as String;
    final cart = _cartResponse(uid);
    final items = cart['items'] as List;
    if (items.isEmpty) _fail(400, 'Your cart is empty.');

    final addressId = body['addressId'];
    final address = (_addresses(uid)['items'] as List)
        .cast<Map<String, dynamic>>()
        .where((a) => a['id'] == addressId)
        .firstOrNull;
    if (address == null) _fail(400, 'Please choose a delivery address.');

    const methods = {'upi', 'card', 'cod'};
    final payment = body['paymentMethod'];
    if (payment is! String || !methods.contains(payment)) {
      _fail(400, 'Please choose a payment method.');
    }

    final restaurant = _restaurant(
      (cart['restaurant'] as Map<String, dynamic>)['id'] as String,
    );
    final now = _clock();
    final maxMinutes = int.tryParse(
          (restaurant['deliveryTime'] as String).split(RegExp(r'[^0-9]+'))[1],
        ) ??
        30;
    final orders = _orderList(uid);
    String newId() => 'AF-${10000 + _random.nextInt(89999)}';
    var id = newId();
    while (orders.any((o) => o['id'] == id)) {
      id = newId();
    }

    final order = {
      'id': id,
      'restaurant': {
        'id': restaurant['id'],
        'name': restaurant['name'],
        'imageUrl': restaurant['imageUrl'],
        'distanceKm': restaurant['distanceKm'],
        'deliveryTime': restaurant['deliveryTime'],
      },
      'items': items,
      'amount': (cart['totals'] as Map)['total'],
      'couponCode': cart['couponCode'],
      'instructions': cart['instructions'],
      'address': address,
      'paymentMethod': payment,
      'placedAt': now.toIso8601String(),
      'eta': now.add(Duration(minutes: maxMinutes)).toIso8601String(),
    };
    await _store.writeJson('${_prefix}orders.$uid', [...orders, order]);
    await _saveCart(uid, {
      'items': <Map<String, dynamic>>[],
      'couponCode': null,
      'instructions': '',
    });
    return _withStatus(order);
  }
}
