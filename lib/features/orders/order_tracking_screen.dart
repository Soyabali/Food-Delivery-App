import 'dart:async';

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
import '../../core/widgets/async_view.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/orders_controller.dart';
import '../shell/app_header.dart';
import 'widgets/order_status_timeline.dart';

/// Order confirmation (from orderconfirmation.html) when [justPlaced], and
/// the same layout without the celebration header for later tracking.
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.justPlaced = false,
  });

  final String orderId;
  final bool justPlaced;

  /// How often an active order is re-fetched (GET /orders/{id}).
  static const pollInterval = Duration(seconds: 5);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Order? _order;
  ApiException? _error;
  bool _refreshFailed = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final order = await context.read<OrdersController>().refresh(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _error = null;
        _refreshFailed = false;
      });
      _schedule();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Keep showing the last known state if a background refresh fails.
        if (_order == null) _error = toApiException(e);
        _refreshFailed = _order != null;
      });
      if (_order != null) _schedule();
    }
  }

  void _schedule() {
    _poll?.cancel();
    if (_order?.isActive ?? false) {
      _poll = Timer(OrderTrackingScreen.pollInterval, _load);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.white, title: const Text('Order Tracking')),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  child: ErrorView(
                    error: _error!,
                    onRetry: () {
                      setState(() => _error = null);
                      _load();
                    },
                  ),
                ),
        ),
      );
    }
    return _OrderTrackingView(
      order: order,
      justPlaced: widget.justPlaced,
      refreshFailed: _refreshFailed,
    );
  }
}

class _OrderTrackingView extends StatelessWidget {
  const _OrderTrackingView({
    required this.order,
    required this.justPlaced,
    required this.refreshFailed,
  });

  final Order order;
  final bool justPlaced;
  final bool refreshFailed;

