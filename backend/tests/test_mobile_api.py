"""Mobile app contract: auth, catalogue, user data, cart and orders."""

from tests.conftest import DEMO, login


def test_health(client):
    assert client.get("/health").json() == {"status": "ok", "database": "ok"}


# ------------------------------------------------------------------ auth


def test_login_and_me(client, user):
    me = client.get("/api/auth/me", headers=user).json()
    assert me["name"] == "Rahul Sharma" and me["email"] == DEMO[0]


def test_wrong_password_uses_message_shape(client):
    res = client.post("/api/auth/login", json={"email": DEMO[0], "password": "nope"})
    assert res.status_code == 401
    assert res.json() == {"message": "Incorrect email or password."}


def test_email_is_case_insensitive(client):
    login(client, DEMO[0].upper(), DEMO[1])


def test_register_duplicate_and_validation(client):
    body = {"name": "Asha Verma", "email": "asha@example.com", "phone": "98765 43210", "password": "longenough"}
    res = client.post("/api/auth/register", json=body)
    assert res.status_code == 201
    token = {"Authorization": f"Bearer {res.json()['token']}"}
    book = client.get("/api/addresses", headers=token).json()
    assert len(book["items"]) == 2 and book["selectedId"] is not None

    assert client.post("/api/auth/register", json={**body, "email": "ASHA@example.com"}).status_code == 409
    bad = client.post("/api/auth/register", json={**body, "email": "x@y.com", "password": "short"})
    assert bad.status_code == 422
    assert bad.json()["message"].startswith("password:")


def test_protected_routes_need_token(client):
    assert client.get("/api/cart").status_code == 401
    assert client.get("/api/cart").json()["message"] == "Please log in to continue."


def test_logout_revokes_token(client, user):
    assert client.post("/api/auth/logout", headers=user).status_code == 204
    assert client.get("/api/auth/me", headers=user).status_code == 401


def test_change_password(client, user):
    bad = client.post("/api/auth/change-password", headers=user,
                      json={"currentPassword": "wrong", "newPassword": "NewPass#123"})
    assert bad.status_code == 400
    ok = client.post("/api/auth/change-password", headers=user,
                     json={"currentPassword": DEMO[1], "newPassword": "NewPass#123"})
    assert ok.status_code == 200
    login(client, DEMO[0], "NewPass#123")


def test_forgot_password_does_not_reveal_accounts(client):
    a = client.post("/api/auth/forgot-password", json={"email": DEMO[0]}).json()
    b = client.post("/api/auth/forgot-password", json={"email": "nobody@example.com"}).json()
    assert a == b


# ------------------------------------------------------------- catalogue


def test_restaurants_shape_and_distance(client, user):
    data = client.get("/api/restaurants", params={"sort": "distance"}, headers=user).json()
    assert len(data) == 8
    first = data[0]
    for key in ("id", "name", "cuisines", "rating", "deliveryTime", "costForOne", "distanceKm", "imageUrl",
                "isPureVeg", "deliveryFee", "popular", "menuTags", "addOns", "hasSpiceLevels"):
        assert key in first
    distances = [r["distanceKm"] for r in data]
    assert distances == sorted(distances)
    assert client.get("/api/restaurants", params={"popular": "true"}).json()[0]["popular"] is True


def test_restaurant_detail_menu_and_404(client):
    r = client.get("/api/restaurants/royal-biryani").json()
    assert r["deliveryTime"] == "25-30 mins" and len(r["addOns"]) == 3
    menu = client.get("/api/restaurants/royal-biryani/menu").json()
    assert any(m["name"] == "Chicken Biryani" for m in menu)
    assert client.get("/api/restaurants/nope").status_code == 404


def test_pure_veg_menu_has_no_meat(client):
    menu = client.get("/api/restaurants/green-bowl/menu").json()
    assert menu and all(m["isVeg"] for m in menu)


