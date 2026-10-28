import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/navigation/navigation_helpers.dart';
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
import '../../services/cart_service.dart';
import '../../services/food_service.dart';
import '../../services/user_service.dart';
import '../../state/cart_controller.dart';
import '../../state/preferences_controller.dart';

/// Built from the "Food Item Details" screenshot. The dish comes from
/// GET /recipes/{id} (DummyJSON) via [FoodService].
class FoodDetailsScreen extends StatelessWidget {
  const FoodDetailsScreen({super.key, required this.dishId, this.restaurantId});

  final String dishId;

  /// Restaurant the user came from (menus can share a recipe).
  final String? restaurantId;

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse(dishId);
    Widget errorPage(ApiException error, VoidCallback? retry) => Scaffold(
          appBar: AppBar(backgroundColor: Colors.white),
          body: Center(
            child: SingleChildScrollView(
              child: ErrorView(error: error, onRetry: retry),
            ),
          ),
        );
    if (id == null) {
      return errorPage(
        const ApiException(ApiErrorType.notFound, 'This dish is no longer on the menu.'),
        null,
      );
    }
    return RequestBuilder<Dish>(
      requestKey: (id, restaurantId),
      request: () =>
          context.read<FoodService>().getDish(id, restaurantId: restaurantId),
      loading: const Scaffold(body: Center(child: CircularProgressIndicator())),
      errorBuilder: errorPage,
      builder: (context, dish) => _FoodDetailsView(dish: dish),
    );
  }
}

class _FoodDetailsView extends StatefulWidget {
  const _FoodDetailsView({required this.dish});

  final Dish dish;

  @override
  State<_FoodDetailsView> createState() => _FoodDetailsViewState();
}