  @override
  Widget build(BuildContext context) {
    void back() => justPlaced
        ? context.go(AppRoutes.home)
        : context.popOrGo(AppRoutes.orders);

    return PopScope(
      // The confirmation replaced the whole stack, so system Back goes Home
      // instead of exiting the app.
      canPop: !justPlaced,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.home);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 1,
          shadowColor: Colors.black12,
          titleSpacing: 0,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: back,
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Row(
            children: [
              AppLogo(size: 28),
              SizedBox(width: 8),
              Flexible(child: Text('Order Tracking', style: AppText.titleMd)),
            ],
          ),
          actions: const [ProfileAvatarButton(), SizedBox(width: 8)],
        ),
        body: Stack(
          children: [
            if (justPlaced) const _Confetti(),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (justPlaced) const _SuccessHeader(),
                _OrderSummaryCard(order: order),
                const SizedBox(height: 24),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Order Live Status',
                              style: AppText.titleMd.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Pill(
                            label: order.isActive ? 'Live Updates' : 'Completed',
                            background: order.isActive
                                ? AppColors.primaryFixed.withValues(alpha: 0.4)
                                : AppColors.tertiaryFixed.withValues(alpha: 0.4),
                            foreground: order.isActive
                                ? AppColors.primaryContainer
                                : AppColors.tertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OrderStatusTimeline(order: order),
                      const SizedBox(height: 8),
                      Text(
                        refreshFailed
                            ? 'Couldn’t refresh status. Retrying automatically…'
                            : 'Demo tracking: status is simulated by the mock backend '
                                '(accelerated timeline).',
                        style: AppText.bodySm.copyWith(
                          color: refreshFailed ? AppColors.error : AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (justPlaced) ...[
                  PrimaryButton(
                    label: 'Track Order',
                    leadingIcon: Icons.near_me_outlined,
                    onPressed: () => context.go(AppRoutes.orderTracking(order.id)),
                  ),
                  const SizedBox(height: 8),
                ],
                SecondaryButton(
                  label: justPlaced ? 'Back to Home' : 'Back to Orders',
                  icon: justPlaced ? Icons.storefront : Icons.receipt_long,
                  onPressed: back,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessHeader extends StatefulWidget {
  const _SuccessHeader();

  @override
  State<_SuccessHeader> createState() => _SuccessHeaderState();
}

class _SuccessHeaderState extends State<_SuccessHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FadeTransition(
                  opacity: ReverseAnimation(_c),
                  child: ScaleTransition(
                    scale: Tween(begin: 0.8, end: 1.25).animate(_c),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryFixed.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryContainer.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.tertiaryContainer.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded, size: 44, color: Colors.white),
                ),
                Positioned(
                  top: 18,
                  right: 18,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.sm,
                    ),
                    child: const Icon(
                      Icons.celebration,
                      size: 18,
                      color: AppColors.primaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              'Order Placed Successfully!',
              textAlign: TextAlign.center,
              style: AppText.headlineLg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your delicious food is being prepared with hygiene and care.',
            textAlign: TextAlign.center,
            style: AppText.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatefulWidget {
  const _OrderSummaryCard({required this.order});

  final Order order;

  @override
  State<_OrderSummaryCard> createState() => _OrderSummaryCardState();
}

class _OrderSummaryCardState extends State<_OrderSummaryCard> {
  bool _copied = false;
  Timer? _timer;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: '#${widget.order.id}'));
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
    final order = widget.order;
    final String etaTitle;
    final String etaValue;
    switch (order.status) {
      case OrderStatus.delivered:
        etaTitle = 'Delivered at';
        etaValue = formatTime(order.statusTimes[OrderStatus.delivered]!);
      case OrderStatus.outForDelivery:
        etaTitle = 'Arriving in';
        etaValue = '5-10 mins';
      default:
        etaTitle = 'Estimated Delivery';
        etaValue = order.restaurant.deliveryTime;
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      shadow: AppShadows.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.lg,
            ),
            child: Row(
              children: [
                Text(
                  'ORDER ID ',
                  style: AppText.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
                Expanded(
                  child: Text(
                    '#${order.id}',
                    overflow: TextOverflow.ellipsis,
                    style: AppText.labelMd,
                  ),
                ),
                TextButton.icon(
                  onPressed: _copy,
                  icon: Icon(
                    _copied ? Icons.check : Icons.content_copy,
                    size: 16,
                    color: AppColors.primaryContainer,
                  ),
                  label: Text(
                    _copied ? 'Copied!' : 'Copy',
                    style: AppText.labelSm.copyWith(
                      color: AppColors.primaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.3),
              borderRadius: AppRadius.lg,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.sm,
                  ),
                  child: Icon(
                    order.isActive ? Icons.schedule : Icons.check,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        etaTitle,
                        style: AppText.bodySm.copyWith(
                          color: AppColors.onPrimaryFixedVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        etaValue,
                        style: AppText.headlineMd.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (order.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.full,
                      boxShadow: AppShadows.sm,
                    ),
                    child: Text(
                      'Arriving ${formatTime(order.eta)}',
                      style: AppText.labelSm.copyWith(
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.restaurant,
            iconColor: AppColors.primaryContainer,
            title: order.restaurant.name,
            subtitle: order.items
                .map((i) => '${i.quantity} × ${i.name}')
                .join(', '),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.near_me, size: 14, color: AppColors.primary),
                const SizedBox(width: 2),
                Text(
                  '${order.restaurant.distanceKm} km',
                  style: AppText.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.location_on_outlined,
            iconColor: AppColors.onSurface,
            title: 'Delivery Address',
            subtitle: '${order.address.label} - ${order.address.line}',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.lg,
            ),
            child: Row(
              children: [
                Text(
                  order.payment == PaymentMethod.cod ? 'To Pay: ' : 'Amount Paid: ',
                  style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
                Expanded(
                  child: Text(
                    rupees(order.amount, decimals: true),
                    style: AppText.titleMd.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Pill(
                  label: order.payment.paidLabel,
                  icon: Icons.check_circle_outline,
                  background: AppColors.tertiaryContainer.withValues(alpha: 0.15),
                  foreground: AppColors.tertiary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: AppRadius.lg,
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelMd.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Confetti extends StatelessWidget {
  const _Confetti();

  @override
  Widget build(BuildContext context) {
    const pieces = [
      (x: 45.0, y: 40.0, c: Color(0xFFFF6B35), s: 8.0, round: true),
      (x: 320.0, y: 30.0, c: Color(0xFF00B15C), s: 8.0, round: false),
      (x: 28.0, y: 110.0, c: Color(0xFFFFB59D), s: 8.0, round: false),
      (x: 340.0, y: 120.0, c: Color(0xFFDE2B41), s: 10.0, round: true),
      (x: 70.0, y: 80.0, c: Color(0xFF006D37), s: 7.0, round: false),
      (x: 105.0, y: 35.0, c: Color(0xFFFFDBD0), s: 6.0, round: true),
      (x: 290.0, y: 85.0, c: Color(0xFFFF6B35), s: 7.0, round: false),
      (x: 365.0, y: 70.0, c: Color(0xFFFF6B35), s: 7.0, round: true),
      (x: 15.0, y: 65.0, c: Color(0xFF00B15C), s: 8.0, round: false),
    ];
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / 390;
          return Opacity(
            opacity: 0.5,
            child: Stack(
              children: [
                for (final p in pieces)
                  Positioned(
                    left: p.x * scale,
                    top: p.y,
                    child: Transform.rotate(
                      angle: p.round ? 0 : 0.5,
                      child: Container(
                        width: p.s,
                        height: p.s,
                        decoration: BoxDecoration(
                          color: p.c,
                          shape: p.round ? BoxShape.circle : BoxShape.rectangle,
                          borderRadius: p.round ? null : BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
