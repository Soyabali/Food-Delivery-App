/// Seed "database" for the on-device mock backend. This is backend data:
/// screens never import it, they fetch it through services.
///
/// Restaurant menus are not stored here. Each restaurant lists DummyJSON tags
/// (`menuTags`); the app builds the menu from GET /recipes/tag/{tag}.
abstract final class MockSeedData {
  static String recipeImage(int id) =>
      'https://cdn.dummyjson.com/recipe-images/$id.webp';

  /// Demo account created on first launch (mock mode only).
  static const demoEmail = 'rahul.sharma@example.com';
  static const demoPassword = 'supersecret123';
  static const demoName = 'Rahul Sharma';
  static const demoPhone = '98765 43210';

  static List<Map<String, dynamic>> restaurants() => [
        {
          'id': 'royal-biryani',
          'name': 'Royal Biryani House',
          'cuisines': ['Biryani', 'Pakistani', 'Mughlai'],
          'rating': 4.8,
          'deliveryTime': '25-30 mins',
          'costForOne': 250,
          'distanceKm': 2.4,
          'imageUrl': recipeImage(11),
          'deliveryFee': 0,
          'popular': true,
          'hasSpiceLevels': true,
          'menuTags': ['Pakistani'],
          'addOns': [
            {
              'id': 'salan',
              'name': 'Extra Mirchi Ka Salan',
              'subtitle': 'Spicy peanut-sesame gravy',
              'price': 30,
            },
            {
              'id': 'raita',
              'name': 'Mint Raita',
              'subtitle': 'Cooling yoghurt with fresh mint',
              'price': 25,
            },
            {
              'id': 'papad',
              'name': 'Roasted Papad & Salad',
              'subtitle': 'Crisp papad + onion lemon rings',
              'price': 20,
            },
          ],
        },
        {
          'id': 'pizza-roma',
          'name': 'Pizza Roma Cucina',
          'cuisines': ['Italian', 'Wood-fired Pizza'],
          'rating': 4.6,
          'deliveryTime': '20-25 mins',
          'costForOne': 350,
          'distanceKm': 3.1,
          'imageUrl': recipeImage(1),
          'deliveryFee': 20,
          'popular': true,
          'menuTags': ['Italian', 'Pizza', 'Pasta'],
          'addOns': [
            {'id': 'cheese', 'name': 'Extra Mozzarella', 'price': 60},
            {'id': 'olives', 'name': 'Black Olives', 'price': 40},
            {'id': 'garlic-dip', 'name': 'Garlic Dip', 'price': 30},
          ],
        },
        {
          'id': 'wok-spice',
          'name': 'Wok & Spice',
          'cuisines': ['Asian', 'Thai', 'Korean'],
          'rating': 4.7,
          'deliveryTime': '15-20 mins',
          'costForOne': 300,
          'distanceKm': 1.8,
          'imageUrl': recipeImage(21),
          'deliveryFee': 25,
          'badge': 'Trending',
          'popular': true,
          'hasSpiceLevels': true,
          'menuTags': ['Stir-fry', 'Thai', 'Korean'],
          'addOns': [
            {'id': 'rice', 'name': 'Steamed Jasmine Rice', 'price': 40},
            {'id': 'chilli-oil', 'name': 'Chilli Oil', 'price': 15},
          ],
        },
        {
          'id': 'green-bowl',
          'name': 'Green Bowl Kitchen',
          'cuisines': ['Healthy', 'Salads', 'Smoothies'],
          'rating': 4.9,
          'deliveryTime': '10-15 mins',
          'costForOne': 180,
          'distanceKm': 1.2,
          'imageUrl': recipeImage(6),
          'isPureVeg': true,
          'deliveryFee': 15,
          'menuTags': ['Salad', 'Vegetarian', 'Mediterranean', 'Smoothie'],
          'addOns': [
            {'id': 'tofu', 'name': 'Grilled Tofu', 'price': 50},
            {'id': 'feta', 'name': 'Feta Crumble', 'price': 40},
          ],
        },
        {
          'id': 'tokyo-ramen',
          'name': 'Tokyo Ramen Bar',
          'cuisines': ['Japanese', 'Ramen', 'Sushi'],
          'rating': 4.5,
          'deliveryTime': '25-30 mins',
          'costForOne': 400,
          'distanceKm': 3.6,
          'imageUrl': recipeImage(16),
          'deliveryFee': 30,
          'menuTags': ['Japanese'],
          'addOns': [
            {'id': 'noodles', 'name': 'Extra Noodles', 'price': 50},
            {'id': 'nori', 'name': 'Toasted Nori', 'price': 20},
          ],
        },
        {
          'id': 'casa-mexicana',
          'name': 'Casa Mexicana',
          'cuisines': ['Mexican', 'Street Food'],
          'rating': 4.4,
          'deliveryTime': '20-25 mins',
          'costForOne': 280,
          'distanceKm': 2.9,
          'imageUrl': recipeImage(36),
          'deliveryFee': 0,
          'hasSpiceLevels': true,
          'menuTags': ['Mexican'],
          'addOns': [
            {'id': 'guac', 'name': 'Guacamole', 'price': 50},
            {'id': 'sour-cream', 'name': 'Sour Cream', 'price': 30},
          ],
        },
        {
          'id': 'mezze-house',
          'name': 'Mezze House',
          'cuisines': ['Lebanese', 'Greek', 'Moroccan'],
          'rating': 4.6,
          'deliveryTime': '25-30 mins',
          'costForOne': 320,
          'distanceKm': 4.2,
          'imageUrl': recipeImage(29),
          'deliveryFee': 25,
          'menuTags': ['Lebanese', 'Greek', 'Moroccan', 'Turkish'],
          'addOns': [
            {'id': 'hummus', 'name': 'Hummus', 'price': 40},
            {'id': 'pita', 'name': 'Warm Pita', 'price': 30},
          ],
        },
        {
          'id': 'apna-kitchen',
          'name': 'Apna Cloud Kitchen',
          'cuisines': ['Desserts', 'Drinks', 'Global'],
          'rating': 4.3,
          'deliveryTime': '20-25 mins',
          'costForOne': 220,
          'distanceKm': 2.0,
          'imageUrl': recipeImage(35),
          'deliveryFee': 20,
          'servesAllRecipes': true,
          'menuTags': [
            'Dessert',
            'Cocktail',
            'Soup',
            'Dosa',
            'Spanish',
            'Vietnamese',
            'Hawaiian',
            'Brazilian',
            'Smoothie',
          ],
          'addOns': <Map<String, dynamic>>[],
        },
      ];

