# Mock API Limitations

## External (real network)

| API | Used for | Limitations |
|---|---|---|
| DummyJSON Recipes (`https://dummyjson.com/recipes…`) | Dishes, images, ratings, ingredients, categories (tags), meal types, search | **Read-only, 50 recipes total.** No prices, restaurants, delivery times, stock, descriptions or veg flags. Public test service with no uptime guarantee; may rate-limit. No API key. Data is the same for everyone. |
| DummyJSON image CDN (`cdn.dummyjson.com/recipe-images/{id}.webp`) | Dish, restaurant and offer images | Cached in memory only (`Image.network`), so it re-downloads after an app restart. |

DummyJSON also has `/auth/login` and `/carts`, but they are **not used**. Its
auth only knows fixed test users and cannot register new ones, and its write
endpoints **do not persist** (responses are simulated). They could not support
a real cart or order flow.

## Simulated locally (on-device mock backend)

Everything in `BackendEndpoints` (auth, profile, restaurants, offers,
notifications, addresses, favourites, cart, orders) is answered by
`lib/data/mock_backend/mock_backend.dart`.

| Question | Answer |
|---|---|
| Survives app restart? | **Yes.** Stored in SharedPreferences (`mockdb.*`). The session token persists too. |
| Survives uninstall / "Reset demo data"? | No. |
| Shared across devices or users? | **No.** Each install has its own private "database". Two phones never see each other's accounts or orders. |
| Real authentication? | **No.** Passwords are salted SHA-256 hashes in unencrypted local storage, and tokens are random strings with no expiry. That's fine for a demo, not secure. |
| Real emails / password reset? | No email is ever sent; the UI says so. |
| Real payment? | No. UPI/Card/COD only record the chosen method. The checkout sheet says "Demo checkout: no real payment is made." |
| Real order tracking? | No. Status is computed from elapsed time on an accelerated timeline (10 s / 60 s / 120 s). |
| Google / Apple sign-in | Simulated: signs in the demo account in mock mode; reports "not configured" in `http` mode. No SDK is integrated. |

## Demo rules standing in for missing data

All of these live in one file, `lib/data/adapters/recipe_adapter.dart`:

- **Price:** `99 + calories×0.45 + minutes×0.8 (+30 if Medium)`, rounded to
  ₹10 and kept between ₹100 and ₹550. "Large" portions cost 60% more.
  Food details shows "demo price".
- **Veg / non-veg:** a keyword heuristic (meat, fish, egg). It can be wrong.
- **Description:** composed from cuisine, meal type and the first ingredients.
- **Restaurant for a recipe:** the first restaurant whose `menuTags` match the
  recipe's tags, otherwise "Apna Cloud Kitchen".
- **Cart prices:** the mock backend trusts the `unitPrice` the app sends.
  A real backend **must** price items server-side.

## Other limitations

- Restaurants, offers and notifications are fixed seed data in `mock_seed_data.dart`.
- Adding, editing and deleting addresses isn't implemented (select only).
- Voice search and live support chat are not implemented, and the UI says so.
- "Reset demo data" wipes the mock backend only; preferences such as the
  notification toggle are in memory and reset on restart.