class _FoodDetailsViewState extends State<_FoodDetailsView> {
  Dish get _dish => widget.dish;
  DishOption? _portion;
  String? _spice;
  final Set<String> _addOns = {};
  int _quantity = 1;
  String _note = '';
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    final dish = _dish;
    _portion = dish.portions.isEmpty ? null : dish.portions.first;
    if (dish.spiceLevels.isNotEmpty) {
      _spice = dish.spiceLevels.contains('Medium')
          ? 'Medium'
          : dish.spiceLevels.first;
    }
  }

  AddToCartRequest _request({bool replaceCart = false}) => AddToCartRequest(
        dish: _dish,
        quantity: _quantity,
        portion: _portion,
        spiceLevel: _spice,
        addOns: _dish.addOns.where((a) => _addOns.contains(a.id)).toList(),
        note: _note.isEmpty ? null : _note,
        replaceCart: replaceCart,
      );

  int get _unitPrice => _request().unitPrice;

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _note);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cooking instructions'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'E.g. Less oil, no onions...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && mounted) setState(() => _note = result);
  }

  /// POST /cart/items. A 409 (cart from another restaurant) asks the user
  /// before retrying with `replaceCart: true`.
  Future<void> _addToCart() async {
    if (_adding) return;
    final cart = context.read<CartController>();
    setState(() => _adding = true);
    try {
      var outcome = await cart.add(_request());
      if (outcome is CartConflict) {
        if (!mounted) return;
        final current = cart.cart.restaurant?.name ?? 'another restaurant';
        final replace = await showConfirmDialog(
          context,
          title: 'Replace cart items?',
          message: 'Your cart has items from $current. Start a new cart '
              'with ${_dish.restaurantName}?',
          confirmLabel: 'Replace',
          destructive: true,
        );
        if (!replace || !mounted) return;
        outcome = await cart.add(_request(replaceCart: true));
      }
      if (!mounted || outcome is! AddedToCart) return;
      HapticFeedback.lightImpact();
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      context.popOrGo(AppRoutes.home);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Added $_quantity × ${_dish.name} to cart'),
            action: SnackBarAction(
              label: 'VIEW CART',
              onPressed: () => router.go(AppRoutes.cart),
            ),
          ),
        );
    } catch (e) {
      if (mounted) showAppSnackBar(context, toApiException(e).message);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _toggleFavourite() async {
    await runWithFeedback(
      context,
      () => context
          .read<PreferencesController>()
          .toggleFavourite(FavoriteType.dish, '${_dish.id}'),
    );
  }

  Future<void> _share(Dish dish) async {
    await Clipboard.setData(
      ClipboardData(text: 'https://apnafood.example/dish/${dish.id}'),
    );
    if (mounted) showAppSnackBar(context, 'Dish link copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    final dish = _dish;
    final fav = context.select<PreferencesController, bool>(
      (p) => p.isFavourite(FavoriteType.dish, '${dish.id}'),
    );
    final total = _unitPrice * _quantity;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 280,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Text(dish.restaurantName, style: AppText.titleMd),
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
              CircleIconButton(
                icon: fav ? Icons.favorite : Icons.favorite_border,
                tooltip: fav ? 'Remove from favourites' : 'Add to favourites',
                background: Colors.white,
                foreground: AppColors.secondary,
                shadow: true,
                onPressed: _toggleFavourite,
              ),
              const SizedBox(width: 8),
              CircleIconButton(
                icon: Icons.share_outlined,
                tooltip: 'Share',
                background: Colors.white,
                shadow: true,
                onPressed: () => _share(dish),
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(dish.image),
                  if (dish.badge != null)
                    Positioned(
                      left: 16,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                        ),
                        child: Row(
                          children: [
                            VegMark(isVeg: dish.isVeg, size: 12),
                            const SizedBox(width: 6),
                            Text(
                              dish.badge!.toUpperCase(),
                              style: AppText.labelSm.copyWith(letterSpacing: 0.8),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverList.list(
              children: [
                _Section(child: _Summary(dish: dish)),
                if (dish.ingredients.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Ingredients',
                    subtitle: [
                      'From the recipe',
                      ?dish.difficulty,
                      if (dish.servings != null) 'serves ${dish.servings}',
                    ].join(' • '),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final i in dish.ingredients)
                          Pill(
                            label: i,
                            background: AppColors.surfaceContainerLow,
                            foreground: AppColors.onSurface,
                          ),
                      ],
                    ),
                  ),
                ],
                if (dish.portions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Choose Portion Size',
                    subtitle: 'Select one option',
                    trailing: const Pill(
                      label: 'Required',
                      uppercase: true,
                      background: AppColors.primaryFixed,
                      foreground: AppColors.onPrimaryFixedVariant,
                    ),
                    child: Column(
                      children: [
                        for (final p in dish.portions)
                          _OptionTile(
                            title: p.name,
                            subtitle: p.subtitle,
                            priceLabel: p.price == 0
                                ? 'Included'
                                : '+${rupees(p.price)}',
                            selected: _portion?.id == p.id,
                            radio: true,
                            onTap: () => setState(() => _portion = p),
                          ),
                      ],
                    ),
                  ),
                ],
                if (dish.spiceLevels.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Select Spice Level',
                    subtitle: 'Customized fresh to your taste',
                    child: Row(
                      children: [
                        for (final s in dish.spiceLevels)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: s == dish.spiceLevels.last ? 0 : 8,
                              ),
                              child: _SpiceChip(
                                label: s,
                                selected: _spice == s,
                                onTap: () => setState(() => _spice = s),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (dish.addOns.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Section(
                    title: 'Add-ons & Extras',
                    subtitle: 'Extras from ${dish.restaurantName}',
                    child: Column(
                      children: [
                        for (final a in dish.addOns)
                          _OptionTile(
                            title: a.name,
                            subtitle: a.subtitle,
                            priceLabel: '+${rupees(a.price)}',
                            selected: _addOns.contains(a.id),
                            onTap: () => setState(() {
                              if (!_addOns.remove(a.id)) _addOns.add(a.id);
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppCard(
                  onTap: _editNote,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryFixed,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_note,
                          size: 20,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _note.isEmpty
                                  ? 'Add Cooking Instructions?'
                                  : 'Cooking Instructions',
                              style: AppText.labelMd,
                            ),
                            Text(
                              _note.isEmpty
                                  ? 'E.g. Less oil, no onions...'
                                  : _note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodySm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.outline),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 24,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    QuantityStepper(
                      quantity: _quantity,
                      min: 1,
                      compact: false,
                      onChanged: (q) => setState(() => _quantity = q),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total Price',
                          style: AppText.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        Text(rupees(total), style: AppText.headlineMd),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Add to Cart • ${rupees(total)}',
                  leadingIcon: Icons.shopping_bag_outlined,
                  loading: _adding,
                  loadingLabel: 'Adding…',
                  onPressed: _addToCart,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!, style: AppText.titleMd),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppText.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dish.tag != null)
                    Row(
                      children: [
                        VegMark(isVeg: dish.isVeg, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          dish.tag!.toUpperCase(),
                          style: AppText.labelSm.copyWith(
                            color: AppColors.secondary,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    dish.name,
                    style: AppText.headlineMd.copyWith(fontSize: 22),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rupees(dish.price),
                  style: AppText.headlineMd.copyWith(
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'demo price',
                  style: AppText.bodySm.copyWith(color: AppColors.outline),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Pill(
              label: '${dish.rating} (${dish.ratingCount}+)',
              icon: Icons.star_outline,
              background: AppColors.tertiaryFixed.withValues(alpha: 0.4),
              foreground: AppColors.tertiary,
            ),
            Pill(
              label: dish.prepTime,
              icon: Icons.schedule,
              background: AppColors.surfaceContainer,
              foreground: AppColors.onSurface,
            ),
            if (dish.kcal != null)
              Pill(
                label: '${dish.kcal} kcal',
                icon: Icons.local_fire_department_outlined,
                background: AppColors.surfaceContainer,
                foreground: AppColors.onSurface,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          dish.description,
          style: AppText.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.priceLabel,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.radio = false,
  });

  final String title;
  final String? subtitle;
  final String priceLabel;
  final bool selected;
  final bool radio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final indicator = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: radio ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radio ? null : AppRadius.sm,
        color: !radio && selected ? AppColors.primaryContainer : Colors.white,
        border: Border.all(
          color: selected ? AppColors.primaryContainer : AppColors.outline,
          width: radio && selected ? 6 : 1.5,
        ),
      ),
      child: !radio && selected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        checked: radio ? null : selected,
        inMutuallyExclusiveGroup: radio,
        selected: radio ? selected : null,
        child: Material(
          color: selected
              ? AppColors.surfaceContainer
              : AppColors.surfaceContainerLow,
          borderRadius: AppRadius.xl,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  indicator,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.labelMd),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: AppText.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    priceLabel,
                    style: AppText.labelMd.copyWith(
                      color: priceLabel.startsWith('+') && radio
                          ? AppColors.secondary
                          : AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpiceChip extends StatelessWidget {
  const _SpiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryContainer
              : AppColors.surfaceContainerLow,
          borderRadius: AppRadius.full,
          boxShadow: selected ? AppShadows.md : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadius.full,
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (label == 'Extra Hot') ...[
                  Icon(Icons.local_fire_department_outlined, size: 14, color: fg),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.labelMd.copyWith(color: fg),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.check, size: 16, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
