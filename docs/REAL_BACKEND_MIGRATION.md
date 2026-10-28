# Migrating to a Real Backend

The goal: implement the contract in `API_ENDPOINTS.md` on your server, flip a
setting, and keep every screen unchanged.

## Files you will touch

| Change | File(s) |
|---|---|
| URLs / mode | `.env` (or `--dart-define`), defaults in `lib/core/config/app_config.dart` |
| Endpoint paths | `lib/core/api/endpoints.dart` |
| Headers, auth scheme, timeouts, error parsing | `lib/core/api/api_client.dart`, `lib/core/api/api_exception.dart` |
| Request payloads / response mapping | `lib/services/*.dart`, `fromJson` in `lib/data/models.dart` |
| Menu data (if your API has real menus) | `lib/services/food_service.dart`, `lib/data/adapters/recipe_adapter.dart` |
| Token storage | `lib/services/session_store.dart` |

**Unchanged:** everything in `lib/features/` (screens), `lib/core/widgets/`,
the router, and the controllers' public APIs.

## 1. Base URL and mode

```bash
# .env
BACKEND_MODE=http
BACKEND_BASE_URL=https://api.apnafood.com/v1
```

`AppServices.create()` then builds an `HttpApiClient` instead of `MockBackend`.
Remove `lib/data/mock_backend/` once you no longer need offline demos.

## 2. Endpoint paths

If your routes differ, change only the constants:

```dart
// lib/core/api/endpoints.dart
static const login = '/auth/login';        // → '/v1/sessions'
static String order(String id) => '/orders/$id';
```

## 3. Authentication header

`HttpApiClient` sends `Authorization: Bearer <token>`. For a different scheme,
edit `_headers()`:

```dart
if (token != null) 'X-Api-Token': token,
```

Static public headers (an app version, say) go in `defaultHeaders:` when constructing the client.

## 4. Request payloads

Payloads are built in services or model `toJson()`. For example, if your server
expects `item_id` instead of `recipeId`:

```dart
// lib/data/models.dart — AddToCartRequest.toJson()
'item_id': dish.id,
```

**Server-side pricing:** stop sending `unitPrice`, and let the server look up
the price from `item_id` plus the selected options.

## 5. Response adapters

If your JSON uses different names, adapt `fromJson` only:

```dart
factory Restaurant.fromJson(Map<String, dynamic> j) => Restaurant(
  id: j['id'].toString(),
  image: j['cover_image_url'] as String,   // was imageUrl
  ...
);
```

If your API wraps payloads (`{ "data": {...} }`), unwrap once in
`HttpApiClient._send` (return `json['data']`) instead of in every service.

**Real menus:** replace `FoodService.menuFor` and `getDish` with calls to your
menu endpoints and map them straight to `Dish`. Then `PricingPolicy`,
`VegClassifier` and `RestaurantService.resolveForRecipe` can be deleted.

## 6. Error handling

`ApiException.fromStatus` reads `{ "message": "…" }`. If your errors look like
`{ "error": { "detail": "…" } }`, change the one line in `_send`:

```dart
final message = json is Map ? (json['error']?['detail'] ?? json['message'])?.toString() : null;
```

Keep 409 for "cart has another restaurant" or update `CartService.addItem`.

## 7. Token expiry

- Any 401 already logs the user out: controllers call
  `AuthController.expireSession()`, and the router redirects to Login.
- For refresh tokens, catch `unauthorized` in `HttpApiClient._send`, call your
  refresh endpoint once, save the new token with `SessionStore.save`, and retry
  the request. Only if the refresh fails should the 401 propagate.
- Move tokens to secure storage: add `flutter_secure_storage` and swap
  `LocalStore` for it inside `SessionStore`. The API stays the same.

## 8. Cart and order persistence

With a real backend the cart and orders are server-side, so they follow the
user across devices automatically. Nothing changes in the app, because it
already treats the backend as the source of truth: every cart call returns
the full cart with totals, and orders are created from the server cart via
`POST /orders`. Move the totals and coupon rules from `MockBackend._cartResponse`
into your server.

## 9. Verify

1. Run the contract test idea from `test/services_test.dart`
   (`BACKEND_MODE=http: services work unchanged…`) against a staging server.
2. Walk the flows in `TESTING_GUIDE.md` with `BACKEND_MODE=http`.
3. Check the debug console for `[api]` log lines (network failures are logged there).
