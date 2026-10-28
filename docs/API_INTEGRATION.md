# API Integration

How a request travels from a screen to an API and back, using the code that
ships in this repo.

## 1. The API client

`HttpApiClient` (`lib/core/api/api_client.dart`) wraps `package:http`:

- joins `baseUrl` + path and adds query parameters
- sets `Accept: application/json`, plus `Content-Type` for bodies
- adds `Authorization: Bearer <token>` when `tokenProvider` returns one
- applies `AppConfig.requestTimeout` to both the connection and the body read
- decodes UTF-8 JSON (empty body → `null`)
- converts failures into `ApiException`:

| Situation | `ApiErrorType` | Message shown |
|---|---|---|
| No connection / DNS failure | `network` | "No internet connection…" |
| Took longer than timeout | `timeout` | "The request took too long…" |
| 401 | `unauthorized` | server message or "Your session has expired…" |
| 404 | `notFound` | server message |
| Other 4xx | `badRequest` | server message (e.g. "Invalid coupon code.") |
| 5xx | `server` | generic, never server internals |
| Non-JSON 2xx / wrong shape | `invalidResponse` | "We received an unexpected response…" |

`MockBackend` implements the same `ApiClient` interface and throws the same
`ApiException`s, so callers cannot tell them apart.

## 2. Services

Each feature has one service in `lib/services/`. A service calls the client
with a path from `endpoints.dart`, validates the shape, and returns models:

```dart
// lib/services/food_service.dart
Future<List<Dish>> search(String query) async {
  final json = await _foodApi.get(FoodEndpoints.search, query: {'q': query});
  return _toDishes(RecipeAdapter.recipeList(json));   // throws invalidResponse on bad shape
}
```

```dart
// lib/services/cart_service.dart — a 409 becomes a typed outcome, not an error
Future<AddToCartOutcome> addItem(AddToCartRequest request) async {
  try {
    return AddedToCart(_parse(await _backend.post(BackendEndpoints.cartItems, body: request.toJson())));
  } on ApiException catch (e) {
    if (e.statusCode == 409) return CartConflict(e.message);
    rethrow;
  }
}
```

## 3. Calling services from screens

**One-off screen data** uses `RequestBuilder`
(`lib/core/widgets/async_view.dart`), which handles loading, error with Retry,
empty and data states:

```dart
// lib/features/home/home_screen.dart
RequestBuilder<List<Dish>>(
  requestKey: _refreshKey,                         // pull-to-refresh bumps this
  request: () => food.getTopRated(limit: 8),
  loading: /* skeleton cards */,
  compactError: true,                              // inline error + Retry
  isEmpty: (d) => d.isEmpty,
  builder: (context, dishes) => /* carousel */,
)
```

**Long-lived user data** (auth, cart, orders, addresses and favourites) lives in
`ChangeNotifier` controllers (`lib/state/`), loaded on sign-in by
`ApnaFoodApp._onAuthChanged`. Screens `watch` them:

```dart
// lib/features/cart/cart_screen.dart
final controller = context.watch<CartController>();
if (controller.isLoading && cart.isEmpty)      content = const ListSkeleton(count: 3);
else if (controller.error != null && cart.isEmpty) content = ErrorView(error: controller.error!, onRetry: controller.load);
else if (cart.isEmpty)                          content = /* empty state */;
```

Mutations show failures as a snackbar through `runWithFeedback`:

```dart
QuantityStepper(onChanged: (q) => runWithFeedback(context, () => controller.setQuantity(item, q)));
```

## 4. Request handling details

- **Duplicate requests.** Controllers ignore `load()` while one is in flight,
  and `isBusy` disables cart buttons during a mutation.
- **Obsolete searches.** Search waits 400 ms after typing stops.
  `RequestBuilder` numbers each request and drops responses from superseded
  ones, so typing fast never shows stale results.
- **Parallel calls.** A restaurant menu fetches all of its `menuTags` with
  `Future.wait` and removes duplicate recipes.
- **401 anywhere.** Controllers call `AuthController.expireSession()`, and the
  router redirect sends the user to Login.
- **Polling.** The order tracking screen re-fetches `GET /orders/{id}` every
  5 s while the order is active. If one refresh fails it keeps the last state
  and shows "Couldn't refresh status…".
- **Images.** `AppImage` shows a placeholder while loading and on error, so a
  broken image icon never appears.
- **Connectivity.** The offline banner shows connection status. Placing an
  order calls `requireOnline()` first. Browsing still attempts requests and
  shows the API error with Retry if they fail.
