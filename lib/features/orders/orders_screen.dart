import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/adaptive_dialogs.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/cart_controller.dart';
import '../../state/orders_controller.dart';

/// Orders tab (not in the Stitch export). Order history from GET /orders.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  Future<void> _reorder(BuildContext context, Order order) async {
    final cart = context.read<CartController>();
    final current = cart.cart.restaurant;
    var replace = false;
    if (!cart.isEmpty && current?.id != order.restaurant.id) {
      replace = await showConfirmDialog(
        context,
        title: 'Replace cart items?',
        message:
            'Your cart has items from ${current?.name}. Replace them '
            'with this order from ${order.restaurant.name}?',
        confirmLabel: 'Replace',
        destructive: true,
      );
      if (!replace || !context.mounted) return;
    }
    final ok = await runWithFeedback(
      context,
      () => cart.reorder(order.items, replace: replace),
    );
    if (ok && context.mounted) context.go(AppRoutes.cart);
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrdersController>();
    final active = orders.active;
    final past = orders.past;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Your Orders', style: AppText.headlineMd),
        centerTitle: false,
      ),
      body: orders.isLoading && !orders.hasLoaded
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: ListSkeleton(count: 3, imageSize: 48),
            )
          : orders.error != null && orders.orders.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: ErrorView(error: orders.error!, onRetry: orders.load),
              ),
            )
          : orders.orders.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No orders yet',
                  message: 'Your orders will show up here once you place one.',
                  actionLabel: 'Start ordering',
                  onAction: () => context.go(AppRoutes.home),
                ),
              ),
            )
          : RefreshIndicator(
              color: AppColors.primaryContainer,
              onRefresh: orders.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (active.isNotEmpty) ...[
                    const SectionHeader(
                      title: 'Active',
                      subtitle: 'Live tracking',
                    ),
                    const SizedBox(height: 8),
                    for (final o in active) ...[
                      _OrderCard(order: o),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 16),
                  ],
                  if (past.isNotEmpty) ...[
                    const SectionHeader(title: 'Past orders'),
                    const SizedBox(height: 8),
                    for (final o in past) ...[
                      _OrderCard(
                        order: o,
                        onReorder: () => _reorder(context, o),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.onReorder});

  final Order order;
  final VoidCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (order.status) {
      OrderStatus.placed => 'Order placed',
      OrderStatus.preparing => 'Preparing',
      OrderStatus.outForDelivery => 'Out for delivery',
      OrderStatus.delivered => 'Delivered',
    };
    return AppCard(
      onTap: () => context.push(AppRoutes.orderTracking(order.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppImage(
                order.restaurant.image,
                width: 48,
                height: 48,
                borderRadius: AppRadius.lg,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.restaurant.name, style: AppText.labelLg),
                    Text(
                      '#${order.id} • ${formatDate(order.placedAt)}',
                      style: AppText.bodySm.copyWith(color: AppColors.outline),
                    ),
                  ],
                ),
              ),
              Pill(
                label: statusLabel,
                background: order.isActive
                    ? AppColors.primaryFixed
                    : AppColors.tertiaryFixed.withValues(alpha: 0.5),
                foreground: order.isActive
                    ? AppColors.onPrimaryFixedVariant
                    : AppColors.tertiary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            order.items.map((i) => '${i.quantity} × ${i.name}').join(', '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const Divider(height: 20, color: AppColors.surfaceContainer),
          Row(
            children: [
              Expanded(
                child: Text(
                  rupees(order.amount, decimals: true),
                  style: AppText.labelLg,
                ),
              ),
              if (order.isActive)
                Text(
                  'TRACK ›',
                  style: AppText.labelSm.copyWith(color: AppColors.primary),
                )
              else if (onReorder != null)
                TextButton.icon(
                  onPressed: onReorder,
                  icon: const Icon(Icons.replay, size: 16),
                  label: const Text('Reorder'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryContainer,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
