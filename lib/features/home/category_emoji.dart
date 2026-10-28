/// Presentation only: an emoji for known DummyJSON recipe tags. Unknown
/// tags (new ones the API adds later) fall back to a plate.
String emojiForCategory(String tag) => switch (tag.toLowerCase()) {
      'pizza' || 'margherita pizza' => '🍕',
      'biryani' || 'rice' => '🍛',
      'pasta' || 'pesto pasta' => '🍝',
      'dessert' || 'tiramisu' || 'cookies' => '🍰',
      'salad' || 'quinoa' || 'vegetarian' => '🥗',
      'chicken' || 'kebabs' || 'grilling' => '🍗',
      'beef' => '🥩',
      'shrimp' => '🍤',
      'curry' || 'butter chicken' || 'karahi' => '🍲',
      'soup' || 'ramen' => '🍜',
      'smoothie' || 'lassi' => '🥤',
      'cocktail' || 'caipirinha' => '🍹',
      'stir-fry' || 'asian' => '🥡',
      'indian' || 'pakistani' => '🫓',
      'mexican' || 'salsa' || 'street food' => '🌮',
      'japanese' || 'sushi rolls' => '🍣',
      'italian' => '🇮🇹',
      'dosa' => '🥞',
      'baking' => '🥐',
      _ => '🍽️',
    };
