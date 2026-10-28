import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/navigation/navigation_helpers.dart';
import '../../app/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../services/food_service.dart';
import '../../services/restaurant_service.dart';
import '../../state/cart_controller.dart';
import 'widgets/restaurant_cards.dart';

/// Restaurant from GET /restaurants/{id}; menu from DummyJSON tags.
class RestaurantScreen extends StatelessWidget {
  const RestaurantScreen({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context) {
    return RequestBuilder<Restaurant>(
      requestKey: restaurantId,
      request: () => context.read<RestaurantService>().getRestaurant(restaurantId),
      loading: const Scaffold(body: Center(child: CircularProgressIndicator())),
      errorBuilder: (error, retry) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.white),
        body: Center(
          child: SingleChildScrollView(
            child: ErrorView(error: error, onRetry: retry),
          ),
        ),
      ),
      builder: (context, restaurant) => _RestaurantView(restaurant: restaurant),
    );
  }
}

class _RestaurantView extends StatelessWidget {
  const _RestaurantView({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                background: Colors.white,
                shadow: true,
                onPressed: () => context.popOrGo(AppRoutes.home),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FavouriteButton(restaurant: restaurant, size: 40),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'restaurant-${restaurant.id}',
                child: AppImage(restaurant.image),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(restaurant.name, style: AppText.headlineLg),
                      ),
                      RatingPill(restaurant.rating),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant.cuisineLine,
                    style: AppText.bodyMd.copyWith(color: AppColors.outline),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Pill(label: restaurant.deliveryTime, icon: Icons.schedule),
                      Pill(label: '${restaurant.distanceKm} km', icon: Icons.near_me),
                      Pill(
                        label: '₹${restaurant.costForOne} for one',
                        icon: Icons.payments_outlined,
                      ),
                      if (restaurant.isPureVeg)
                        const Pill(
                          label: 'Pure Veg',
                          icon: Icons.eco,
                          background: AppColors.tertiaryFixed,
                          foreground: AppColors.tertiary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Menu', style: AppText.titleMd),
                  Text(
                    'Dishes from the recipe catalogue • demo prices',
                    style: AppText.bodySm.copyWith(color: AppColors.outline),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverToBoxAdapter(
              child: RequestBuilder<List<Dish>>(
                requestKey: restaurant.id,
                request: () => context.read<FoodService>().menuFor(restaurant),
                loading: const ListSkeleton(count: 4, imageSize: 96),
                isEmpty: (d) => d.isEmpty,
                empty: const EmptyState(
                  icon: Icons.no_food_outlined,
                  title: 'Menu unavailable',
                  message: 'This restaurant has no dishes right now.',
                ),
                builder: (context, dishes) => Column(
                  children: [
                    for (final d in dishes) ...[
                      _MenuItem(dish: d),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ViewCartBar(restaurantId: restaurant.id),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    final inCart = context.select<CartController, int>(
      (c) => c.cart.restaurant?.id == dish.restaurantId
          ? c.cart.quantityOfDish(dish.id)
          : 0,
    );
    void open() => context.push(AppRoutes.dish(dish.id, restaurantId: dish.restaurantId));
    return AppCard(
      onTap: open,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VegMark(isVeg: dish.isVeg, size: 14),
                const SizedBox(height: 6),
                Text(dish.name, style: AppText.labelLg),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(rupees(dish.price), style: AppText.labelMd),
                    const SizedBox(width: 8),
                    const Icon(Icons.star, size: 13, color: AppColors.tertiary),
                    Text(
                      ' ${dish.rating} (${dish.ratingCount})',
                      style: AppText.bodySm.copyWith(color: AppColors.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  dish.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: Column(
              children: [
                AppImage(
                  dish.image,
                  width: 104,
                  height: 96,
                  borderRadius: AppRadius.xl,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: OutlinedButton(
                    onPressed: open,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryContainer,
                      side: const BorderSide(color: AppColors.primaryContainer),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.lg,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      inCart > 0 ? 'ADD MORE ($inCart)' : 'ADD',
                      style: AppText.labelSm.copyWith(
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewCartBar extends StatelessWidget {
  const _ViewCartBar({required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>().cart;
    if (cart.isEmpty || cart.restaurant?.id != restaurantId) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: PrimaryButton(
          label:
              '${cart.totalQuantity} item${cart.totalQuantity == 1 ? '' : 's'} • ${rupees(cart.itemTotal)}  |  View Cart',
          icon: Icons.arrow_forward,
          onPressed: () => context.go(AppRoutes.cart),
        ),
      ),
    );
  }
}
