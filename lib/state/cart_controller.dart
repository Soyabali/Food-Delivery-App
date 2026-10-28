import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../data/models.dart';
import '../services/cart_service.dart';

/// Mirrors the server-side cart. Every mutation goes through [CartService]
/// and replaces [cart] with the backend's response (including totals).
/// Mutations throw [ApiException]; screens show the message.
class CartController extends ChangeNotifier {
  CartController(this._service, {required this.onUnauthorized});

  final CartService _service;
  final Future<void> Function() onUnauthorized;

  Cart _cart = Cart.empty;
  bool _loading = false;
  bool _busy = false;
  ApiException? _error;

  Cart get cart => _cart;
  bool get isLoading => _loading;

  /// A mutation is in flight; buttons should be disabled.
  bool get isBusy => _busy;
  ApiException? get error => _error;

  // Convenience getters used by widgets.
  bool get isEmpty => _cart.isEmpty;
  int get totalQuantity => _cart.totalQuantity;

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      final error = toApiException(e);
      if (error.type == ApiErrorType.unauthorized) await onUnauthorized();
      throw error;
    }
  }

  Future<void> load() async {
    if (_loading) return; // prevent duplicate requests
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _cart = await _guard(_service.getCart);
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _mutate(Future<Cart> Function() action) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      _cart = await _guard(action);
      _error = null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<AddToCartOutcome> add(AddToCartRequest request) async {
    _busy = true;
    notifyListeners();
    try {
      final outcome = await _guard(() => _service.addItem(request));
      if (outcome is AddedToCart) _cart = outcome.cart;
      return outcome;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> setQuantity(CartLine line, int quantity) =>
      _mutate(() => _service.updateQuantity(line.id, quantity));

  Future<void> remove(CartLine line) => _mutate(() => _service.removeItem(line.id));

  Future<void> restore(CartLine line) => _mutate(() => _service.restoreLine(line));

  Future<void> clear() => _mutate(_service.clear);

  /// Adds a past order's lines to the cart, optionally clearing it first.
  Future<void> reorder(List<CartLine> lines, {bool replace = false}) =>
      _mutate(() async {
        var cart = replace ? await _service.clear() : _cart;
        for (final line in lines) {
          cart = await _service.restoreLine(line);
        }
        return cart;
      });

  Future<void> applyCoupon(String code) => _mutate(() => _service.applyCoupon(code));

  Future<void> removeCoupon() => _mutate(_service.removeCoupon);

  Future<void> setInstructions(String text) =>
      _mutate(() => _service.setInstructions(text));

  /// After an order is placed the backend has emptied the cart.
  void markEmpty() {
    _cart = Cart.empty;
    notifyListeners();
  }

  void reset() {
    _cart = Cart.empty;
    _error = null;
    notifyListeners();
  }
}
