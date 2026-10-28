import 'package:flutter/foundation.dart';

import '../core/api/api_exception.dart';
import '../data/models.dart';
import '../services/address_service.dart';
import '../services/user_service.dart';

/// Signed-in user's addresses and favourites (backend), plus the purely
/// local notification toggle.
class PreferencesController extends ChangeNotifier {
  PreferencesController(
    this._addresses,
    this._users, {
    required this.onUnauthorized,
  });

  final AddressService _addresses;
  final UserService _users;
  final Future<void> Function() onUnauthorized;

  List<DeliveryAddress> _items = const [];
  String? _selectedId;
  Favorites _favorites = const Favorites();
  bool _notificationsEnabled = true;
  bool _loading = false;
  ApiException? _error;

  List<DeliveryAddress> get addresses => _items;
  DeliveryAddress? get address =>
      _items.where((a) => a.id == _selectedId).firstOrNull ?? _items.firstOrNull;
  Favorites get favorites => _favorites;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get isLoading => _loading;
  ApiException? get error => _error;

  bool isFavourite(FavoriteType type, String id) => switch (type) {
        FavoriteType.restaurant => _favorites.restaurants.contains(id),
        FavoriteType.dish => _favorites.dishes.contains(id),
      };

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
      final results = await _guard(
        () => Future.wait([_addresses.getAddresses(), _users.getFavorites()]),
      );
      final book = results[0] as AddressBook;
      _items = book.items;
      _selectedId = book.selectedId;
      _favorites = results[1] as Favorites;
    } on ApiException catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> selectAddress(DeliveryAddress address) async {
    final book = await _guard(() => _addresses.select(address.id));
    _items = book.items;
    _selectedId = book.selectedId;
    notifyListeners();
  }

  /// Optimistic toggle; reverts and rethrows if the backend rejects it.
  /// Returns the new state.
  Future<bool> toggleFavourite(FavoriteType type, String id) async {
    final before = _favorites;
    final next = !isFavourite(type, id);
    _favorites = Favorites(
      restaurants: type == FavoriteType.restaurant
          ? ({...before.restaurants}..toggle(id, next))
          : before.restaurants,
      dishes: type == FavoriteType.dish
          ? ({...before.dishes}..toggle(id, next))
          : before.dishes,
    );
    notifyListeners();
    try {
      _favorites = await _guard(() => _users.setFavorite(type, id, next));
      notifyListeners();
      return next;
    } catch (_) {
      _favorites = before;
      notifyListeners();
      rethrow;
    }
  }

  void setNotifications(bool enabled) {
    _notificationsEnabled = enabled;
    notifyListeners();
  }

  void reset() {
    _items = const [];
    _selectedId = null;
    _favorites = const Favorites();
    _error = null;
    notifyListeners();
  }
}

extension on Set<String> {
  void toggle(String id, bool add) => add ? this.add(id) : remove(id);
}