  static List<Map<String, dynamic>> offers() => [
        {
          'code': 'APNA50',
          'title': '50% OFF',
          'subtitle': 'Up to ₹150 on first 3 orders',
          'type': 'percent',
          'value': 50,
          'maxDiscount': 150,
          'minOrder': 0,
          'maxOrdersPerUser': 3,
          'imageUrl': recipeImage(11),
          'featured': true,
        },
        {
          'code': 'APNA100',
          'title': '₹100 OFF',
          'subtitle': 'On orders above ₹300',
          'type': 'flat',
          'value': 100,
          'minOrder': 300,
          'imageUrl': recipeImage(20),
        },
      ];

  static List<Map<String, dynamic>> notifications(DateTime now) => [
        {
          'id': 'n1',
          'title': '50% OFF on your first 3 orders',
          'body': 'Use code APNA50 at checkout. Up to ₹150 off.',
          'kind': 'offer',
          'createdAt': now.subtract(const Duration(hours: 2)).toIso8601String(),
        },
        {
          'id': 'n2',
          'title': 'Free delivery above ₹199',
          'body': 'Orders above ₹199 ship free from every restaurant.',
          'kind': 'delivery',
          'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
        },
      ];

  static List<Map<String, dynamic>> defaultAddresses() => [
        {
          'id': 'home',
          'label': 'Home',
          'line': '123 Main Street, Sector 4, Indiranagar, Bengaluru',
          'icon': 'home',
          'isDefault': true,
        },
        {
          'id': 'work',
          'label': 'Work',
          'line': '4th Floor, Prestige Tech Park, Outer Ring Road, Bengaluru',
          'icon': 'work',
        },
      ];

  // Pricing rules the mock backend applies when calculating cart totals.
  static const standardDeliveryFee = 30;
  static const freeDeliveryThreshold = 199;
  static const taxRatePercent = 5.0;

  /// Accelerated demo timeline (from placement) for order status.
  static const preparingAfter = Duration(seconds: 10);
  static const outForDeliveryAfter = Duration(seconds: 60);
  static const deliveredAfter = Duration(seconds: 120);
}
