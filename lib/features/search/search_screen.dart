import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../services/category_service.dart';
import '../../services/food_service.dart';
import '../../services/restaurant_service.dart';
import '../home/category_emoji.dart';
import '../restaurant/widgets/restaurant_cards.dart';

typedef _Results = ({List<Dish> dishes, List<Restaurant> restaurants});

/// Search tab (not in the Stitch export). Dishes come from DummyJSON
/// (search / tag / meal-type endpoints); restaurants from the backend.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.category});

  /// A DummyJSON tag chosen on Home.
  final String? category;

  static const debounce = Duration(milliseconds: 400);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  String _activeQuery = '';
  String? _tag;
  String? _mealType;

  @override
  void initState() {
    super.initState();
    _tag = widget.category;
    _query.addListener(_onTyped);
  }

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    if (widget.category != old.category && widget.category != null) {
      _query.text = '';
      setState(() {
        _tag = widget.category;
        _mealType = null;
        _activeQuery = '';
      });
    }
  }

  void _onTyped() {
    _debounce?.cancel();
    _debounce = Timer(SearchScreen.debounce, () {
      final q = _query.text.trim();
      if (q != _activeQuery && mounted) setState(() => _activeQuery = q);
    });
    setState(() {}); // clear-button visibility
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<_Results> _search() async {
    final food = context.read<FoodService>();
    final restaurants = context.read<RestaurantService>();
    final q = _activeQuery;
    if (q.isNotEmpty) {
      final results = await Future.wait([
        food.search(q),
        restaurants.getRestaurants(query: q),
      ]);
      return (
        dishes: results[0] as List<Dish>,
        restaurants: results[1] as List<Restaurant>,
      );
    }
    if (_tag != null) {
      final tag = _tag!.toLowerCase();
      final results = await Future.wait([food.byTag(_tag!), restaurants.all()]);
      return (
        dishes: results[0] as List<Dish>,
        restaurants: (results[1] as List<Restaurant>)
            .where((r) => r.menuTags.any((t) => t.toLowerCase() == tag))
            .toList(),
      );
    }
    if (_mealType != null) {
      return (dishes: await food.byMealType(_mealType!), restaurants: <Restaurant>[]);
    }
    final results = await Future.wait([food.getTopRated(limit: 10), restaurants.all()]);
    return (
      dishes: results[0] as List<Dish>,
      restaurants: results[1] as List<Restaurant>,
    );
  }

  void _clearAll() {
    _query.clear();
    setState(() {
      _activeQuery = '';
      _tag = null;
      _mealType = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final browsing = _activeQuery.isEmpty && _tag == null && _mealType == null;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => setState(() => _activeQuery = v.trim()),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                style: AppText.bodyMd,
                decoration: InputDecoration(
                  hintText: 'Search dishes, cuisines, restaurants...',
                  hintStyle: AppText.bodyMd.copyWith(color: AppColors.outline),
                  prefixIcon: const Icon(Icons.search, color: AppColors.outline),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: _query.clear,
                          icon: const Icon(Icons.close, size: 20),
                        ),
                  filled: true,
                  fillColor: AppColors.surfaceContainerHigh,
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.xl,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (_tag != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text('${emojiForCategory(_tag!)} $_tag'),
                        selected: true,
                        showCheckmark: false,
                        selectedColor: AppColors.primaryFixed,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        labelStyle: AppText.labelSm,
                        onDeleted: () => setState(() => _tag = null),
                        onPressed: () => setState(() => _tag = null),
                      ),
                    ),
                  for (final m in CategoryService.mealTypes)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(m),
                        selected: _mealType == m,
                        showCheckmark: false,
                        selectedColor: AppColors.primaryFixed,
                        backgroundColor: AppColors.surfaceContainerLow,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        labelStyle: AppText.labelSm,
                        onSelected: (selected) => setState(() {
                          _mealType = selected ? m : null;
                          if (selected) {
                            _tag = null;
                            _query.text = '';
                            _activeQuery = '';
                          }
                        }),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RequestBuilder<_Results>(
                requestKey: (_activeQuery, _tag, _mealType),
                request: _search,
                loading: const Padding(
                  padding: EdgeInsets.all(16),
                  child: ListSkeleton(count: 5, imageSize: 56),
                ),
                isEmpty: (r) => r.dishes.isEmpty && r.restaurants.isEmpty,
                empty: SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.search_off,
                    title: 'Nothing found',
                    message: _activeQuery.isNotEmpty
                        ? 'No dishes or restaurants match “$_activeQuery”.'
                        : 'Try a different dish, cuisine or restaurant.',
                    actionLabel: 'Clear search',
                    onAction: _clearAll,
                  ),
                ),
                builder: (context, results) => ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    if (results.dishes.isNotEmpty) ...[
                      SectionHeader(
                        title: browsing ? 'Top rated dishes' : 'Dishes',
                        subtitle: '${results.dishes.length} found',
                      ),
                      const SizedBox(height: 8),
                      for (final d in results.dishes) ...[
                        _DishResult(dish: d),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 16),
                    ],
                    if (results.restaurants.isNotEmpty) ...[
                      SectionHeader(
                        title: browsing ? 'All restaurants' : 'Restaurants',
                        subtitle: '${results.restaurants.length} found',
                      ),
                      const SizedBox(height: 8),
                      for (final r in results.restaurants) ...[
                        RestaurantListTile(restaurant: r),
                        const SizedBox(height: 8),
                      ],
                    ],
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

class _DishResult extends StatelessWidget {
  const _DishResult({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push(AppRoutes.dish(dish.id, restaurantId: dish.restaurantId)),
      child: Row(
        children: [
          AppImage(dish.image, width: 56, height: 56, borderRadius: AppRadius.lg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    VegMark(isVeg: dish.isVeg, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dish.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.labelMd,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${dish.tag} • ★ ${dish.rating}',
                  style: AppText.bodySm.copyWith(color: AppColors.outline),
                ),
              ],
            ),
          ),
          Text(rupees(dish.price), style: AppText.labelLg),
          const Icon(Icons.chevron_right, color: AppColors.outline),
        ],
      ),
    );
  }
}
