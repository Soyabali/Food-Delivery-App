import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/adaptive_dialogs.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models.dart';
import '../../../services/user_service.dart';
import '../../../state/preferences_controller.dart';

Future<void> _toggleFavourite(BuildContext context, Restaurant r) async {
  try {
    final added = await context
        .read<PreferencesController>()
        .toggleFavourite(FavoriteType.restaurant, r.id);
    if (context.mounted) {
      showAppSnackBar(
        context,
        added ? '${r.name} added to favourites' : '${r.name} removed from favourites',
      );
    }
  } catch (e) {
    if (context.mounted) showAppSnackBar(context, toApiException(e).message);
  }
}

class FavouriteButton extends StatelessWidget {
  const FavouriteButton({super.key, required this.restaurant, this.size = 28});

  final Restaurant restaurant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fav = context.select<PreferencesController, bool>(
      (p) => p.isFavourite(FavoriteType.restaurant, restaurant.id),
    );
    return Semantics(
      button: true,
      toggled: fav,
      label: fav ? 'Remove from favourites' : 'Add to favourites',
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.85),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _toggleFavourite(context, restaurant),
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              fav ? Icons.favorite : Icons.favorite_border,
              size: size * 0.57,
              color: fav ? AppColors.secondary : AppColors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// 260px wide carousel card ("Popular Restaurants").
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return SizedBox(
      width: 260,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () => context.push(AppRoutes.restaurant(r.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 144,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(tag: 'restaurant-${r.id}', child: AppImage(r.image)),
                  Positioned(top: 10, left: 10, child: _badge(r)),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: FavouriteButton(restaurant: r),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.labelLg,
                        ),
                      ),
                      RatingPill(r.rating),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.cuisineLine,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySm.copyWith(color: AppColors.outline),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: AppColors.outline),
                      const SizedBox(width: 4),
                      Text(
                        r.deliveryTime,
                        style: AppText.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '₹${r.costForOne} for one',
                        style: AppText.labelSm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(Restaurant r) {
    if (r.badge != null) {
      return Pill(
        label: r.badge!,
        uppercase: true,
        background: AppColors.primary.withValues(alpha: 0.9),
        foreground: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      );
    }
    if (r.deliveryFee == 0) {
      return Pill(
        label: 'Free Delivery',
        icon: Icons.moped,
        uppercase: true,
        background: Colors.white.withValues(alpha: 0.9),
        foreground: AppColors.tertiary,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      );
    }
    return Pill(
      label: '₹${r.deliveryFee} fee',
      background: Colors.white.withValues(alpha: 0.9),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }
}

/// Compact horizontal tile ("Nearby Restaurants", search results).
class RestaurantListTile extends StatelessWidget {
  const RestaurantListTile({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    final dot = Container(
      width: 4,
      height: 4,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        shape: BoxShape.circle,
      ),
    );
    final meta = AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant);
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push(AppRoutes.restaurant(r.id)),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(r.image, borderRadius: AppRadius.lg),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: r.maxMinutes <= 15
                          ? AppColors.tertiaryFixed
                          : AppColors.surfaceContainerHigh,
                      borderRadius: AppRadius.sm,
                    ),
                    child: Text(
                      '${r.maxMinutes}m',
                      style: AppText.labelSm.copyWith(fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (r.isPureVeg) ...[
                      const VegMark(isVeg: true, size: 14),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        r.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.labelLg.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    RatingPill(r.rating),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  r.cuisineLine,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(color: AppColors.outline),
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.near_me, size: 13, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text('${r.distanceKm} km', style: meta),
                      ],
                    ),
                    dot,
                    if (r.isPureVeg)
                      Text(
                        'Pure Veg',
                        style: meta.copyWith(color: AppColors.tertiary),
                      )
                    else
                      Text(
                        r.deliveryFee == 0 ? 'Free Delivery' : '₹${r.deliveryFee} fee',
                        style: meta,
                      ),
                    dot,
                    Text('₹${r.costForOne} for one', style: meta),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
