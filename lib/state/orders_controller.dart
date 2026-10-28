import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../data/models.dart';
import '../services/order_service.dart';

/// Order history for the Orders tab, plus placing new orders.
class OrdersController extends ChangeNotifier {
  OrdersController(this._service, {required this.onUnauthorized});

  final OrderService _service;
  final Future<void> Function() onUnauthorized;

  List<Order> _orders = const [];
  bool _loading = false;
  bool _loaded = false;
  ApiException? _error;

  List<Order> get orders => _orders;
  List<Order> get active => _orders.where((o) => o.isActive).toList();
  List<Order> get past => _orders.where((o) => !o.isActive).toList();
  bool get isLoading => _loading;
  bool get hasLoaded => _loaded;
  ApiException? get error => _error;

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
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _orders = await _guard(_service.getOrders);
      _loaded = true;
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Order> place({
    required String addressId,
    required PaymentMethod payment,
  }) async {
    final order = await _guard(
      () => _service.placeOrder(addressId: addressId, payment: payment),
    );
    _orders = [order, ..._orders];
    notifyListeners();
    return order;
  }

  /// Fetches the latest state of one order (used by tracking polling).
  Future<Order> refresh(String id) async {
    final order = await _guard(() => _service.getOrder(id));
    final index = _orders.indexWhere((o) => o.id == id);
    if (index >= 0) {
      _orders = [..._orders]..[index] = order;
      notifyListeners();
    }
    return order;
  }

  void reset() {
    _orders = const [];
    _loaded = false;
    _error = null;
    notifyListeners();
  }
}
