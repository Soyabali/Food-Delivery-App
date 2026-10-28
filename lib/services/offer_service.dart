import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/api/endpoints.dart';
import '../data/models.dart';

/// Promotional offers / coupons and in-app notifications (backend).
class OfferService {
  OfferService(this._backend);

  final ApiClient _backend;

  Future<List<Offer>> getOffers() async {
    final json = await _backend.get(BackendEndpoints.offers);
    if (json is! List) throw ApiException.invalidResponse;
    return json
        .map((e) => Offer.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// The highlighted offer (home banner), or null if none is featured.
  Future<Offer?> getFeaturedOffer() async =>
      (await getOffers()).where((o) => o.featured).firstOrNull;

  Future<List<AppNotification>> getNotifications() async {
    final json = await _backend.get(BackendEndpoints.notifications);
    if (json is! List) throw ApiException.invalidResponse;
    return json
        .map((e) => AppNotification.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}
