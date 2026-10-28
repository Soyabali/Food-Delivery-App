import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/api/endpoints.dart';
import '../data/models.dart';

/// Order placement (from the server-side cart), history and tracking.
/// No payment provider is involved in this phase.
class OrderService {
  OrderService(this._backend);

  final ApiClient _backend;

  Order _parse(Object? json) {
    if (json is! Map) throw ApiException.invalidResponse;
    return Order.fromJson(json.cast<String, dynamic>());
  }

  Future<Order> placeOrder({
    required String addressId,
    required PaymentMethod payment,
  }) async =>
      _parse(
        await _backend.post(
          BackendEndpoints.orders,
          body: {'addressId': addressId, 'paymentMethod': payment.name},
        ),
      );

  Future<List<Order>> getOrders() async {
    final json = await _backend.get(BackendEndpoints.orders);
    if (json is! List) throw ApiException.invalidResponse;
    return json.map(_parse).toList();
  }

  Future<Order> getOrder(String id) async =>
      _parse(await _backend.get(BackendEndpoints.order(id)));
}