def test_menu_item_search_filters(client):
    assert any("Pizza" in m["name"] for m in client.get("/api/menu-items", params={"q": "pizza"}).json())
    desserts = client.get("/api/menu-items", params={"category": "desserts"}).json()
    assert desserts and all(m["category"] == "Desserts" for m in desserts)
    by_name = client.get("/api/menu-items", params={"category": "Desserts"}).json()
    assert [m["id"] for m in by_name] == [m["id"] for m in desserts]
    assert client.get("/api/menu-items", params={"mealType": "breakfast"}).json()
    veg = client.get("/api/menu-items", params={"veg": "true", "limit": 100}).json()
    assert all(m["isVeg"] for m in veg)
    top = client.get("/api/menu-items", params={"sort": "rating", "limit": 3}).json()
    assert top[0]["rating"] >= top[-1]["rating"]
    assert client.get("/api/menu-items", params={"q": "zzzz"}).json() == []


def test_menu_item_detail(client):
    m = client.get("/api/menu-items/11").json()
    assert m["name"] == "Chicken Biryani" and m["restaurantId"] == "royal-biryani"
    assert [p["name"] for p in m["portions"]] == ["Regular (Serves 1)", "Large (Serves 2)"]
    assert m["spiceLevels"] == ["Mild", "Medium", "Extra Hot"]
    assert len(m["addOns"]) == 3
    assert client.get("/api/menu-items/99999").status_code == 404


def test_categories_offers_notifications(client):
    assert len(client.get("/api/categories").json()) == 13
    offers = client.get("/api/offers").json()
    assert offers[0]["code"] == "APNA50" and offers[0]["featured"] is True
    assert len(client.get("/api/notifications").json()) == 2


# ------------------------------------------------------------- user data


def test_addresses_and_select(client, user):
    book = client.get("/api/addresses", headers=user).json()
    work = next(a for a in book["items"] if a["label"] == "Work")
    assert client.post(f"/api/addresses/{work['id']}/select", headers=user).json()["selectedId"] == work["id"]
    created = client.post("/api/addresses", headers=user, json={"label": "Gym", "line": "5 Park Road, Bengaluru"})
    assert created.status_code == 201 and len(created.json()["items"]) == 3
    assert client.post("/api/addresses/999999/select", headers=user).status_code == 404


def test_favorites(client, user):
    assert client.put("/api/favorites/restaurant/pizza-roma", headers=user).json()["restaurants"] == ["pizza-roma"]
    assert client.put("/api/favorites/dish/11", headers=user).json()["dishes"] == ["11"]
    assert client.delete("/api/favorites/dish/11", headers=user).json()["dishes"] == []
    assert client.put("/api/favorites/restaurant/nope", headers=user).status_code == 404


# ------------------------------------------------------------------ cart


def add(client, headers, **body):
    return client.post("/api/cart/items", headers=headers, json={"quantity": 1, **body})


def test_cart_prices_on_server_and_merges(client, user):
    # The app's current payload (recipeId + names + its own unitPrice) is accepted,
    # but the price always comes from the database.
    res = add(client, user, recipeId=11, unitPrice=1, portion="Large (Serves 2)", spiceLevel="Medium",
              addOns=["Mint Raita"])
    assert res.status_code == 200, res.text
    line = res.json()["items"][0]
    item = client.get("/api/menu-items/11").json()
    large = next(p for p in item["portions"] if p["name"].startswith("Large"))
    assert line["unitPrice"] == item["price"] + large["price"] + 25
    assert line["addOns"] == ["Mint Raita"] and line["portion"] == "Large (Serves 2)"

    again = add(client, user, menuItemId=11, portion="Large (Serves 2)", spiceLevel="Medium", addOns=["Mint Raita"])
    assert len(again.json()["items"]) == 1 and again.json()["items"][0]["quantity"] == 2


def test_cart_validation(client, user):
    assert add(client, user, menuItemId=11, portion="Huge").status_code == 400
    assert add(client, user, menuItemId=11, addOns=["Caviar"]).status_code == 400
    assert add(client, user, menuItemId=99999).status_code == 404
    assert add(client, user, menuItemId=11, quantity=50).status_code == 422
    cookies = 3  # dessert: no spice levels, no add-ons
    assert add(client, user, menuItemId=cookies, spiceLevel="Mild").status_code == 400


