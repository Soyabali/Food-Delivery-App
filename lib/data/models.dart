// App-side data models. These are the app's own shapes: API responses are
// converted into them by `fromJson` (backend) or the recipe adapter
// (DummyJSON), so screens never see raw provider JSON.

double _toDouble(Object? v) => (v as num).toDouble();
List<String> _strings(Object? v) =>
    (v as List? ?? const []).map((e) => e.toString()).toList();

class DishOption {
  const DishOption({
    required this.id,
    required this.name,
    this.subtitle,
    this.price = 0,
  });

  factory DishOption.fromJson(Map<String, dynamic> j) => DishOption(
        id: j['id'] as String,
        name: j['name'] as String,
        subtitle: j['subtitle'] as String?,
        price: (j['price'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String name;
  final String? subtitle;
  final int price;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (subtitle != null) 'subtitle': subtitle,
        'price': price,
      };
}

class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.cuisines,
    required this.rating,
    required this.deliveryTime,
    required this.costForOne,
    required this.distanceKm,
    required this.image,
    this.isPureVeg = false,
    this.deliveryFee = 0,
    this.badge,
    this.popular = false,
    this.menuTags = const [],
    this.addOns = const [],
    this.hasSpiceLevels = false,
    this.servesAllRecipes = false,
  });

  factory Restaurant.fromJson(Map<String, dynamic> j) => Restaurant(
        id: j['id'] as String,
        name: j['name'] as String,
        cuisines: _strings(j['cuisines']),
        rating: _toDouble(j['rating']),
        deliveryTime: j['deliveryTime'] as String,
        costForOne: (j['costForOne'] as num).toInt(),
        distanceKm: _toDouble(j['distanceKm']),
        image: j['imageUrl'] as String,
        isPureVeg: j['isPureVeg'] as bool? ?? false,
        deliveryFee: (j['deliveryFee'] as num?)?.toInt() ?? 0,
        badge: j['badge'] as String?,
        popular: j['popular'] as bool? ?? false,
        menuTags: _strings(j['menuTags']),
        addOns: (j['addOns'] as List? ?? const [])
            .map((e) => DishOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasSpiceLevels: j['hasSpiceLevels'] as bool? ?? false,
        servesAllRecipes: j['servesAllRecipes'] as bool? ?? false,
      );

  final String id;
  final String name;
  final List<String> cuisines;
  final double rating;

  /// e.g. "25-30 mins"
  final String deliveryTime;
  final int costForOne;
  final double distanceKm;

  /// Image URL (or bundled asset path).
  final String image;
  final bool isPureVeg;

  /// 0 means free delivery.
  final int deliveryFee;
  final String? badge;
  final bool popular;

  /// DummyJSON recipe tags that make up this restaurant's menu.
  final List<String> menuTags;

  /// Extras the restaurant offers with any dish.
  final List<DishOption> addOns;
  final bool hasSpiceLevels;

  /// Catch-all kitchen for recipes no other restaurant's tags match.
  final bool servesAllRecipes;

  String get cuisineLine => cuisines.join(' • ');
  int get maxMinutes {
    final parts = deliveryTime.split(RegExp(r'[^0-9]+'));
    return int.tryParse(parts.length > 1 ? parts[1] : parts[0]) ?? 30;
  }
}

/// A sellable menu item: a DummyJSON recipe combined with restaurant context
/// and demo pricing (see `recipe_adapter.dart`).
class Dish {
  const Dish({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    required this.isVeg,
    required this.category,
    this.rating = 0,
    this.ratingCount = 0,
    this.prepTime = '',
    this.kcal,
    this.tag,
    this.badge,
    this.ingredients = const [],
    this.mealTypes = const [],
    this.tags = const [],
    this.difficulty,
    this.servings,
    this.portions = const [],
    this.spiceLevels = const [],
    this.addOns = const [],
  });

  /// DummyJSON recipe id.
  final int id;
  final String restaurantId;
  final String restaurantName;
  final String name;
  final String description;

  /// Demo price in rupees for the first portion.
  final int price;
  final String image;
  final bool isVeg;
  final String category;
  final double rating;
  final int ratingCount;
  final String prepTime;
  final int? kcal;
  final String? tag;
  final String? badge;
  final List<String> ingredients;
  final List<String> mealTypes;
  final List<String> tags;
  final String? difficulty;
  final int? servings;
  final List<DishOption> portions;
  final List<String> spiceLevels;
  final List<DishOption> addOns;
}

/// One line of the server-side cart.
class CartLine {
  const CartLine({
    required this.id,
    required this.recipeId,
    required this.restaurantId,
    required this.name,
    required this.image,
    required this.isVeg,
    required this.unitPrice,
    required this.quantity,
    this.portion,
    this.spiceLevel,
    this.addOns = const [],
    this.note,
  });

