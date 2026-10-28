# API Architecture

Apna Food is a Flutter app. All business data reaches the UI through one
layered path. Screens never build URLs, parse JSON, or read mock data.

```text
Screen / Widget            lib/features/**            (UI only)
   │  context.read / watch
   ▼
Controller or RequestBuilder  lib/state/*_controller.dart, lib/core/widgets/async_view.dart
   │  calls
   ▼
Service                    lib/services/*_service.dart   (one per feature)
   │  ApiClient.get/post/put/patch/delete(path)
   ▼
ApiClient                  lib/core/api/api_client.dart
   ├── HttpApiClient ──► DummyJSON (https://dummyjson.com)      ← real HTTP, always
   └── MockBackend   ──► on-device "server" + SharedPreferences  ← BACKEND_MODE=mock
       HttpApiClient ──► your backend (BACKEND_BASE_URL)          ← BACKEND_MODE=http
   │  JSON
   ▼
Adapter / fromJson         lib/data/adapters/recipe_adapter.dart, lib/data/models.dart
   │  app models (Dish, Cart, Order …)
   ▼
UI state update            ChangeNotifier.notifyListeners() / RequestBuilder setState
```

## The two data sources

| Source | Client | What it provides |
|---|---|---|
| **Food API** (DummyJSON) | `HttpApiClient(baseUrl: FOOD_API_BASE_URL)` | Recipes → dishes, images, ratings, ingredients, tags (categories), meal types, search |
| **Backend** (mock or real) | `MockBackend` or `HttpApiClient(baseUrl: BACKEND_BASE_URL)` | Auth, profile, restaurants, offers, notifications, addresses, favourites, cart + totals, orders + status |

Both implement the same interface:

```dart
// lib/core/api/api_client.dart
abstract interface class ApiClient {
  Future<dynamic> get(String path, {Map<String, String>? query});
  Future<dynamic> post(String path, {Object? body});
  Future<dynamic> put(String path, {Object? body});
  Future<dynamic> patch(String path, {Object? body});
  Future<dynamic> delete(String path);
}
```

The **only** place that chooses mock or real is the composition root:

```dart
// lib/app/app.dart — AppServices.create()
final ApiClient backend = cfg.isMockBackend
    ? MockBackend(store: local, tokenProvider: () => session.token, latency: cfg.mockLatency)
    : HttpApiClient(baseUrl: cfg.backendBaseUrl, timeout: cfg.requestTimeout,
                    tokenProvider: () => session.token);
```

## Layers and responsibilities

| Layer | Files | Rules |
|---|---|---|
| Config | `lib/core/config/app_config.dart` | Reads `--dart-define` values. No URL appears anywhere else. |
| Endpoints | `lib/core/api/endpoints.dart` | Every path (`FoodEndpoints`, `BackendEndpoints`). |
| Transport | `lib/core/api/api_client.dart`, `api_exception.dart` | HTTP, headers, JSON, timeouts, and status → `ApiException`. |
| Mock server | `lib/data/mock_backend/` | Business rules a real backend owns: auth, totals, coupons, order status. |
| Adapters | `lib/data/adapters/recipe_adapter.dart` | DummyJSON recipe → `Dish` (demo price, veg heuristic, description). |
| Models | `lib/data/models.dart`, `lib/core/auth/auth_state.dart` | App shapes with `fromJson`. |
| Services | `lib/services/` | One per feature; call `ApiClient`, return models, throw `ApiException`. |
| State | `lib/state/` | `ChangeNotifier`s for long-lived data (auth, cart, orders, addresses/favourites). |
| UI | `lib/features/` | Render state. Loading, error, empty and retry come from `async_view.dart`. |

## Why this makes the real backend easy

1. **Same paths, same JSON.** `MockBackend` answers exactly the routes in
   `BackendEndpoints` with the JSON shapes in `docs/API_ENDPOINTS.md`. A real
   server that implements that contract plugs in by setting `BACKEND_MODE=http`.
   The test `BACKEND_MODE=http: services work unchanged over real HTTP` in
   `test/services_test.dart` runs the services through `HttpApiClient`
   (real JSON, headers and status codes) to prove it.
2. **Errors are normalised once.** Services and screens only ever see
   `ApiException` (`network`, `timeout`, `unauthorized`, `notFound`,
   `badRequest`, `server`, `invalidResponse`).
3. **Provider quirks live in adapters.** DummyJSON has no prices, so
   `PricingPolicy` invents them in one place. A real menu API would delete
   that code and leave screens untouched.
4. **Business rules are on the "server".** Subtotal, delivery fee, tax,
   coupons and order status are calculated by the backend and returned in the
   response. The app only displays them, as it would with a real backend.