def test_one_restaurant_per_cart(client, user):
    add(client, user, menuItemId=11)
    conflict = add(client, user, menuItemId=1)
    assert conflict.status_code == 409
    replaced = add(client, user, menuItemId=1, replaceCart=True).json()
    assert replaced["restaurant"]["id"] == "pizza-roma" and len(replaced["items"]) == 1


def test_cart_totals_delivery_and_coupons(client, user):
    item = client.get("/api/menu-items/22").json()  # Mango Lassi, cheap
    cart = add(client, user, menuItemId=22).json()
    t = cart["totals"]
    assert t["itemTotal"] == item["price"]
    if item["price"] < 199:
        assert t["deliveryFee"] == 30  # Royal Biryani has fee 0 -> standard fee
    assert t["taxes"] == round(item["price"] * 0.05, 2)

    with_coupon = client.post("/api/cart/coupon", headers=user, json={"code": "apna100"}).json()
    assert with_coupon["couponCode"] == "APNA100"
    if item["price"] < 300:
        assert with_coupon["couponMessage"].startswith("Add ₹") and with_coupon["totals"]["discount"] == 0

    line_id = cart["items"][0]["id"]
    big = client.patch(f"/api/cart/items/{line_id}", headers=user, json={"quantity": 5}).json()["totals"]
    assert big["deliveryFee"] == 0 and big["discount"] == 100
    assert big["savings"] == 130
    assert big["total"] == round(big["itemTotal"] + big["taxes"] - 100, 2)

    fifty = client.post("/api/cart/coupon", headers=user, json={"code": "APNA50"}).json()["totals"]
    assert fifty["discount"] == min(150, int(fifty["itemTotal"] * 0.5))
    assert client.post("/api/cart/coupon", headers=user, json={"code": "FAKE"}).status_code == 400
    assert client.delete("/api/cart/coupon", headers=user).json()["couponCode"] is None


def test_cart_quantity_zero_removes_and_instructions(client, user):
    line = add(client, user, menuItemId=11).json()["items"][0]["id"]
    assert client.put("/api/cart/instructions", headers=user, json={"instructions": " Ring twice "}).json()[
        "instructions"] == "Ring twice"
    assert client.patch(f"/api/cart/items/{line}", headers=user, json={"quantity": 0}).json()["items"] == []
    assert client.patch(f"/api/cart/items/{line}", headers=user, json={"quantity": 1}).status_code == 404


# ---------------------------------------------------------------- orders


def place(client, headers, payment="upi"):
    address_id = client.get("/api/addresses", headers=headers).json()["selectedId"]
    return client.post("/api/orders", headers=headers, json={"addressId": address_id, "paymentMethod": payment})


def test_place_order_flow(client, user):
    assert place(client, user).json()["message"] == "Your cart is empty."
    add(client, user, menuItemId=11, quantity=2)
    cart_total = client.get("/api/cart", headers=user).json()["totals"]["total"]

    res = place(client, user)
    assert res.status_code == 201, res.text
    order = res.json()
    assert order["id"].startswith("AF-") and order["status"] == "placed"
    assert order["amount"] == cart_total and order["paymentStatus"] == "pending"
    assert set(order["statusTimes"]) == {"placed"}
    assert client.get("/api/cart", headers=user).json()["items"] == []

    assert client.get(f"/api/orders/{order['id']}", headers=user).json()["id"] == order["id"]
    assert len(client.get("/api/orders", headers=user).json()) == 1


def test_orders_are_private(client, user):
    add(client, user, menuItemId=11)
    number = place(client, user).json()["id"]
    other = client.post("/api/auth/register", json={
        "name": "Other", "email": "other@example.com", "phone": "9123456789", "password": "longenough"})
    token = {"Authorization": f"Bearer {other.json()['token']}"}
    assert client.get(f"/api/orders/{number}", headers=token).status_code == 404


def test_bad_address_and_payment(client, user):
    add(client, user, menuItemId=11)
    bad_addr = client.post("/api/orders", headers=user, json={"addressId": "999999", "paymentMethod": "upi"})
    assert bad_addr.status_code == 400
    bad_pay = client.post("/api/orders", headers=user, json={"addressId": "1", "paymentMethod": "bitcoin"})
    assert bad_pay.status_code == 422