  factory CartLine.fromJson(Map<String, dynamic> j) => CartLine(
        id: j['id'] as String,
        recipeId: (j['recipeId'] as num).toInt(),
        restaurantId: j['restaurantId'] as String,
        name: j['name'] as String,
        image: j['image'] as String,
        isVeg: j['isVeg'] as bool? ?? false,
        unitPrice: (j['unitPrice'] as num).toInt(),
        quantity: (j['quantity'] as num).toInt(),
        portion: j['portion'] as String?,
        spiceLevel: j['spiceLevel'] as String?,
        addOns: _strings(j['addOns']),
        note: j['note'] as String?,
      );

  final String id;
  final int recipeId;
  final String restaurantId;
  final String name;
  final String image;
  final bool isVeg;
  final int unitPrice;
  final int quantity;
  final String? portion;
  final String? spiceLevel;
  final List<String> addOns;
  final String? note;

  int get lineTotal => unitPrice * quantity;

  String get displayName =>
      portion == null ? name : '$name (${portion!.split(' ').first})';

  String? get customisation {
    final parts = [
      if (spiceLevel != null) '$spiceLevel Spice',
      ...addOns,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeId': recipeId,
        'restaurantId': restaurantId,
        'name': name,
        'image': image,
        'isVeg': isVeg,
        'unitPrice': unitPrice,
        'quantity': quantity,
        if (portion != null) 'portion': portion,
        if (spiceLevel != null) 'spiceLevel': spiceLevel,
        'addOns': addOns,
        if (note != null) 'note': note,
      };
}

/// Payload for `POST /cart/items`.
class AddToCartRequest {
  const AddToCartRequest({
    required this.dish,
    required this.quantity,
    this.portion,
    this.spiceLevel,
    this.addOns = const [],
    this.note,
    this.replaceCart = false,
  });

  final Dish dish;
  final int quantity;
  final DishOption? portion;
  final String? spiceLevel;
  final List<DishOption> addOns;
  final String? note;

  /// Clear a cart from another restaurant first.
  final bool replaceCart;

  int get unitPrice =>
      dish.price +
      (portion?.price ?? 0) +
      addOns.fold(0, (sum, a) => sum + a.price);

  Map<String, dynamic> toJson() => {
        'recipeId': dish.id,
        'restaurantId': dish.restaurantId,
        'name': dish.name,
        'image': dish.image,
        'isVeg': dish.isVeg,
        // A real backend must price items itself; the mock trusts this.
        'unitPrice': unitPrice,
        'quantity': quantity,
        if (portion != null) 'portion': portion!.name,
        if (spiceLevel != null) 'spiceLevel': spiceLevel,
        'addOns': addOns.map((a) => a.name).toList(),
        if (note != null) 'note': note,
        'replaceCart': replaceCart,
      };
}

class CartRestaurant {
  const CartRestaurant({
    required this.id,
    required this.name,
    required this.distanceKm,
  });

  factory CartRestaurant.fromJson(Map<String, dynamic> j) => CartRestaurant(
        id: j['id'] as String,
        name: j['name'] as String,
        distanceKm: _toDouble(j['distanceKm']),
      );

  final String id;
  final String name;
  final double distanceKm;
}

/// Cart snapshot including totals calculated by the backend.
class Cart {
  const Cart({
    this.items = const [],
    this.restaurant,
    this.couponCode,
    this.couponMessage,
    this.instructions = '',
    this.itemTotal = 0,
    this.deliveryFee = 0,
    this.standardDeliveryFee = 0,
    this.freeDeliveryThreshold = 0,
    this.taxes = 0,
    this.taxRatePercent = 0,
    this.discount = 0,
    this.total = 0,
    this.savings = 0,
  });

  static const empty = Cart();

  factory Cart.fromJson(Map<String, dynamic> j) {
    final t = j['totals'] as Map<String, dynamic>;
    return Cart(
      items: (j['items'] as List)
          .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      restaurant: j['restaurant'] == null
          ? null
          : CartRestaurant.fromJson(j['restaurant'] as Map<String, dynamic>),
      couponCode: j['couponCode'] as String?,
      couponMessage: j['couponMessage'] as String?,
      instructions: j['instructions'] as String? ?? '',
      itemTotal: (t['itemTotal'] as num).toInt(),
      deliveryFee: (t['deliveryFee'] as num).toInt(),
      standardDeliveryFee: (t['standardDeliveryFee'] as num).toInt(),
      freeDeliveryThreshold: (t['freeDeliveryThreshold'] as num).toInt(),
      taxes: _toDouble(t['taxes']),
      taxRatePercent: _toDouble(t['taxRatePercent']),
      discount: (t['discount'] as num).toInt(),
      total: _toDouble(t['total']),
      savings: (t['savings'] as num).toInt(),
    );
  }

  final List<CartLine> items;
  final CartRestaurant? restaurant;

  /// Applied coupon code (may be applied but not yet eligible).
  final String? couponCode;

  /// e.g. "Add ₹85 more to use APNA100".
  final String? couponMessage;
  final String instructions;
  final int itemTotal;
  final int deliveryFee;

