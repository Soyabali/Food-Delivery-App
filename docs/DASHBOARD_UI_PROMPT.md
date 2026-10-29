# Apna Food — Admin Dashboard UI Design Prompt

> Copy everything below the line into your design agent (Google Stitch, v0,
> Lovable, Figma AI, etc.). It is self-contained and covers UI and visual
> design only.

---

## 1. Role and goal

You are a senior product designer. Design a **responsive web admin dashboard**
for **Apna Food**, a hyperlocal food-delivery business in Bengaluru, India.
Staff use the dashboard to manage restaurants, dishes, categories, offers,
orders, customers and notifications. Everything they enter appears in the
Apna Food customer mobile app.

The dashboard must look like the same brand as the mobile app: warm orange,
soft tinted surfaces, rounded cards, generous spacing and friendly typography.
It should be denser and more data-oriented than the app, but never feel like a
generic grey admin template.

**Deliverables:**
- One high-fidelity screen for each page in section 6, at desktop width
  (1440 px).
- Tablet (1024 px) and mobile (390 px) versions of the **Overview** and
  **Orders** pages.
- A components sheet: buttons, inputs, selects, toggles, chips, status badges,
  table row, card, modal, drawer, toast, pagination, empty state, skeletons.
- Output as HTML with Tailwind CSS, using the exact tokens in sections 2–4,
  with a light theme.

---

## 2. Colour tokens (use exactly these values)

Material 3 style roles copied from the mobile app:

| Token | Hex | Use |
|---|---|---|
| `primary-container` | `#FF6B35` | **Brand orange**: primary buttons, active nav, key highlights |
| `primary` | `#AB3500` | Links, text on light orange, focus emphasis |
| `on-primary` | `#FFFFFF` | Text and icons on orange |
| `primary-fixed` | `#FFDBD0` | Light orange chips, selected rows, badges |
| `primary-fixed-dim` | `#FFB59D` | Decorative accents |
| `on-primary-fixed` | `#390C00` | Text on `primary-fixed` |
| `on-primary-fixed-variant` | `#832600` | Secondary text on light orange |
| `secondary` | `#B9052C` | Destructive actions (delete, cancel) |
| `secondary-container` | `#DE2B41` | Gradient partner of orange, alerts |
| `secondary-fixed` | `#FFDAD9` | Light red background for destructive areas |
| `tertiary` | `#006D37` | Success text (delivered, paid, veg) |
| `tertiary-container` | `#00B15C` | Success fills, rating pills |
| `tertiary-fixed` | `#6BFE9C` | Light green badges |
| `error` | `#BA1A1A` | Form errors |
| `error-container` | `#FFDAD6` | Error banners |
| `surface-container-lowest` | `#FFFFFF` | Cards, table, page content |
| `surface` / `background` | `#F8F9FF` | App background behind cards |
| `surface-container-low` | `#EFF4FF` | Input fills, subtle sections, table header |
| `surface-container` | `#E6EEFF` | Hover, neutral chips |
| `surface-container-high` | `#DEE9FC` | Pressed, skeleton base |
| `surface-dim` | `#D0DBED` | Dividers |
| `surface-variant` | `#D9E3F6` | Borders, progress tracks |
| `on-surface` | `#121C2A` | Primary text |
| `on-surface-variant` | `#594139` | Secondary text |
| `outline` | `#8D7168` | Muted text, placeholder, icons |
| `outline-variant` | `#E1BFB5` | Hairline borders on orange areas |

**Brand gradient** (hero banners, revenue card, login panel):
`linear-gradient(90deg, #FF6B35 0%, #DE2B41 60%, #B9052C 100%)`.

**Rules**
- Avoid pure grey. Neutrals are the cool blue-tinted surfaces above, and text
  is warm brown-black.
- Use one orange primary action per view. Secondary actions are tinted
  (`surface-container-low`) or text buttons.
- Separate areas mostly with colour shifts and soft shadows, not heavy borders.

### Status colours (badges, chart series, timeline)

