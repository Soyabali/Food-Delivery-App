# API Endpoints

Paths are defined in `lib/core/api/endpoints.dart`. Base URLs come from
`AppConfig` (`FOOD_API_BASE_URL`, `BACKEND_BASE_URL`).

**Provider legend**
- **DummyJSON** — real external HTTP API, `https://dummyjson.com`. Read-only.
- **Mock backend** — `lib/data/mock_backend/mock_backend.dart`, running inside
  the app (`BACKEND_MODE=mock`). It becomes your server when `BACKEND_MODE=http`.

## 1. Food data — DummyJSON (real)

All DummyJSON endpoints below were exercised against the live API with
`flutter test test/live --dart-define=RUN_LIVE=true` (8/8 passing; see TESTING_GUIDE.md).

| Feature | Method | Base URL | Endpoint | Purpose | Params | Response (used fields) | Status | Persistence |
|---|---|---|---|---|---|---|---|---|
| Top-rated dishes (Home, Search default) | GET | DummyJSON | `/recipes` | Featured dishes | `sortBy=rating&order=desc&limit=N` | `{recipes:[Recipe], total, skip, limit}` | Real | Read-only |
| Random dish (Surprise Me) | GET | DummyJSON | `/recipes` | Count, then one at random offset | `limit=1&select=id`, then `limit=1&skip=n` | same | Real | Read-only |
| Dish details | GET | DummyJSON | `/recipes/{id}` | Food details screen | path `id` | `Recipe`; 404 `{message}` | Real | Read-only |
| Search | GET | DummyJSON | `/recipes/search` | Search tab | `q` | `{recipes:[Recipe], …}` (empty list when no match) | Real | Read-only |
| Categories | GET | DummyJSON | `/recipes/tags` | Home "Explore Categories" | — | `["Pizza","Italian",…]` | Real | Read-only |
| Category / restaurant menu | GET | DummyJSON | `/recipes/tag/{tag}` | Category results; each restaurant's menu (one call per `menuTags` entry, run in parallel) | path `tag` (case-insensitive) | `{recipes:[Recipe], …}` | Real | Read-only |
| Meal type filter | GET | DummyJSON | `/recipes/meal-type/{type}` | Search chips | path `type` (Breakfast, Lunch, Dinner, Snack, Dessert, Beverage) | `{recipes:[Recipe], …}` | Real | Read-only |

`Recipe` fields used: `id, name, ingredients[], prepTimeMinutes, cookTimeMinutes,
servings, difficulty, cuisine, caloriesPerServing, tags[], image, rating,
reviewCount, mealType[]`.

**Not provided by DummyJSON** (derived in `recipe_adapter.dart`, documented as
demo rules): price, portions, spice levels, add-ons, description, veg/non-veg,
restaurant.

## 2. Backend — mock today, your server later

All require `Authorization: Bearer <token>` except those marked *public*.
Errors return `{ "message": "…" }` with the listed status.

### Auth

| Method | Endpoint | Purpose | Body | Response | Errors |
|---|---|---|---|---|---|
| POST | `/auth/login` *public* | Sign in | `{email, password}` | `{token, user:{id,name,email,phone}}` | 400 missing field, 401 wrong credentials |
| POST | `/auth/register` *public* | Create account + sign in | `{name, email, phone, password}` | `{token, user}` | 400 (password < 8), 409 email exists |
| POST | `/auth/logout` | Invalidate token | — | `null` | — |
| GET | `/auth/me` | Current user (session restore, profile) | — | `user` | 401 |
| POST | `/auth/forgot-password` *public* | Send 6-digit reset code | `{email}` | `{message}` (same whether or not the account exists). The mock backend also returns `demoCode` because it can't send email; FastAPI emails it. | 400 |
| POST | `/auth/reset-password` *public* | Set new password with the code | `{email, code, newPassword}` | `{message}`; ends all sessions | 400 wrong/expired code, 429 too many attempts |
| POST | `/auth/change-password` | Change password | `{currentPassword, newPassword}` | `{message}` | 400 wrong current / same / too short, 401 |

### Catalogue

| Method | Endpoint | Purpose | Query | Response |
|---|---|---|---|---|
| GET | `/restaurants` *public* | Popular, nearby, search, all | `popular=true`, `sort=distance`, `q=` | `[Restaurant]` |
| GET | `/restaurants/{id}` *public* | Restaurant screen | — | `Restaurant`; 404 |
| GET | `/offers` *public* | Home banner, login/registration promo, coupon picker | — | `[Offer]` |
| GET | `/notifications` *public* | Notifications sheet | — | `[{id,title,body,kind,createdAt}]` |

