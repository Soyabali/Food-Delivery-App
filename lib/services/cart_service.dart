import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/api/endpoints.dart';
import '../data/models.dart';

/// Result of adding to cart: either the updated cart, or a conflict because
/// the cart already holds another restaurant's food (HTTP 409).
sealed class AddToCartOutcome {
  const AddToCartOutcome();
}

class AddedToCart extends AddToCartOutcome {
  const AddedToCart(this.cart);
  final Cart cart;
}

class CartConflict extends AddToCartOutcome {
  const CartConflict(this.message);
  final String message;
}

/// Server-side cart. Every call returns the full cart including totals, so
/// subtotal/fees/discounts are always calculated by the backend.
class CartService {
  CartService(this._backend);

  final ApiClient _backend;

  Cart _parse(Object? json) {
    if (json is! Map) throw ApiException.invalidResponse;
    return Cart.fromJson(json.cast<String, dynamic>());
  }

  Future<Cart> getCart() async => _parse(await _backend.get(BackendEndpoints.cart));

  Future<AddToCartOutcome> addItem(AddToCartRequest request) async {
    try {
      final json = await _backend.post(
        BackendEndpoints.cartItems,
        body: request.toJson(),
      );
      return AddedToCart(_parse(json));
    } on ApiException catch (e) {
      if (e.statusCode == 409) return CartConflict(e.message);
      rethrow;
    }
  }

  /// Re-adds a removed line (used by "Undo").
  Future<Cart> restoreLine(CartLine line) async => _parse(
        await _backend.post(
          BackendEndpoints.cartItems,
          body: {...line.toJson()..remove('id'), 'replaceCart': false},
        ),
      );

  Future<Cart> updateQuantity(String lineId, int quantity) async => _parse(
        await _backend.patch(
          BackendEndpoints.cartItem(lineId),
          body: {'quantity': quantity},
        ),
      );

  Future<Cart> removeItem(String lineId) async =>
      _parse(await _backend.delete(BackendEndpoints.cartItem(lineId)));

  Future<Cart> clear() async => _parse(await _backend.delete(BackendEndpoints.cart));

  Future<Cart> applyCoupon(String code) async => _parse(
        await _backend.post(BackendEndpoints.cartCoupon, body: {'code': code}),
      );

  Future<Cart> removeCoupon() async =>
      _parse(await _backend.delete(BackendEndpoints.cartCoupon));

  Future<Cart> setInstructions(String text) async => _parse(
        await _backend.put(
          BackendEndpoints.cartInstructions,
          body: {'instructions': text},
        ),
      );
}