| Status | Background | Text / dot |
|---|---|---|
| Placed | `#E6EEFF` | `#121C2A` |
| Preparing | `#FFDBD0` | `#AB3500` |
| Out for delivery | `#FFF1C2` | `#7A5900` |
| Delivered | `#6BFE9C66` (40%) | `#006D37` |
| Cancelled | `#FFDAD9` | `#B9052C` |
| Payment pending | `#E6EEFF` | `#594139` |
| Paid | `#6BFE9C66` | `#006D37` |
| Failed / Refunded | `#FFDAD9` | `#B9052C` |
| Active / Inactive (toggle) | green track `#00B15C` / grey track `#D0DBED` |

Veg / non-veg indicators: a green dot in a green-outlined square for veg, a
red square in a red-outlined square for non-veg. These match the mobile app.

---

## 3. Typography

Two Google Fonts:
- **Plus Jakarta Sans** (600, 700) for headings, numbers and KPIs
- **Inter** (400, 500, 600, 700) for body text, labels, tables and inputs

| Style | Font | Size / line height | Weight | Tracking | Use |
|---|---|---|---|---|---|
| `display` | Plus Jakarta Sans | 32 / 40 | 700 | -0.02em | KPI numbers (revenue) |
| `headline-xl` | Plus Jakarta Sans | 28 / 34 | 700 | -0.02em | Page title |
| `headline-lg` | Plus Jakarta Sans | 24 / 30 | 700 | -0.015em | Section titles, modal titles |
| `headline-md` | Plus Jakarta Sans | 22 / 28 | 600 | -0.01em | Card titles, stat values |
| `title-md` | Plus Jakarta Sans | 18 / 24 | 600 | 0 | Sub-section headers, drawer headers |
| `label-lg` | Inter | 16 / 20 | 600 | 0 | Buttons, emphasised values |
| `label-md` | Inter | 14 / 18 | 600 | 0 | Form labels, table headers, nav items |
| `label-sm` | Inter | 11 / 14 | 700 | 0.02em (0.08em for UPPERCASE) | Badges, chips, overlines |
| `body-lg` | Inter | 16 / 24 | 400 | 0 | Long descriptions |
| `body-md` | Inter | 14 / 20 | 400 | 0 | Default body, table cells |
| `body-sm` | Inter | 12 / 16 | 400 | 0 | Helper text, timestamps, captions |

- Show money in rupees with the `₹` sign: `₹1,250` in tables and `₹1,250.00`
  in bills and receipts. Use tabular numbers (`font-variant-numeric:
  tabular-nums`) in tables and KPIs.
- Small UPPERCASE overlines with letter spacing, such as "DELIVER TO" and
  "TOTAL PAYABLE", are a brand signature. Use them for card overlines and
  table group headers.
- Icons: **Material Symbols Outlined** (weight 400, FILL 0; FILL 1 for active
  nav). 20 px inline and 24 px in navigation.

---

## 4. Shape, spacing and elevation

- **Spacing** (4-px base): 4, 8, 16, 24, 32, 48. Page padding is 32 px
  (desktop), 24 px (tablet) and 16 px (mobile). The card grid gap is 24 px.
- **Radius**: 4 px (tiny badges), 8 px (inputs inside tables, image
  thumbnails), **12 px (cards, inputs, buttons; default)**, 16 px (large
  panels, modals), 24 px (hero banner, login card), full (chips, avatars,
  toggles).
- **Shadows**:
  - `sm` = `0 1px 2px rgba(0,0,0,.05)` for cards at rest
  - `md` = `0 4px 6px rgba(0,0,0,.08), 0 2px 4px rgba(0,0,0,.04)` for hover,
    dropdowns and primary buttons
  - `lg` = `0 10px 15px rgba(0,0,0,.10)` for modals and drawers
- **Heights**: inputs and primary buttons 44 px (52 px on login), table rows
  56 px, top bar 64 px.
- **Motion**: 150–200 ms ease-out on hover and press. Primary buttons scale to
  0.98 when pressed, and drawers slide in from the right.

---

## 5. Layout shell

**Sidebar** (left, 264 px; collapses to 72 px icons; becomes a drawer on
mobile). It has a white background and a soft right shadow.
- Top: logo (orange-to-red gradient rounded square with a burger icon) and
  "Apna Food" in Plus Jakarta Sans 700, with a small "Admin" chip.