`Restaurant`: `{id, name, cuisines[], rating, deliveryTime, costForOne,
distanceKm, imageUrl, isPureVeg, deliveryFee, badge, popular, menuTags[],
addOns[{id,name,subtitle,price}], hasSpiceLevels, servesAllRecipes}`
`Offer`: `{code, title, subtitle, type:"percent"|"flat", value, maxDiscount,
minOrder, maxOrdersPerUser, imageUrl, featured}`

### User data

| Method | Endpoint | Purpose | Response |
|---|---|---|---|
| GET | `/addresses` | Saved addresses | `{selectedId, items:[{id,label,line,icon,isDefault}]}` |
| POST | `/addresses/{id}/select` | Choose delivery address | same; 404 |
| GET | `/favorites` | Favourites | `{restaurants:[id], dishes:[recipeId]}` |
| PUT | `/favorites/{restaurant\|dish}/{id}` | Add favourite | same |
| DELETE | `/favorites/{restaurant\|dish}/{id}` | Remove favourite | same |

### Cart (totals are calculated by the backend)

| Method | Endpoint | Purpose | Body | Errors |
|---|---|---|---|---|
| GET | `/cart` | Current cart | — | 401 |
| POST | `/cart/items` | Add item (merges identical configuration) | `{recipeId, restaurantId, name, image, isVeg, unitPrice, quantity, portion?, spiceLevel?, addOns[], note?, replaceCart}` | 400 validation, 404 restaurant, **409 cart has another restaurant** (unless `replaceCart:true`) |
| PATCH | `/cart/items/{id}` | Set quantity (0 removes) | `{quantity}` | 400, 404 |
| DELETE | `/cart/items/{id}` | Remove line | — | — |
| DELETE | `/cart` | Clear cart | — | — |
| POST | `/cart/coupon` | Apply coupon | `{code}` | 400 invalid code |
| DELETE | `/cart/coupon` | Remove coupon | — | — |
| PUT | `/cart/instructions` | Cooking/delivery note | `{instructions}` (≤150) | 400 |

Every cart endpoint responds with:

```json
{
  "items": [{"id":"l_…","recipeId":11,"restaurantId":"royal-biryani","name":"Chicken Biryani",
             "image":"…","isVeg":false,"unitPrice":400,"quantity":1,"portion":"Regular (Serves 1)",
             "spiceLevel":"Medium","addOns":[],"note":null}],
  "restaurant": {"id":"royal-biryani","name":"Royal Biryani House","distanceKm":2.4},
  "couponCode": "APNA100",
  "couponMessage": null,
  "instructions": "",
  "totals": {"itemTotal":400,"deliveryFee":0,"standardDeliveryFee":30,"freeDeliveryThreshold":199,
             "taxes":20.0,"taxRatePercent":5.0,"discount":100,"total":320.0,"savings":130}
}
```

Rules in the mock: delivery is free at ₹199 or more (otherwise the restaurant fee, or ₹30
when the fee is 0). Tax is 5% of the item total. `APNA100` takes ₹100 off orders of
₹300 or more. `APNA50` takes 50% off, capped at ₹150, on a user's first 3 orders.

### Orders

| Method | Endpoint | Purpose | Body | Response / errors |
|---|---|---|---|---|
| POST | `/orders` | Place order from the server cart (cart is emptied) | `{addressId, paymentMethod: "upi"\|"card"\|"cod"}` | `Order` · 400 empty cart / bad address / bad payment |
| GET | `/orders` | History (newest first) | — | `[Order]` |
| GET | `/orders/{id}` | Tracking (polled every 5 s while active) | — | `Order` · 404 |

`Order`: `{id:"AF-12345", restaurant:{id,name,imageUrl,distanceKm,deliveryTime},
items:[CartLine], amount, couponCode, instructions, address, paymentMethod,
placedAt, eta, status:"placed"|"preparing"|"outForDelivery"|"delivered",
statusTimes:{status: ISO8601}}`. The mock derives the status from time since
placement on an accelerated timeline: preparing after 10 s, out for delivery
after 60 s, delivered after 120 s.

### Persistence (mock backend)

All backend data is stored on the device in SharedPreferences under `mockdb.*`
keys, per user. It survives app restarts, but not uninstalling the app or
"Reset demo data". It is never shared between devices. The session token is
stored under `session.token`.
