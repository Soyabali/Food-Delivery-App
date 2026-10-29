"""Dashboard API (/api/admin/*)."""

import base64

from tests.test_mobile_api import add, place

PNG_1X1 = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg=="
)


def test_customers_cannot_use_admin_api(client, user):
    assert client.get("/api/admin/stats", headers=user).status_code == 403
    assert client.get("/api/admin/stats").status_code == 401


def test_restaurant_crud_with_add_ons(client, admin):
    body = {
        "slug": "dosa-corner", "name": "Dosa Corner", "cuisines": ["South Indian"],
        "latitude": 12.97, "longitude": 77.64, "deliveryTimeMin": 15, "deliveryTimeMax": 20,
        "costForOne": 150, "addOns": [{"name": "Extra Chutney", "price": 15}],
    }
    res = client.post("/api/admin/restaurants", headers=admin, json=body)
    assert res.status_code == 201, res.text
    r = res.json()
    assert r["addOns"][0]["name"] == "Extra Chutney" and r["menuItemCount"] == 0

    assert client.post("/api/admin/restaurants", headers=admin, json=body).status_code == 409
    bad = client.post("/api/admin/restaurants", headers=admin, json={**body, "slug": "Bad Slug"})
    assert bad.status_code == 422

    keep = r["addOns"][0]["id"]
    patched = client.patch(f"/api/admin/restaurants/{r['id']}", headers=admin, json={
        "name": "Dosa Corner Express",
        "addOns": [{"id": keep, "name": "Coconut Chutney", "price": 20}, {"name": "Ghee", "price": 25}],
    }).json()
    assert patched["name"] == "Dosa Corner Express"
    assert [a["name"] for a in patched["addOns"]] == ["Coconut Chutney", "Ghee"]
    assert patched["addOns"][0]["id"] == keep

    times = client.patch(f"/api/admin/restaurants/{r['id']}", headers=admin,
                         json={"deliveryTimeMin": 40, "deliveryTimeMax": 30})
    assert times.status_code == 400
    assert client.get("/api/restaurants/dosa-corner").status_code == 200


def test_menu_item_crud_and_live_price(client, admin, user):
    restaurants = client.get("/api/admin/restaurants", headers=admin, params={"q": "royal"}).json()
    rid = restaurants["items"][0]["id"]
    res = client.post("/api/admin/menu-items", headers=admin, json={
        "restaurantId": rid, "name": "Hyderabadi Haleem", "price": 280, "isVeg": False,
        "variants": [{"name": "Regular", "isDefault": True}, {"name": "Family", "priceDelta": 200}],
    })
    assert res.status_code == 201, res.text
    item = res.json()
    assert item["restaurantName"] == "Royal Biryani House" and len(item["variants"]) == 2

    two_defaults = client.post("/api/admin/menu-items", headers=admin, json={
        "restaurantId": rid, "name": "X Dish", "price": 100,
        "variants": [{"name": "A", "isDefault": True}, {"name": "B", "isDefault": True}],
    })
    assert two_defaults.status_code == 400
    assert client.post("/api/admin/menu-items", headers=admin,
                       json={"restaurantId": 999999, "name": "Ghost", "price": 100}).status_code == 400

    # The mobile API immediately serves the new dish, priced by the server.
    assert client.get(f"/api/menu-items/{item['id']}").json()["price"] == 280
    cart = add(client, user, menuItemId=item["id"]).json()
    assert cart["items"][0]["unitPrice"] == 280

    client.patch(f"/api/admin/menu-items/{item['id']}", headers=admin, json={"price": 300})
    assert client.get("/api/cart", headers=user).json()["items"][0]["unitPrice"] == 300

    client.patch(f"/api/admin/menu-items/{item['id']}", headers=admin, json={"isAvailable": False})
    assert client.get(f"/api/menu-items/{item['id']}").status_code == 404


def test_deleting_a_dish_keeps_order_history(client, admin, user):
    add(client, user, menuItemId=11)
    number = place(client, user).json()["id"]
    assert client.delete("/api/admin/menu-items/11", headers=admin).status_code == 204
    order = client.get(f"/api/orders/{number}", headers=user).json()
    assert order["items"][0]["name"] == "Chicken Biryani"


def test_restaurant_with_orders_is_deactivated_not_deleted(client, admin, user):
    add(client, user, menuItemId=11)
    place(client, user)
    rid = client.get("/api/admin/restaurants", headers=admin, params={"q": "royal"}).json()["items"][0]["id"]
    assert client.delete(f"/api/admin/restaurants/{rid}", headers=admin).status_code == 204
    assert client.get(f"/api/admin/restaurants/{rid}", headers=admin).json()["isActive"] is False
    assert client.get("/api/restaurants/royal-biryani").status_code == 404


