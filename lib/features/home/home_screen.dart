import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_routes.dart';
import '../../core/api/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/adaptive_dialogs.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../services/category_service.dart';
import '../../services/food_service.dart';
import '../../services/offer_service.dart';
import '../../services/restaurant_service.dart';
import '../../state/auth_controller.dart';
import '../../state/preferences_controller.dart';
import '../restaurant/widgets/restaurant_cards.dart';
import '../shell/app_header.dart';
import '../shell/sheets.dart';
import 'category_emoji.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _NearbyFilters {
  bool pureVeg = false;
  bool topRated = false;
  bool fastDelivery = false;

  int get count => [pureVeg, topRated, fastDelivery].where((f) => f).length;

  bool matches(Restaurant r) =>
      (!pureVeg || r.isPureVeg) &&
      (!topRated || r.rating >= 4.7) &&
      (!fastDelivery || r.maxMinutes <= 20);
}

class _HomeScreenState extends State<HomeScreen> {
  final _filters = _NearbyFilters();

  /// Bumped by pull-to-refresh; every section re-requests when it changes.
  int _refreshKey = 0;
  bool _surpriseLoading = false;

  Future<void> _refresh() async {
    setState(() => _refreshKey++);
    await context.read<PreferencesController>().load();
  }

  Future<void> _surprise() async {
    if (_surpriseLoading) return;
    setState(() => _surpriseLoading = true);
    try {
      final dish = await context.read<FoodService>().getRandomDish();
      if (!mounted) return;
      final go = await showConfirmDialog(
        context,
        title: '✨ Apna Food Recommends',
        message: '${dish.name}\n${rupees(dish.price)} • ★ ${dish.rating}',
        confirmLabel: 'View dish',
        cancelLabel: 'Maybe later',
      );
      if (go && mounted) context.push(AppRoutes.dish(dish.id));
    } catch (e) {
      if (mounted) showAppSnackBar(context, toApiException(e).message);
    } finally {
      if (mounted) setState(() => _surpriseLoading = false);
    }
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          Widget toggle(String label, bool value, ValueChanged<bool> set) =>
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(label, style: AppText.labelMd),
                value: value,
                onChanged: (v) {
                  setSheet(() => set(v));
                  setState(() {});
                },
              );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Filter nearby restaurants', style: AppText.titleMd),
                  const SizedBox(height: 8),
                  toggle('Pure Veg only', _filters.pureVeg,
                      (v) => _filters.pureVeg = v),
                  toggle('Rating 4.7+', _filters.topRated,
                      (v) => _filters.topRated = v),
                  toggle('Delivery in 20 mins or less', _filters.fastDelivery,
                      (v) => _filters.fastDelivery = v),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      minimumSize: const Size.fromHeight(48),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.xl,
                      ),
                    ),
                    child: const Text('Show results'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final address = context.watch<PreferencesController>().address;
    final food = context.read<FoodService>();
    final restaurants = context.read<RestaurantService>();

    return Scaffold(
      appBar: const DeliveryHeader(),
      body: RefreshIndicator(
        color: AppColors.primaryContainer,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          children: [
            // Greeting
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${user?.firstName ?? 'there'} 👋',
                          style: AppText.headlineMd,
                        ),
                        const SizedBox(height: 2),
                        InkWell(
                          borderRadius: AppRadius.lg,
                          onTap: () => showAddressSheet(context),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text.rich(
                                  address == null
                                      ? const TextSpan(text: 'Choose a delivery address')
                                      : TextSpan(
                                          text: 'Deliver to: ',
                                          children: [
                                            TextSpan(
                                              text: address.label,
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            TextSpan(text: ' - ${address.short}'),
                                          ],
                                        ),
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.labelSm,
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color: AppColors.outline,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.casino_outlined,
                    tooltip: 'Surprise me',
                    background: AppColors.surfaceContainer,
                    foreground: AppColors.primary,
                    shadow: true,
                    onPressed: _surpriseLoading ? null : _surprise,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Search entry point
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: AppColors.surfaceContainerHigh,
                borderRadius: AppRadius.xl,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.go(AppRoutes.search),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 20, color: AppColors.outline),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Search restaurants, cuisines, dishes...',
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyMd.copyWith(color: AppColors.outline),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Voice search',
                          onPressed: () => showAppSnackBar(
                            context,
                            'Voice search is not available in this demo yet.',
                          ),
                          icon: const Icon(
                            Icons.mic_none,
                            size: 20,
                            color: AppColors.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Offer banner: GET /offers (featured)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RequestBuilder<Offer?>(
                requestKey: _refreshKey,
                request: context.read<OfferService>().getFeaturedOffer,
                loading: const SkeletonBox(height: 144, radius: AppRadius.xl),
                compactError: true,
                isEmpty: (offer) => offer == null,
                builder: (context, offer) => _PromoBanner(offer: offer!),
              ),
            ),
            const SizedBox(height: 16),
            // Categories: GET /recipes/tags
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(
                title: 'Explore Categories',
                trailing: TextButton(
                  onPressed: () => context.go(AppRoutes.search),
                  child: Text(
                    'See All',
                    style: AppText.labelSm.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            RequestBuilder<List<FoodCategory>>(
              requestKey: _refreshKey,
              request: context.read<CategoryService>().getCategories,
              loading: SizedBox(
                height: 88,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  children: [
                    for (var i = 0; i < 5; i++)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SkeletonBox(width: 76, height: 80, radius: AppRadius.xl),
                      ),
                  ],
                ),
              ),
              compactError: true,
              isEmpty: (tags) => tags.isEmpty,
              builder: (context, tags) {
                final shown = tags.take(12).toList();
                return SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _CategoryChip(
                      emoji: shown[i].emoji ?? emojiForCategory(shown[i].name),
                      imageUrl: shown[i].imageUrl,
                      label: shown[i].name,
                      highlighted: i == 0,
                      onTap: () => context.go(AppRoutes.searchCategory(shown[i].name)),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Featured dishes: GET /recipes?sortBy=rating
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(
                title: 'Top Rated Dishes',
                subtitle: 'Highest rated by foodies',
              ),
            ),
            const SizedBox(height: 4),
            RequestBuilder<List<Dish>>(
              requestKey: _refreshKey,
              request: () => food.getTopRated(limit: 8),
              loading: SizedBox(
                height: 196,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  children: [
                    for (var i = 0; i < 3; i++)
                      const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SkeletonBox(width: 150, height: 188, radius: AppRadius.xl),
                      ),
                  ],
                ),
              ),
              compactError: true,
              isEmpty: (d) => d.isEmpty,
              builder: (context, dishes) => SizedBox(
                height: 196,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: dishes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _DishCard(dish: dishes[i]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Popular restaurants: GET /restaurants?popular=true
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(
                title: 'Popular Restaurants',
                subtitle: 'Top picks by foodies around you',
                trailing: CircleIconButton(
                  icon: Icons.arrow_forward,
                  tooltip: 'See all restaurants',
                  size: 32,
                  iconSize: 18,
                  background: AppColors.surfaceContainer,
                  foreground: AppColors.onSurfaceVariant,
                  onPressed: () => context.go(AppRoutes.search),
                ),
              ),
            ),
            const SizedBox(height: 4),
            RequestBuilder<List<Restaurant>>(
              requestKey: _refreshKey,
              request: () => restaurants.getRestaurants(popularOnly: true),
              loading: SizedBox(
                height: 246,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  children: const [
                    SkeletonBox(width: 260, height: 236, radius: AppRadius.xl),
                    SizedBox(width: 16),
                    SkeletonBox(width: 260, height: 236, radius: AppRadius.xl),
                  ],
                ),
              ),
              compactError: true,
              isEmpty: (r) => r.isEmpty,
              builder: (context, popular) => SizedBox(
                height: 246,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: popular.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (context, i) => RestaurantCard(restaurant: popular[i]),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Nearby: GET /restaurants?sort=distance (+ local filters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(
                title: 'Nearby Restaurants',
                subtitle: 'Fastest delivery to your doorstep',
                trailing: Material(
                  color: _filters.count > 0
                      ? AppColors.primaryFixed
                      : AppColors.surfaceContainer,
                  borderRadius: AppRadius.lg,
                  child: InkWell(
                    borderRadius: AppRadius.lg,
                    onTap: _openFilters,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.tune, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            _filters.count > 0
                                ? 'Filters (${_filters.count})'
                                : 'Filters',
                            style: AppText.labelSm.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: RequestBuilder<List<Restaurant>>(
                requestKey: _refreshKey,
                request: () => restaurants.getRestaurants(sortByDistance: true),
                loading: const ListSkeleton(count: 3, imageSize: 96),
                compactError: true,
                builder: (context, nearby) {
                  final filtered = nearby.where(_filters.matches).toList();
                  if (filtered.isEmpty) {
                    return EmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No matches',
                      message: 'No nearby restaurants match these filters.',
                      actionLabel: 'Clear filters',
                      onAction: () => setState(() {
                        _filters
                          ..pureVeg = false
                          ..topRated = false
                          ..fastDelivery = false;
                      }),
                    );
                  }
                  return Column(
                    children: [
                      for (final r in filtered) ...[
                        RestaurantListTile(restaurant: r),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: AppRadius.xl,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.restaurant, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Not sure what to eat?', style: AppText.labelMd),
                          Text(
                            'Spin the Apna Wheel of Taste',
                            style: AppText.bodySm.copyWith(color: AppColors.outline),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: _surpriseLoading ? null : _surprise,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.lg,
                        ),
                      ),
                      child: _surpriseLoading
                          ? const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Surprise Me',
                              style: AppText.labelSm.copyWith(color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () => context.push(AppRoutes.dish(dish.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AppImage(dish.image, width: 150, height: 110),
                Positioned(
                  top: 6,
                  left: 6,
                  child: VegMark(isVeg: dish.isVeg, size: 14),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.labelMd.copyWith(height: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(rupees(dish.price), style: AppText.labelMd),
                      const Spacer(),
                      RatingPill(dish.rating),
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
}

class _PromoBanner extends StatefulWidget {
  const _PromoBanner({required this.offer});

  final Offer offer;

  @override
  State<_PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<_PromoBanner> {
  bool _copied = false;
  Timer? _timer;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.offer.code));
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: AppRadius.xl,
        boxShadow: AppShadows.md,
        gradient: LinearGradient(
          colors: [AppColors.primaryContainer, AppColors.secondary],
        ),
      ),
      child: Stack(
        children: [
          Positioned(right: -24, bottom: -40, child: _circle(144, 0.1)),
          Positioned(left: 110, top: -24, child: _circle(80, 0.1)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Pill(
                        label: 'Special Deal',
                        icon: Icons.local_fire_department,
                        uppercase: true,
                        background: Colors.white.withValues(alpha: 0.2),
                        foreground: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        offer.title,
                        style: AppText.headlineLg.copyWith(color: Colors.white),
                      ),
                      Text(
                        offer.subtitle,
                        style: AppText.labelSm.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Material(
                            color: Colors.white,
                            borderRadius: AppRadius.lg,
                            child: InkWell(
                              borderRadius: AppRadius.lg,
                              onTap: _copy,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      offer.code,
                                      style: AppText.labelMd.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      _copied ? Icons.check : Icons.content_copy,
                                      size: 14,
                                      color: AppColors.primary,
                                      semanticLabel: 'Copy code',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _copied ? 1 : 0,
                            child: Text(
                              'Copied!',
                              style: AppText.labelSm.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (offer.imageUrl != null)
                  Transform.rotate(
                    angle: 0.05,
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: const BoxDecoration(
                        borderRadius: AppRadius.xl,
                        boxShadow: AppShadows.lg,
                      ),
                      child: AppImage(offer.imageUrl, borderRadius: AppRadius.xl),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, double alpha) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: alpha),
            shape: BoxShape.circle,
          ),
        ),
      );
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.emoji,
    required this.label,
    required this.onTap,
    this.imageUrl,
    this.highlighted = false,
  });

  final String emoji;

  /// Photo set in the admin dashboard; shown instead of the emoji.
  final String? imageUrl;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primaryFixed : Colors.white,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.xl,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (imageUrl != null)
                  AppImage(
                    imageUrl,
                    width: 32,
                    height: 32,
                    borderRadius: AppRadius.full,
                  )
                else
                  Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppText.labelSm.copyWith(
                    color: highlighted
                        ? AppColors.onPrimaryFixed
                        : AppColors.onSurface,
                    fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
