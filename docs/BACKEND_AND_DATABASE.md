# Apna Food — Backend (FastAPI) & Database (PostgreSQL)

This is the real backend for the Apna Food mobile app and the upcoming web
dashboard. It lives in its own folder, separate from the Flutter app:

```text
mobileapp/
├── lib/ …                    Flutter app (unchanged)
├── docs/BACKEND_AND_DATABASE.md   ← this file
└── backend/                  FastAPI + PostgreSQL
    ├── app/
    │   ├── main.py           FastAPI app (routers, CORS, /media, /health)
    │   ├── core/             config.py · database.py · security.py · errors.py
    │   ├── models/           SQLAlchemy tables (the schema)
    │   ├── schemas/          Pydantic request/response shapes (camelCase JSON)
    │   ├── services/         business logic: cart totals, coupons, orders, serializers
    │   └── api/
    │       ├── deps.py       auth dependencies (customer / admin)
    │       └── routes/       auth · catalog · me · cart · orders · admin/*
    ├── alembic/              migrations (versions/…_0001_initial_schema.py)
    ├── database/schema.sql   generated plain-SQL DDL of the whole schema
    ├── seed/                 recipes.json (50 dishes) · catalog.py (restaurants, offers…)
    ├── scripts/              seed.py · export_schema.py
    ├── tests/                34 pytest tests against real PostgreSQL
    ├── requirements.txt · requirements-dev.txt · .env.example · alembic.ini
```

The architecture is:

```text
Web dashboard ──(admin token)──► /api/admin/*  ┐
                                               ├─► FastAPI ─► PostgreSQL
Mobile app ─────(user token)───► /api/*        ┘
```

Data entered in the dashboard is stored in PostgreSQL and served to the app
through the same API. The mobile endpoints follow the contract in
`docs/API_ENDPOINTS.md`, so the app switches over with `BACKEND_MODE=http`.

---

## 1. Database schema

**20 tables · 29 foreign keys · 23 check constraints · 6 enum types.**
Money is `NUMERIC(10,2)` in rupees. Timestamps are `TIMESTAMPTZ`. Lists such
as tags and ingredients are PostgreSQL `TEXT[]` arrays with GIN indexes.

### 1.1 ER diagram

```mermaid
erDiagram
    users ||--o{ addresses : "has"
    users |o--o| addresses : "selected_address_id"
    users ||--o{ user_sessions : "signs in"
    users ||--o{ password_reset_tokens : "resets"
    users |o--o{ media_assets : "uploads"
    users ||--o| carts : "owns one"
    users ||--o{ orders : "places"
    users ||--o{ notifications : "receives (NULL = broadcast)"
    users ||--o{ favorite_restaurants : ""
    users ||--o{ favorite_menu_items : ""

    restaurants ||--o{ menu_items : "sells"
    restaurants ||--o{ add_ons : "offers"
    categories  |o--o{ menu_items : "groups"
    menu_items  ||--o{ menu_item_variants : "portions"

    carts       ||--o{ cart_items : "contains"
    carts       }o--o| restaurants : "from"
    carts       }o--o| offers : "coupon"
    cart_items  }o--|| menu_items : ""
    cart_items  }o--o| menu_item_variants : "portion"
    cart_items  ||--o{ cart_item_add_ons : ""
    add_ons     ||--o{ cart_item_add_ons : ""

    orders      }o--|| restaurants : "from"
    orders      }o--o| offers : "coupon used"
    orders      ||--o{ order_items : "lines (snapshot)"
    orders      ||--o{ order_status_history : "timeline"
    order_items }o--o| menu_items : "SET NULL on delete"

    favorite_restaurants }o--|| restaurants : ""
    favorite_menu_items  }o--|| menu_items : ""
```

### 1.2 Tables

**Users & auth**

