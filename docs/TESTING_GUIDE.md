# Testing Guide

## Automated tests

```bash
flutter analyze                                        # lint / static checks
flutter test                                           # 45 tests; 8 live tests skipped
flutter test test/live --dart-define=RUN_LIVE=true     # 8 tests against the real DummyJSON
```

| File | What it covers |
|---|---|
| `test/api_client_test.dart` | URL/query/header building, JSON bodies, 401/400/404/5xx mapping, invalid JSON, network failure, timeout |
| `test/recipe_adapter_test.dart` | DummyJSON → `Dish` mapping, demo pricing formula, veg heuristic, invalid response shapes |
| `test/mock_backend_test.dart` | Auth (401, wrong password, duplicate email, hashed passwords), cart totals, free delivery, tax, both coupons, merge, 409 conflict, quantity validation, order placement and status timeline, persistence across restarts, logout |
| `test/services_test.dart` | FoodService against a fake DummyJSON (sorting, search, tags, pure-veg menus, 404, network, invalid JSON), auth session restore, cart conflict, **services over real HTTP (`BACKEND_MODE=http`)**, router guards |
| `test/widget_test.dart` | End-to-end UI: login validation, backend errors, Home sections loaded from APIs, food-API outage → Retry → recovery, search + empty state, restaurant → dish → cart → order → confirmation, session survives restart, logout, registration, offline order blocked |
| `test/live/dummyjson_live_test.dart` | Every DummyJSON endpoint the app uses, through the real services (opt-in) |

Widget tests use `test/support/fake_food_api.dart`, an `http` `MockClient`
that serves DummyJSON-shaped fixtures and can be switched to
`FakeFailure.network | server | invalidJson`.

## Manual checks on a device or emulator

| Scenario | How | Expected |
|---|---|---|
| Successful requests | Log in | Home shows offer, categories, top-rated dishes, restaurants. Images come from `cdn.dummyjson.com`. |
| Network failure | Turn on Airplane mode, then pull to refresh on Home | Offline banner, plus "No internet connection" with Retry in each food section |
| Recovery | Turn Airplane mode off, tap Retry | Sections load |
| Search | Search tab → type `pasta` | Results after ~0.4 s. `zzzz` shows "Nothing found". |
| Category | Tap a category on Home | Search opens filtered by that tag |
| Cart calculations | Add a dish worth under ₹199 | Delivery fee charged; "Add ₹X more for free delivery" |
| | Raise the quantity past ₹199 | Delivery shows FREE (struck-through fee) |
| | Apply APNA100 under ₹300 | "Add ₹X more to use APNA100", no discount |
| | Apply APNA50 | 50% off, max ₹150 |
| Restaurant conflict | Add from a second restaurant | "Replace cart items?" dialog |
| Checkout | Proceed to Payment → Pay | Confirmation with an `AF-xxxxx` ID; cart empties; status advances (10 s / 60 s / 120 s) |
| Persistence | Add items, kill the app, reopen | Still signed in; cart and orders intact |
| Session expiry | Profile → Reset demo data | Signed out; demo account re-seeded |
| Invalid response | Set `FOOD_API_BASE_URL=https://example.com` | Food sections show "We received an unexpected response" (or not-found) with Retry |
| Mock vs. real config | `--dart-define=BACKEND_MODE=http` with no server running | Splash or login shows a network error instead of crashing |

## Debug output

- `[api] GET https://… network error` lines show real HTTP failures.
- `[mock-backend] POST /cart/items` lines show each simulated backend call.