  /// Fee this order would cost without free delivery.
  final int standardDeliveryFee;
  final int freeDeliveryThreshold;
  final double taxes;
  final double taxRatePercent;
  final int discount;
  final double total;
  final int savings;

  bool get isEmpty => items.isEmpty;
  bool get freeDelivery => !isEmpty && deliveryFee == 0;
  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);
  int quantityOfDish(int recipeId) => items
      .where((i) => i.recipeId == recipeId)
      .fold(0, (sum, i) => sum + i.quantity);
}

class DeliveryAddress {
  const DeliveryAddress({
    required this.id,
    required this.label,
    required this.line,
    this.icon = 'home',
    this.isDefault = false,
  });

  factory DeliveryAddress.fromJson(Map<String, dynamic> j) => DeliveryAddress(
        id: j['id'] as String,
        label: j['label'] as String,
        line: j['line'] as String,
        icon: j['icon'] as String? ?? 'home',
        isDefault: j['isDefault'] as bool? ?? false,
      );

  final String id;
  final String label;
  final String line;
  final String icon;
  final bool isDefault;

  String get short => line.split(',').first;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'line': line,
        'icon': icon,
        'isDefault': isDefault,
      };
}

class Offer {
  const Offer({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.value,
    this.maxDiscount,
    this.minOrder = 0,
    this.imageUrl,
    this.featured = false,
  });

  factory Offer.fromJson(Map<String, dynamic> j) => Offer(
        code: j['code'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        type: j['type'] as String,
        value: (j['value'] as num).toInt(),
        maxDiscount: (j['maxDiscount'] as num?)?.toInt(),
        minOrder: (j['minOrder'] as num?)?.toInt() ?? 0,
        imageUrl: j['imageUrl'] as String?,
        featured: j['featured'] as bool? ?? false,
      );

  final String code;
  final String title;
  final String subtitle;

  /// "percent" or "flat".
  final String type;
  final int value;
  final int? maxDiscount;
  final int minOrder;
  final String? imageUrl;
  final bool featured;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        kind: j['kind'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  final String id;
  final String title;
  final String body;

  /// "offer" | "delivery" | "info"
  final String kind;
  final DateTime createdAt;
}

class Favorites {
  const Favorites({this.restaurants = const {}, this.dishes = const {}});

  factory Favorites.fromJson(Map<String, dynamic> j) => Favorites(
        restaurants: _strings(j['restaurants']).toSet(),
        dishes: _strings(j['dishes']).toSet(),
      );

  final Set<String> restaurants;
  final Set<String> dishes;

  int get count => restaurants.length + dishes.length;
}

enum OrderStatus { placed, preparing, outForDelivery, delivered }

enum PaymentMethod {
  upi('UPI', 'Paid via UPI'),
  card('Card', 'Paid via Card'),
  cod('Cash on Delivery', 'Pay on delivery');

  const PaymentMethod(this.label, this.paidLabel);
  final String label;
  final String paidLabel;
}

class OrderRestaurant {
  const OrderRestaurant({
    required this.id,
    required this.name,
    required this.image,
    required this.distanceKm,
    required this.deliveryTime,
  });

  factory OrderRestaurant.fromJson(Map<String, dynamic> j) => OrderRestaurant(
        id: j['id'] as String,
        name: j['name'] as String,
        image: j['imageUrl'] as String,
        distanceKm: _toDouble(j['distanceKm']),
        deliveryTime: j['deliveryTime'] as String,
      );

  final String id;
  final String name;
  final String image;
  final double distanceKm;
  final String deliveryTime;
}

class Order {
  const Order({
    required this.id,
    required this.restaurant,
    required this.items,
    required this.amount,
    required this.address,
    required this.payment,
    required this.placedAt,
    required this.eta,
    required this.status,
    required this.statusTimes,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] as String,
        restaurant:
            OrderRestaurant.fromJson(j['restaurant'] as Map<String, dynamic>),
        items: (j['items'] as List)
            .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        amount: _toDouble(j['amount']),
        address: DeliveryAddress.fromJson(j['address'] as Map<String, dynamic>),
        payment: PaymentMethod.values.byName(j['paymentMethod'] as String),
        placedAt: DateTime.parse(j['placedAt'] as String),
        eta: DateTime.parse(j['eta'] as String),
        status: OrderStatus.values.byName(j['status'] as String),
        statusTimes: {
          for (final e in (j['statusTimes'] as Map<String, dynamic>).entries)
            OrderStatus.values.byName(e.key): DateTime.parse(e.value as String),
        },
      );

  final String id;
  final OrderRestaurant restaurant;
  final List<CartLine> items;
  final double amount;
  final DeliveryAddress address;
  final PaymentMethod payment;
  final DateTime placedAt;
  final DateTime eta;
  final OrderStatus status;
  final Map<OrderStatus, DateTime> statusTimes;

  bool get isActive => status != OrderStatus.delivered;
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);
}