- Nav items with an icon and label:
  - Overview (`dashboard`)
  - Orders (`receipt_long`), with a live count badge in orange
  - Restaurants (`storefront`)
  - Menu Items (`restaurant_menu`)
  - Categories (`category`)
  - Offers (`local_offer`)
  - Customers (`group`)
  - Notifications (`campaign`)
  - Media Library (`photo_library`)
  - Settings (`settings`)
- Active item: `primary-fixed` background pill, `primary` text, filled icon.
  Hover: `surface-container-low`.
- Bottom: signed-in admin card with avatar, name, email and a logout icon.

**Top bar** (64 px, white at 90% opacity with a blurred background, sticky):
- Breadcrumb and page title on the left.
- Global search in the centre ("Search orders, dishes, restaurants…", with a
  `⌘K` hint).
- On the right:
  - a "Live" indicator (pulsing green dot with "Kitchens Live", like the app
    splash)
  - a notifications bell
  - the admin avatar

**Content area**: `#F8F9FF` background with a max content width of 1440 px.
Page header row: title (`headline-xl`) with a subtitle (`body-md`,
`on-surface-variant`) on the left, and the primary action button on the right.

---

## 6. Pages to design

Use the realistic data given here. These are the real seed records.

### 6.1 Login
- Split layout. The left half is the brand gradient panel with a large food
  photo collage, the line "Fresh Food, Fast Delivery." and the "Apna Food"
  wordmark. The right half is a white login card (24 px radius).
- Fields: email and password (with a show/hide eye icon), "Remember me", and
  "Forgot password?" in `primary-container`.
- A 52 px orange **Sign in** button with an arrow icon.
- An error banner state reading "Incorrect email or password." on
  `error-container`.
- A note: "Admin access only".

### 6.2 Overview (home)
- **KPI row** of 4 cards:
  - **Revenue today** (`₹12,480`, brand gradient card with white text and a
    sparkline)
  - **Orders today** (`48`, +12% vs yesterday chip in green)
  - **Active orders** (`7`, orange pulsing dot)
  - **Customers** (`1,284`)
- **Orders by status**: a horizontal stacked bar or donut using the status
  colours, with a legend (Placed 3, Preparing 2, Out for delivery 2,
  Delivered 39, Cancelled 2).
- **Revenue, last 7 days**: an area chart with an orange line and an orange
  gradient fill fading to transparent.
- **Live orders**: a compact list of the 5 newest active orders, each with the
  order number `#AF-45666`, customer name, restaurant, amount, status badge
  and a "time since placed" chip.
- **Top dishes**: a top-5 table with thumbnail, name, restaurant, quantity
  sold and revenue. Examples: Chicken Biryani (Royal Biryani House),
  Classic Margherita Pizza (Pizza Roma Cucina), Thai Green Curry
  (Wok & Spice).
- **Quick actions**: Add dish, Add restaurant, Create offer, Send
  notification.

### 6.3 Orders (most important page)
- **Filter bar**: status segmented tabs (All · Placed · Preparing · Out for
  delivery · Delivered · Cancelled, each with a count), date range picker,
  restaurant select, and search ("Order no. or customer").
- **Table columns**: Order no. (`#AF-45666`, monospace-ish Inter 600), placed
  time ("Today, 5:09 PM"), customer (name and phone), restaurant, items count,
  total (`₹924.00`), payment (method chip UPI/Card/COD and payment status
  badge), status badge, and a row action (⋯).
- Rows for active orders show a thin left border in the status colour.
- **Order detail**, a right drawer about 560 px wide:
  - Header: order number, status badge, "Placed 12 min ago".
  - **Status stepper**: Placed → Preparing → Out for delivery → Delivered,
    the same visual language as the app's "Order Live Status" timeline (green
    check for done, a pulsing orange circle for current, grey for upcoming,
    with times).
  - Big action button for the next step ("Mark as Preparing" in orange), plus
    "Cancel order" as a red text button with a confirmation modal.
  - Customer and delivery address card, restaurant card.
  - Items list: veg/non-veg mark, name, portion "Regular (Serves 1)", spice
    level, add-ons, quantity × price.
  - **Bill**: Item total, Delivery fee (struck through with "FREE" in green
    when free), Taxes (5%), Coupon "APNA100 −₹100.00" in green, and **Total**
    in `headline-md`.
  - Activity history: who changed the status and when, with an optional note.