| Table | Purpose | Key columns & rules |
|---|---|---|
| `users` | Customers and admins | `email` unique case-insensitive (`lower(email)` index) · `password_hash` (Argon2id) · `role` enum `customer/admin` · `is_active` · `selected_address_id` → `addresses` (SET NULL) |
| `user_sessions` | One row per signed-in device | `token_hash` = SHA-256 of the bearer token (never the token itself) · `expires_at` · `revoked_at` (logout) |
| `password_reset_tokens` | Emailed 6-digit reset codes | `token_hash` (SHA-256 of user id + code) · `expires_at` · `used_at` · `attempts` (locked after 5) · only the newest code per user is kept |
| `media_assets` | Images uploaded from the dashboard (Media Library) | `file_name` (in `MEDIA_DIR`) and `url` unique · `original_name` · `content_type` · `size_bytes` · `uploaded_by_id` → users (SET NULL). Restaurants, menu items, categories and offers reference an image by `image_url` = `url` |
| `addresses` | Saved delivery addresses | `user_id` → users (CASCADE) · `label`, `line`, `icon`, `latitude/longitude` (range-checked) · **at most one `is_default` per user** (partial unique index) |

**Catalogue (managed from the dashboard)**

| Table | Purpose | Key columns & rules |
|---|---|---|
| `restaurants` | Restaurants | `slug` unique (public id used by the app, e.g. `royal-biryani`) · `cuisines TEXT[]` · `latitude/longitude` (distance is computed per user) · `rating 0–5` · `delivery_time_min/max` (max ≥ min) · `cost_for_one`, `delivery_fee` ≥ 0 · flags `is_pure_veg`, `has_spice_levels`, `is_popular`, `is_active` |
| `categories` | Home-screen categories | `name`, `slug` unique · `emoji` · `sort_order` · `is_active` |
| `menu_items` | Dishes | `restaurant_id` → restaurants (CASCADE) · `category_id` → categories (SET NULL) · `price > 0` · `is_veg`, `is_available`, `has_spice_levels`, `allows_add_ons` · `tags`, `meal_types`, `ingredients` (`TEXT[]`, GIN indexed) · `rating`, `calories`, `prep_time_minutes`, `badge` |
| `menu_item_variants` | Portions ("Regular", "Large") | `menu_item_id` → menu_items (CASCADE) · `price_delta ≥ 0` · **one `is_default` per dish** (partial unique index) |
| `add_ons` | Restaurant extras (raita, extra cheese…) | `restaurant_id` → restaurants (CASCADE) · `price ≥ 0` · `is_active` |

**Promotions & engagement**

| Table | Purpose | Key columns & rules |
|---|---|---|
| `offers` | Coupons (APNA50, APNA100) | `code` unique (UPPERCASE) · `discount_type` enum `percent/flat` (percent ≤ 100) · `value`, `max_discount`, `min_order` · `valid_for_first_n_orders` · `is_featured`, `is_active` · `starts_at < ends_at` |
| `notifications` | In-app messages | `user_id` NULL = broadcast · `kind` enum `offer/delivery/info` · `read_at` |
| `favorite_restaurants` | User ↔ restaurant | composite PK (`user_id`, `restaurant_id`), both CASCADE |
| `favorite_menu_items` | User ↔ dish | composite PK (`user_id`, `menu_item_id`), both CASCADE |

**Cart & orders**

