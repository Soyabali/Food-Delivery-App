import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/adaptive_dialogs.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../services/offer_service.dart';
import '../../state/cart_controller.dart';
import '../../state/preferences_controller.dart';
import '../shell/app_header.dart';
import '../shell/sheets.dart';
import 'payment_sheet.dart';

/// Cart tab (cardScreen.html). Shows the server-side cart; all totals come
/// from the backend response.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _clear(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Clear cart?',
      message: 'All items will be removed from your cart.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (ok && context.mounted) {
      await runWithFeedback(context, context.read<CartController>().clear);
    }
  }

  Future<void> _editInstructions(BuildContext context) async {
    final controller = context.read<CartController>();
    final text = TextEditingController(text: controller.cart.instructions);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cooking & delivery instructions'),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: 150,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'E.g. Please do not ring bell; leave at doorstep',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(text.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    text.dispose();
    if (result != null && context.mounted) {
      await runWithFeedback(context, () => controller.setInstructions(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CartController>();
    final cart = controller.cart;
    final address = context.watch<PreferencesController>().address;
    final restaurant = cart.restaurant;

    Widget content;
    if (controller.isLoading && cart.isEmpty) {
      content = const ListSkeleton(count: 3);
    } else if (controller.error != null && cart.isEmpty) {
      content = ErrorView(error: controller.error!, onRetry: controller.load);
    } else if (cart.isEmpty) {
      content = AppCard(
        child: EmptyState(
          icon: Icons.production_quantity_limits,
          title: 'Your cart is empty',
          message: 'Add something delicious from a restaurant near you!',
          actionLabel: 'Explore Menu',
          onAction: () => context.go(AppRoutes.home),
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DeliveryTeaser(cart: cart),
          const SizedBox(height: 16),
          for (final item in cart.items) ...[
            _CartLineCard(item: item, enabled: !controller.isBusy),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          AppCard(
            onTap: () => _editInstructions(context),
            child: Row(
              children: [
                const Icon(Icons.notes, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cooking & Delivery Instructions',
                        style: AppText.labelMd,
                      ),
                      Text(
                        cart.instructions.isEmpty
                            ? 'Add a note for the restaurant or rider'
                            : cart.instructions,
                        style: AppText.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  cart.instructions.isEmpty ? 'ADD' : 'EDIT',
                  style: AppText.labelSm.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _CouponCard(cart: cart, enabled: !controller.isBusy),
          const SizedBox(height: 16),
          _AddressCard(address: address),
          const SizedBox(height: 16),
          _BillDetails(cart: cart),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.xl,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, size: 18, color: AppColors.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Review your order carefully before payment. '
                    '${restaurant?.name ?? 'The restaurant'} prepares food '
                    'fresh upon checkout confirmation.',
                    style: AppText.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: const DeliveryHeader(),
      body: RefreshIndicator(
        color: AppColors.primaryContainer,
        onRefresh: controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                CircleIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back to Home',
                  onPressed: () => context.go(AppRoutes.home),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Cart', style: AppText.headlineMd),
                      if (restaurant != null)
                        InkWell(
                          onTap: () =>
                              context.push(AppRoutes.restaurant(restaurant.id)),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.storefront,
                                size: 14,
                                color: AppColors.primaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  restaurant.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.labelMd,
                                ),
                              ),
                              Text(
                                '  •  ${restaurant.distanceKm} km',
                                style: AppText.bodySm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (controller.isBusy)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                if (!cart.isEmpty)
                  Material(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: AppRadius.full,
                    child: InkWell(
                      borderRadius: AppRadius.full,
                      onTap: controller.isBusy ? null : () => _clear(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_sweep_outlined,
                              size: 15,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Clear',
                              style: AppText.labelSm.copyWith(
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : _CheckoutBar(cart: cart, address: address, busy: controller.isBusy),
    );
  }
}

class _DeliveryTeaser extends StatelessWidget {
  const _DeliveryTeaser({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final missing = cart.freeDeliveryThreshold - cart.itemTotal;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.xl,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.tertiary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt, size: 20, color: AppColors.tertiary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Standard Delivery', style: AppText.labelMd),
                Text(
                  cart.freeDelivery
                      ? 'Free delivery unlocked on this order'
                      : 'Add ${rupees(missing)} more for free delivery',
                  style: AppText.bodySm.copyWith(
                    color: AppColors.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_outlined, size: 18, color: AppColors.outline),
        ],
      ),
    );
  }
}

class _CartLineCard extends StatelessWidget {
  const _CartLineCard({required this.item, required this.enabled});

  final CartLine item;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CartController>();
    final detail = item.customisation ?? item.note;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppImage(item.image, borderRadius: AppRadius.lg),
                Positioned(top: 6, left: 6, child: VegMark(isVeg: item.isVeg)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.labelLg,
                          ),
                          if (detail != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.tune,
                                    size: 13,
                                    color: AppColors.primaryContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      detail,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.bodySm.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove ${item.name}',
                      visualDensity: VisualDensity.compact,
                      onPressed: !enabled
                          ? null
                          : () async {
                              final ok = await runWithFeedback(
                                context,
                                () => controller.remove(item),
                              );
                              if (ok && context.mounted) {
                                showAppSnackBar(
                                  context,
                                  '${item.name} removed',
                                  actionLabel: 'UNDO',
                                  onAction: () => controller
                                      .restore(item)
                                      .catchError((_) {}),
                                );
                              }
                            },
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(rupees(item.lineTotal), style: AppText.labelLg),
                    ),
                    AbsorbPointer(
                      absorbing: !enabled,
                      child: QuantityStepper(
                        quantity: item.quantity,
                        onChanged: (q) => runWithFeedback(
                          context,
                          () => controller.setQuantity(item, q),
                        ),
                      ),
                    ),
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

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.cart, required this.enabled});

  final Cart cart;
  final bool enabled;

  Future<void> _pickCoupon(BuildContext context) async {
    final controller = context.read<CartController>();
    final offers = context.read<OfferService>();
    final code = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Apply a coupon', style: AppText.titleMd),
              const SizedBox(height: 12),
              RequestBuilder<List<Offer>>(
                request: offers.getOffers,
                loading: const ListSkeleton(count: 2, imageSize: 40),
                compactError: true,
                isEmpty: (o) => o.isEmpty,
                empty: const EmptyState(
                  icon: Icons.local_offer_outlined,
                  title: 'No offers right now',
                  message: 'Check back later for new deals.',
                ),
                builder: (context, list) => Column(
                  children: [
                    for (final o in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: AppRadius.xl,
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: const Icon(
                              Icons.local_offer_outlined,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              '${o.code} • ${o.title}',
                              style: AppText.labelMd,
                            ),
                            subtitle: Text(o.subtitle, style: AppText.bodySm),
                            trailing: Text(
                              'APPLY',
                              style: AppText.labelSm.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            onTap: () => Navigator.of(sheetContext).pop(o.code),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (code != null && context.mounted) {
      await runWithFeedback(context, () => controller.applyCoupon(code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CartController>();
    final code = cart.couponCode;
    final active = code != null && cart.discount > 0;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: code == null && enabled ? () => _pickCoupon(context) : null,
      gradient: LinearGradient(
        colors: [AppColors.primaryFixed.withValues(alpha: 0.3), Colors.white],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.tertiaryContainer
                  : AppColors.surfaceContainerHigh,
              borderRadius: AppRadius.lg,
            ),
            child: Icon(
              active ? Icons.check_circle_outline : Icons.local_offer_outlined,
              size: 20,
              color: active ? Colors.white : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        code ?? 'Apply coupon',
                        style: AppText.labelMd.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: code == null ? 0 : 0.5,
                        ),
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 6),
                      Pill(
                        label: 'APPLIED',
                        background: AppColors.tertiary.withValues(alpha: 0.15),
                        foreground: AppColors.tertiary,
                        fontSize: 10,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      ),
                    ],
                  ],
                ),
                Text(
                  code == null
                      ? 'View available offers'
                      : active
                          ? '${rupees(cart.discount)} coupon applied!'
                          : cart.couponMessage ?? 'Not applicable to this cart',
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(
                    color: active ? AppColors.tertiary : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (code != null)
            TextButton(
              onPressed: enabled
                  ? () => runWithFeedback(context, controller.removeCoupon)
                  : null,
              child: Text(
                'Remove',
                style: AppText.labelSm.copyWith(color: AppColors.secondary),
              ),
            )
          else
            const Icon(Icons.chevron_right, color: AppColors.outline),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});

  final DeliveryAddress? address;

  @override
  Widget build(BuildContext context) {
    final a = address;
    return AppCard(
      onTap: a == null ? () => showAddressSheet(context) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primaryFixed,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: a == null
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Choose a delivery address',
                      style: AppText.labelLg.copyWith(color: AppColors.primary),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Deliver to: ${a.label}',
                              style: AppText.labelLg,
                            ),
                          ),
                          if (a.isDefault) ...[
                            const SizedBox(width: 8),
                            const Pill(
                              label: 'DEFAULT',
                              fontSize: 10,
                              foreground: AppColors.onSurfaceVariant,
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
          ),
          TextButton(
            onPressed: () => showAddressSheet(context),
            child: Text(
              a == null ? 'Choose' : 'Change',
              style: AppText.labelMd.copyWith(color: AppColors.primaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillDetails extends StatelessWidget {
  const _BillDetails({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) {
    final muted = AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant);
    Widget row(String label, Widget value, {String? info, Color? color}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: color == null ? muted : muted.copyWith(color: color),
                    ),
                  ),
                  if (info != null)
                    Tooltip(
                      message: info,
                      triggerMode: TooltipTriggerMode.tap,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.info_outline, size: 14, color: AppColors.outline),
                      ),
                    ),
                ],
              ),
            ),
            value,
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(child: Text('Bill Details', style: AppText.titleMd)),
              Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.outline),
            ],
          ),
          const SizedBox(height: 12),
          row(
            'Item Total',
            Text(rupees(cart.itemTotal, decimals: true), style: AppText.labelMd),
          ),
          row(
            'Delivery Fee',
            cart.freeDelivery
                ? Row(
                    children: [
                      Text(
                        rupees(cart.standardDeliveryFee, decimals: true),
                        style: AppText.bodySm.copyWith(
                          color: AppColors.outline,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'FREE',
                        style: AppText.labelMd.copyWith(
                          color: AppColors.tertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                : Text(rupees(cart.deliveryFee, decimals: true), style: AppText.labelMd),
            info: 'Free on orders above ${rupees(cart.freeDeliveryThreshold)}',
          ),
          row(
            'Taxes and Restaurant Charges',
            Text(rupees(cart.taxes, decimals: true), style: AppText.labelMd),
            info: '${cart.taxRatePercent.toStringAsFixed(0)}% GST on item total',
          ),
          if (cart.discount > 0)
            row(
              'Coupon Discount (${cart.couponCode})',
              Text(
                rupees(-cart.discount, decimals: true),
                style: AppText.labelMd.copyWith(
                  color: AppColors.tertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              color: AppColors.tertiary,
            ),
          const Divider(color: AppColors.surfaceVariant, height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Payable',
                      style: AppText.titleMd.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Inclusive of all taxes',
                      style: AppText.bodySm.copyWith(color: AppColors.outline),
                    ),
                  ],
                ),
              ),
              Text(
                rupees(cart.total, decimals: true),
                style: AppText.headlineMd.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (cart.savings > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.tertiaryFixed.withValues(alpha: 0.4),
                borderRadius: AppRadius.lg,
              ),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You saved ${rupees(cart.savings)} on this order!',
                      style: AppText.labelMd.copyWith(
                        color: AppColors.tertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.savings_outlined, size: 16, color: AppColors.tertiary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.cart,
    required this.address,
    required this.busy,
  });

  final Cart cart;
  final DeliveryAddress? address;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final a = address;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x0F000000), blurRadius: 24, offset: Offset(0, -8)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => showAddressSheet(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      a == null
                          ? const TextSpan(text: 'No delivery address selected')
                          : TextSpan(
                              text: 'Delivering to ',
                              children: [
                                TextSpan(
                                  text: a.label,
                                  style: const TextStyle(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(text: ' (${a.short}...)'),
                              ],
                            ),
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    a == null ? 'CHOOSE' : 'CHANGE',
                    style: AppText.labelSm.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Material(
            color: AppColors.primaryContainer.withValues(alpha: busy ? 0.6 : 1),
            borderRadius: AppRadius.xl,
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: busy ? null : () => showPaymentSheet(context),
              child: SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TO PAY',
                            style: AppText.labelSm.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            rupees(cart.total, decimals: true),
                            style: AppText.titleMd.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        'Proceed to Payment',
                        style: AppText.labelLg.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
