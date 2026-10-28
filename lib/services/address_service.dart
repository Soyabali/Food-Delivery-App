import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/api/endpoints.dart';
import '../data/models.dart';

typedef AddressBook = ({List<DeliveryAddress> items, String selectedId});

/// Saved delivery addresses for the signed-in user (backend).
class AddressService {
  AddressService(this._backend);

  final ApiClient _backend;

  AddressBook _parse(Object? json) {
    if (json is! Map || json['items'] is! List) {
      throw ApiException.invalidResponse;
    }
    return (
      items: (json['items'] as List)
          .map((e) => DeliveryAddress.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      selectedId: json['selectedId'] as String,
    );
  }

  Future<AddressBook> getAddresses() async =>
      _parse(await _backend.get(BackendEndpoints.addresses));

  Future<AddressBook> select(String id) async =>
      _parse(await _backend.post(BackendEndpoints.selectAddress(id)));
}