| Table | Purpose | Key columns & rules |
|---|---|---|
| `carts` | One active cart per user | `user_id` **unique** · `restaurant_id` (a cart holds one restaurant's food) · `offer_id` (applied coupon) · `instructions` |
| `cart_items` | Cart lines | `menu_item_id`, `variant_id`, `spice_level`, `quantity 1–20`, `note` · **prices are not stored**: they're calculated live from the menu |
| `cart_item_add_ons` | Line ↔ add-on (many-to-many) | composite PK, both CASCADE |
| `orders` | Placed orders | `order_number` unique (`AF-12345`) · `status` enum `placed → preparing → out_for_delivery → delivered / cancelled` · `payment_method` `upi/card/cod` · `payment_status` `pending/paid/failed/refunded` · **address and money are snapshots** (`item_total`, `delivery_fee`, `taxes`, `discount`, `total`) · `user_id`, `restaurant_id` **RESTRICT** (history is never lost) |
| `order_items` | Order lines (snapshot) | `name`, `image_url`, `unit_price`, `variant_name`, `add_on_names TEXT[]`, `quantity`, `line_total` · `menu_item_id` SET NULL if the dish is deleted later |
| `order_status_history` | Tracking timeline | every status change with `changed_at`, `changed_by_user_id`, `note` |

### 1.3 Design decisions

- **Snapshots in orders.** Changing a price, deleting a dish or editing an
  address never changes past orders or receipts.
- **Prices are calculated on the server.** The cart stores only *what* was
  chosen. The API always prices from the database and ignores any price the
  app sends.
- **One restaurant per cart.** Adding from another restaurant returns HTTP 409
  unless the app sends `replaceCart: true`.
- **Safe deletes.** A restaurant with orders can't be hard-deleted (RESTRICT),
  so the dashboard deactivates it instead. A deleted dish keeps its order
  lines, because the snapshot keeps the name.
- **Tokens are hashed.** A database leak doesn't expose usable session tokens.
  Passwords use Argon2id.
- **Distance is computed.** Restaurants and addresses store coordinates, and
  the API returns the haversine distance from the user's selected address.

### 1.4 Where the schema is defined

| What | File | Use |
|---|---|---|
| Source of truth | `backend/app/models/*.py` | Change the schema here |
| Migrations | `backend/alembic/versions/` | `alembic upgrade head` creates/updates tables |
| Plain SQL | `backend/database/schema.sql` | Read it, or run it in pgAdmin. Generated with `pg_dump` (`scripts/export_schema.py`). |

To change the schema later: edit a model, run
`alembic revision --autogenerate -m "describe change"`, review the generated
file, then `alembic upgrade head`.

---

## 2. Setup on your PostgreSQL

Requires Python 3.12+ (tested on 3.13) and PostgreSQL 14+ (tested on 18).

### 2.1 Create the database and a dedicated user

In **pgAdmin → Query Tool** (connected as `postgres`), or with `psql -U postgres`:

```sql
CREATE ROLE apna_food_app WITH LOGIN PASSWORD 'choose-a-strong-password';
CREATE DATABASE apna_food OWNER apna_food_app;
```

### 2.2 Install and configure

```powershell
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements-dev.txt
copy .env.example .env      # then edit DATABASE_URL and ADMIN_PASSWORD
```

```ini
# backend/.env
DATABASE_URL=postgresql+psycopg://apna_food_app:choose-a-strong-password@localhost:5432/apna_food
ADMIN_EMAIL=you@yourdomain.com
ADMIN_PASSWORD=a-strong-admin-password
```

### 2.3 Create tables, add starter data, run

```powershell
alembic upgrade head              # creates all 20 tables
python scripts/seed.py            # 8 restaurants, 50 dishes, 13 categories, 2 offers, admin + demo user
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- Interactive API docs: http://localhost:8000/docs
- Health check: http://localhost:8000/health

`seed.py` refuses to run on a database that already has data.
`python scripts/seed.py --reset` **deletes everything** and seeds again.

Starter logins:
- **admin**: your `ADMIN_EMAIL` / `ADMIN_PASSWORD`
- **customer**: `rahul.sharma@example.com` / `supersecret123`

The 50 dishes in `seed/recipes.json` were imported once from DummyJSON and are
now your own data. Their starting prices come from a formula (calories,
cooking time, difficulty), so review them in the dashboard.

### 2.4 Run the tests

The tests **wipe the database they use**, so give them a separate one:

```powershell
# psql: CREATE DATABASE apna_food_test OWNER apna_food_app;
$env:TEST_DATABASE_URL="postgresql+psycopg://apna_food_app:PASSWORD@localhost:5432/apna_food_test"
pytest
```

---

## 3. API reference

Base URL: `http://<host>:8000/api`. Every error looks like
`{"message": "…"}`. Validation errors (422) also include
`"errors": [{"field", "message"}]`. Authenticate with
`Authorization: Bearer <token>` (from login/register).

### 3.1 Mobile app

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/auth/register` | – | Create account → `{token, user}` (201; 409 duplicate email) |
| POST | `/auth/login` | – | → `{token, user}` (401 wrong credentials) |
| POST | `/auth/logout` | user | Revoke this token (204) |
| GET | `/auth/me` | user | Current user |
| POST | `/auth/forgot-password` | – | Emails a 6-digit code (15 min, 45 s resend cooldown). Same reply whether or not the email exists |
| POST | `/auth/reset-password` | – | `{email, code, newPassword}`: sets the password, signs out all devices. 5 wrong codes lock it (429) |
| POST | `/auth/change-password` | user | `{currentPassword, newPassword}` |
| GET | `/restaurants?popular=&sort=distance\|rating&q=` | optional | List (distance from the user's selected address) |
| GET | `/restaurants/{slug}` | optional | One restaurant |
| GET | `/restaurants/{slug}/menu` | – | Its available dishes |
| GET | `/menu-items?q=&category=&tag=&mealType=&restaurant=&veg=&sort=rating\|price\|name&limit=` | – | Search/browse dishes |
| GET | `/menu-items/{id}` | – | Dish details incl. `portions`, `spiceLevels`, `addOns` |
| GET | `/categories` | – | Active categories |
| GET | `/offers` | – | Active offers (featured first) |
| GET | `/notifications` | optional | Broadcast + the user's own |
| GET / POST | `/addresses` | user | Address book / add an address |
| POST | `/addresses/{id}/select` | user | Choose delivery address |
| DELETE | `/addresses/{id}` | user | Remove address |
| GET | `/favorites` | user | `{restaurants:[slug], dishes:[id]}` |
| PUT / DELETE | `/favorites/{restaurant\|dish}/{id}` | user | Add / remove |
| GET / DELETE | `/cart` | user | Cart with server totals / clear |
| POST | `/cart/items` | user | `{menuItemId, quantity, portion\|variantId, spiceLevel, addOns\|addOnIds, note, replaceCart}` |
| PATCH / DELETE | `/cart/items/{id}` | user | Set quantity (0 removes) / remove |
| POST / DELETE | `/cart/coupon` | user | Apply `{code}` / remove |
| PUT | `/cart/instructions` | user | `{instructions}` |
| POST | `/orders` | user | `{addressId, paymentMethod}` → order (201) |
| GET | `/orders`, `/orders/{orderNumber}` | user | History / tracking |

Cart totals rules come from `.env`:
- Delivery is free at `FREE_DELIVERY_THRESHOLD` (₹199) or more. Otherwise the
  restaurant's fee applies, or `STANDARD_DELIVERY_FEE` (₹30) when its fee is 0.
- Tax is `TAX_RATE_PERCENT` (5%) of the item total.
- Coupons follow the offer's `min_order`, `max_discount` and
  `valid_for_first_n_orders`.

### 3.2 Web dashboard (`role = admin`)

| Method | Path | Purpose |
|---|---|---|
| GET | `/admin/stats` | Users, restaurants, dishes, today's orders & revenue, active orders, orders by status, top 5 dishes |
| GET / POST | `/admin/restaurants` (`?q=&active=&page=&pageSize=`) | List (paginated) / create (with `addOns`) |
| GET / PATCH / DELETE | `/admin/restaurants/{id}` | Read / update (sending `addOns` syncs the list) / delete (deactivates if it has orders) |
| GET / POST | `/admin/menu-items` (`?q=&restaurantId=&categoryId=&available=&page=`) | List / create (with `variants`) |
| GET / PATCH / DELETE | `/admin/menu-items/{id}` | Read / update (price, availability, variants…) / delete |
| GET / POST | `/admin/categories` | List (with dish counts) / create |
| PATCH / DELETE | `/admin/categories/{id}` | Update / delete (dishes become uncategorised) |
| GET / POST | `/admin/offers` | List (with `timesUsed`) / create |
| PATCH / DELETE | `/admin/offers/{id}` | Update / delete |
| GET | `/admin/orders` (`?status=&restaurantId=&q=&from=&to=&page=`) | Order list |
| GET | `/admin/orders/{id}` | Detail with items and status history |
| PATCH | `/admin/orders/{id}/status` | `{status, note}`: `placed → preparing → out_for_delivery → delivered`, or `→ cancelled` |
| PATCH | `/admin/orders/{id}/payment` | `{paymentStatus}` |
| GET / POST | `/admin/users` | List (`?q=&role=`) / create staff or customer |
| PATCH | `/admin/users/{id}` | `{role, isActive}` (you can't remove your own admin access) |
| POST | `/admin/notifications` | Broadcast, or send to one `userId` |
| POST | `/admin/uploads` | Multipart image (JPEG/PNG/WebP ≤ 5 MB) → `{id, url}` for any `imageUrl` field; recorded in `media_assets` |
| GET | `/admin/uploads` | Media Library: `?q=` (file name), `page`, `pageSize` → each image with `usedBy` (restaurants/dishes/categories/offers) and `orderItemCount` |
| DELETE | `/admin/uploads/{id}` | Deletes the file and row; `409` while any record or past order uses it |

Paginated responses look like `{items, total, page, pageSize}`.

---

## 4. Connecting the mobile app

1. Start the API on your PC: `uvicorn app.main:app --host 0.0.0.0 --port 8000`.
2. In the Flutter project, copy `.env.example` to `.env` and set:
   ```ini
   BACKEND_MODE=http
   BACKEND_BASE_URL=http://10.0.2.2:8000/api   # Android emulator → your PC
   ```
   On a real phone, use your PC's LAN IP (e.g. `http://192.168.1.20:8000/api`),
   allow port 8000 through Windows Firewall, and set `PUBLIC_BASE_URL` in
   `backend/.env` to the same host so uploaded image URLs work.
3. Run `flutter run --dart-define-from-file=.env`.

Login, cart, coupons, orders, addresses, favourites, restaurants, offers and
notifications then come from PostgreSQL.

To check that the app understands the server, run the app's real services
against it:

```powershell
flutter test test/live/backend_live_test.dart --dart-define=BACKEND_URL=http://localhost:8000/api
```

**Still to do in the app** (next step):
- Dishes, categories and search still come from DummyJSON. Switch the app's
  `FoodService` to `/menu-items`, `/restaurants/{slug}/menu` and `/categories`
  so dashboard edits to dishes show up in the app. The ids already match
  (seeded dish ids = DummyJSON recipe ids).
- Add `cancelled` to the app's `OrderStatus` enum before the dashboard cancels
  an order. Today the app would show "unexpected response" for that order.
- Android blocks plain `http://` in **release** builds. Use HTTPS in
  production, or a network security config for development.

---

## 5. Not included yet

- Real payment gateway: orders record the method with `payment_status=pending`.
- SMS. (Email works through SMTP: see section 6.)
- Restaurant-owner logins, rider/delivery app, reviews and ratings input.
- Rate limiting and HTTPS (put the API behind a reverse proxy such as Nginx or
  Caddy, or a cloud load balancer, when deploying).
- Cloud image storage: uploads go to `backend/media/`. Use S3 or Cloudinary in
  production.

---

## 6. Email (password reset codes)

`POST /auth/forgot-password` emails a 6-digit code using SMTP settings in
`backend/.env`. **While `SMTP_HOST` is empty, nothing is sent and the code is
printed in the FastAPI console instead** (fine for development).

To send real emails from a Gmail account:

1. Turn on **2-Step Verification** for the Google account.
2. Create an **App Password** at https://myaccount.google.com/apppasswords
   (16 characters). Your normal Gmail password will not work.
3. Fill in `backend/.env` and restart the server:

```ini
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your.address@gmail.com
SMTP_PASSWORD=abcdabcdabcdabcd        # the App Password, without spaces
SMTP_FROM=Apna Food <your.address@gmail.com>
```

Gmail allows roughly 500 emails a day. For production, use a transactional
provider (SendGrid, Mailgun, Amazon SES, Brevo). They all accept the same SMTP
settings.