### 6.4 Restaurants
- Toggle between a **grid view** of cards and a **table view**.
- Card: cover image (16:9, 12 px radius), a "Trending" badge or a
  "Pure Veg" green badge, name (`title-md`), cuisines ("Biryani • Pakistani •
  Mughlai"), a rating pill (green, ★ 4.8), delivery time "25-30 mins",
  "₹250 for one", a dish count, and an Active toggle.
- **Create / Edit restaurant** as a full page with sections:
  - **Basic info**: name, slug (auto-generated, editable, with helper text
    "Used in app links"), description, cuisines (chip input).
  - **Media**: image uploader drop zone (dashed `outline-variant` border,
    preview, "JPEG/PNG/WebP up to 5 MB").
  - **Location**: address line, latitude and longitude, and a small map
    preview placeholder.
  - **Delivery & pricing**: delivery time min–max (two inputs with "to"),
    cost for one, delivery fee (₹, with "0 = free delivery" helper).
  - **Flags** as toggles: Pure veg, Spice levels, Popular, Active, and a badge
    text field.
  - **Add-ons**: an editable inline list (name, subtitle, price, active,
    drag handle, delete). Example: "Mint Raita — Cooling yoghurt with fresh
    mint — ₹25".
  - A sticky footer bar with Cancel (tinted) and **Save restaurant** (orange).

### 6.5 Menu Items
- Filters: restaurant select, category select, availability, veg/non-veg,
  search.
- **Table columns**: thumbnail (48 px, 8 px radius), name with a veg mark,
  restaurant, category, price (`₹440`), rating, an **Available** toggle (can
  be switched inline), and actions.
- **Create / Edit dish** as a form in two columns:
  - **Left**: name, description, restaurant, category, price, image upload,
    tags (chips), meal types (multi-select chips: Breakfast, Lunch, Dinner,
    Snack, Dessert, Beverage), ingredients (chip input), prep time, calories,
    difficulty, servings.
  - **Right**: a **live preview card** showing how the dish looks in the
    mobile app (phone-shaped frame using the app's food-details style), plus
    toggles for Veg, Available, Spice levels and Allow add-ons.
  - **Portions**: an editable list (name, subtitle, extra price, default
    radio). Examples: "Regular (Serves 1) +₹0 default", "Large (Serves 2)
    +₹240".

### 6.6 Categories
- A sortable list of cards with a drag handle, emoji in a tinted circle
  (🍛 Biryani, 🍕 Pizza, 🍰 Desserts, 🥤 Drinks), name, slug, dish count, an
  Active toggle, and edit/delete.
- Create and edit happen in a compact modal: name, slug, emoji picker, image,
  sort order, active.

### 6.7 Offers
- Coupon cards styled like tickets, with a notched edge and a dashed divider.
  The code is large (`APNA50`, Plus Jakarta Sans 700, letter-spaced), with a
  title "50% OFF" and subtitle "Up to ₹150 on first 3 orders".
- Card details: a type chip (Percent/Flat), min order, max discount, "first N
  orders" rule, validity dates, **times used**, a Featured star toggle and an
  Active toggle.
- Create/Edit form with a **live preview** of how the offer appears in the
  app's home banner (brand gradient banner with the code button).

### 6.8 Customers
- **Table**: avatar with initials, name, email, phone, orders count, joined
  date, last login, a role chip (Customer/Admin) and a status (Active/Disabled).
- **Detail drawer**: profile header, saved addresses, recent orders list,
  and actions (Make admin, Disable account, the latter with a confirmation).
  The signed-in admin cannot remove their own admin role, so show that
  control disabled with a tooltip.

### 6.9 Notifications
- **Composer card**: title, message (with a character counter out of 500),
  type (Offer / Delivery / Info, as chips with icons), and audience (All
  customers / One customer search).
- A **phone preview** of the notification as it appears in the app sheet.
- **History table**: title, type, audience, and sent at.

### 6.10 Media Library
- A grid of uploaded images with a large drag-and-drop upload area at the top.
- Each tile has a hover overlay with "Copy URL" and "Delete" actions and shows
  the file size.

### 6.11 Settings
- Sections:
  - **Business rules** (read-only display): standard delivery fee ₹30, free
    delivery above ₹199, tax 5%.
  - **Email**: SMTP status with a "Connected"/"Not configured" badge.
  - **Profile**: admin name, email, change password.
- A "Danger zone" card in a `secondary-fixed` tint.

---

## 7. Components (draw all states)

- **Buttons**: Primary (orange fill, white text, `md` shadow), Secondary
  (tinted `surface-container-low`), Ghost/Text (`primary` text), Destructive
  (`secondary` fill, or red text). Each in default, hover, pressed, disabled
  (60% opacity) and loading (spinner plus "Saving…").
- **Inputs**: 44 px, 12 px radius, `surface-container-low` fill with no
  border at rest. On focus: white fill, a 2 px `#FF6B35` ring at 40%, and a
  `md` shadow. Leading icon in `outline`. Error state uses a red ring and red
  helper text below. Label above in `label-md`.
- **Select / Combobox / Multi-select chips / Date range picker / Toggle switch
  / Checkbox / Radio**: all use the orange accent when on.
- **Status badge**: pill, `label-sm`, with a dot and colours from section 2.
- **Rating pill**: green `#00B15C` with a white star and number.
- **Veg mark** (see section 2).
- **Data table**: header row in `surface-container-low` with `label-md`
  `on-surface-variant` text; zebra rows are optional, and hover rows use
  `surface-container-low`. Include a sticky header, sortable column arrows,
  row selection checkboxes, a bulk action bar sliding up from the bottom
  ("3 selected · Mark available · Delete"), and pagination ("Showing 1–20 of
  50", page numbers, page-size select).
- **Card**: white, 12 px radius, `sm` shadow, 16–24 px padding.
- **Modal** (16 px radius, `lg` shadow) and **right drawer**.
- **Confirmation dialog** for destructive actions, with a red primary button.
- **Toasts** in the bottom-right, dark `#121C2A` with white text and an
  optional action (for example "Order #AF-45666 marked Delivered · Undo").
- **Empty states**: a friendly icon in a tinted circle, a title, one line of
  copy and a primary action. Example: "No orders yet. New orders will appear
  here in real time."
- **Loading skeletons**: pulsing `surface-container` blocks matching the
  table rows and cards.
- **Error state**: an inline card with a cloud-off icon, the message and a
  "Retry" button.

---

## 8. Responsive behaviour

- **≥ 1280 px**: full sidebar; KPIs in 4 columns; tables at full width;
  drawers 560 px.
- **768–1279 px**: icon-only sidebar; KPIs in 2 columns; tables hide
  low-priority columns (phone, payment method).
- **< 768 px**: hamburger menu with the sidebar as a drawer; KPIs in 1 column;
  tables become stacked cards (order no. and status badge on top, customer
  and total below); drawers become full-screen sheets; the primary action
  becomes a floating orange button.

---

## 9. Accessibility and quality

- Text contrast must be at least WCAG AA. Body text on white uses `#121C2A`
  or `#594139`; don't put orange `#FF6B35` text on white for small text (use
  `#AB3500` instead).
- Show a visible focus ring everywhere (2 px orange ring).
- Hit targets are at least 40 px.
- Icons that act as buttons have tooltips and labels.
- Status is never shown by colour alone: always a dot plus a text label.
- Numbers right-aligned in tables; money always shows `₹`.
- Dates use relative times for recent events ("12 min ago") and absolute
  dates beyond that ("28 Oct, 5:09 PM").

---

## 10. Tone of microcopy

Friendly, short and action-first, matching the app. Examples:
- "Kitchens Live"
- "Mark as Preparing"
- "Dish saved"
- "No matches — try a different search"
- "You saved ₹130 on this order"

Use Indian English, rupees, and Bengaluru locations (Indiranagar,
Koramangala, HAL 2nd Stage).