def test_order_status_workflow(client, admin, user):
    add(client, user, menuItemId=11)
    number = place(client, user, payment="cod").json()["id"]
    orders = client.get("/api/admin/orders", headers=admin, params={"status": "placed"}).json()
    assert orders["total"] == 1 and orders["items"][0]["customerName"] == "Rahul Sharma"
    oid = orders["items"][0]["id"]

    skip = client.patch(f"/api/admin/orders/{oid}/status", headers=admin, json={"status": "delivered"})
    assert skip.status_code == 400

    for step in ("preparing", "out_for_delivery", "delivered"):
        res = client.patch(f"/api/admin/orders/{oid}/status", headers=admin, json={"status": step})
        assert res.status_code == 200, res.text
    detail = res.json()
    assert detail["paymentStatus"] == "paid"  # COD is paid on delivery
    assert [e["status"] for e in detail["statusHistory"]] == ["placed", "preparing", "out_for_delivery", "delivered"]

    tracked = client.get(f"/api/orders/{number}", headers=user).json()
    assert tracked["status"] == "delivered"
    assert set(tracked["statusTimes"]) == {"placed", "preparing", "outForDelivery", "delivered"}


def test_categories_offers_users_notifications(client, admin):
    cat = client.post("/api/admin/categories", headers=admin,
                      json={"name": "Breakfast", "slug": "breakfast", "emoji": "🍳"})
    assert cat.status_code == 201
    assert client.post("/api/admin/categories", headers=admin,
                       json={"name": "Breakfast", "slug": "breakfast-2"}).status_code == 409

    offer = client.post("/api/admin/offers", headers=admin, json={
        "code": "weekend20", "title": "20% OFF", "subtitle": "Weekends only",
        "discountType": "percent", "value": 20, "maxDiscount": 80})
    assert offer.status_code == 201 and offer.json()["code"] == "WEEKEND20"
    assert client.post("/api/admin/offers", headers=admin, json={
        "code": "BAD", "title": "x", "subtitle": "x", "discountType": "percent", "value": 150}).status_code == 400
    assert any(o["code"] == "WEEKEND20" for o in client.get("/api/offers").json())

    users = client.get("/api/admin/users", headers=admin, params={"role": "admin"}).json()
    me = users["items"][0]
    assert client.patch(f"/api/admin/users/{me['id']}", headers=admin, json={"role": "customer"}).status_code == 400

    sent = client.post("/api/admin/notifications", headers=admin, json={"title": "Hi", "body": "Hello all"})
    assert sent.status_code == 201
    assert client.get("/api/notifications").json()[0]["title"] == "Hi"


def test_stats(client, admin, user):
    add(client, user, menuItemId=11, quantity=2)
    place(client, user)
    stats = client.get("/api/admin/stats", headers=admin).json()
    assert stats["ordersToday"] == 1 and stats["activeOrders"] == 1
    assert stats["revenueToday"] > 0
    assert stats["topItems"][0]["name"] == "Chicken Biryani" and stats["topItems"][0]["quantity"] == 2
    assert stats["totalMenuItems"] == 50


def test_image_upload(client, admin):
    res = client.post("/api/admin/uploads", headers=admin, files={"file": ("dish.png", PNG_1X1, "image/png")})
    assert res.status_code == 201, res.text
    path = res.json()["url"].split("http://localhost:8000")[1]
    assert client.get(path).content == PNG_1X1
    bad = client.post("/api/admin/uploads", headers=admin, files={"file": ("x.txt", b"hi", "text/plain")})
    assert bad.status_code == 400


def test_media_library_tracks_usage(client, admin):
    up = client.post("/api/admin/uploads", headers=admin, files={"file": ("biryani.png", PNG_1X1, "image/png")}).json()
    lib = client.get("/api/admin/uploads", headers=admin).json()
    assert lib["total"] == 1
    m = lib["items"][0]
    assert m["id"] == up["id"] and m["originalName"] == "biryani.png" and m["sizeBytes"] == len(PNG_1X1)
    assert m["uploadedBy"] == "Apna Admin" and m["usedBy"] == []

    # The admin's change is what the mobile app reads (same table).
    cat = client.get("/api/admin/categories", headers=admin).json()[0]
    assert client.patch(f"/api/admin/categories/{cat['id']}", headers=admin, json={"imageUrl": up["url"]}).status_code == 200
    assert any(c["imageUrl"] == up["url"] for c in client.get("/api/categories").json())

    used = client.get("/api/admin/uploads", headers=admin).json()["items"][0]["usedBy"]
    assert used == [{"kind": "category", "id": cat["id"], "name": cat["name"]}]
    blocked = client.delete(f"/api/admin/uploads/{up['id']}", headers=admin)
    assert blocked.status_code == 409 and cat["name"] in blocked.json()["message"]

    client.patch(f"/api/admin/categories/{cat['id']}", headers=admin, json={"imageUrl": None})
    assert client.delete(f"/api/admin/uploads/{up['id']}", headers=admin).status_code == 204
    assert client.get("/api/admin/uploads", headers=admin).json()["total"] == 0
    assert client.get(up["url"].split("http://localhost:8000")[1]).status_code == 404
    assert client.delete(f"/api/admin/uploads/{up['id']}", headers=admin).status_code == 404
