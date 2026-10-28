import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models.dart';

class OrderStatusTimeline extends StatefulWidget {
  const OrderStatusTimeline({super.key, required this.order});

  final Order order;

  @override
  State<OrderStatusTimeline> createState() => _OrderStatusTimelineState();
}

class _OrderStatusTimelineState extends State<OrderStatusTimeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  static const _steps = [
    (
      status: OrderStatus.placed,
      title: 'Order Placed',
      done: 'Restaurant confirmed the ticket',
      icon: Icons.check,
    ),
    (
      status: OrderStatus.preparing,
      title: 'Preparing in Kitchen',
      done: 'Master Chef is preparing your food',
      icon: Icons.soup_kitchen_outlined,
    ),
    (
      status: OrderStatus.outForDelivery,
      title: 'Out for Delivery',
      done: 'Your rider is on the way',
      icon: Icons.two_wheeler,
    ),
    (
      status: OrderStatus.delivered,
      title: 'Delivered',
      done: 'Enjoy your fresh hot meal',
      icon: Icons.home_outlined,
    ),
  ];

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.order.status.index;
    final delivered = widget.order.status == OrderStatus.delivered;
    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          _row(i, current, delivered, isLast: i == _steps.length - 1),
      ],
    );
  }

  Widget _row(int i, int current, bool delivered, {required bool isLast}) {
    final step = _steps[i];
    final isDone = i < current || (delivered && i == current);
    final isNow = i == current && !delivered;
    final time = widget.order.statusTimes[step.status];
    final pendingText = switch (step.status) {
      OrderStatus.outForDelivery => 'Rider assigned soon',
      OrderStatus.delivered => 'Enjoy your fresh hot meal',
      _ => step.done,
    };

    final Widget dot;
    if (isNow) {
      dot = SizedBox.square(
        dimension: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            FadeTransition(
              opacity: ReverseAnimation(_pulse),
              child: ScaleTransition(
                scale: Tween(begin: 0.8, end: 1.3).animate(_pulse),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            _circle(AppColors.primaryContainer, Colors.white, step.icon),
          ],
        ),
      );
    } else {
      dot = SizedBox.square(
        dimension: 36,
        child: Center(
          child: isDone
              ? _circle(AppColors.tertiaryContainer, Colors.white, Icons.check)
              : _circle(
                  AppColors.surfaceContainerHigh,
                  AppColors.onSurfaceVariant,
                  step.icon,
                ),
        ),
      );
    }

    final opacity = isDone || isNow ? 1.0 : (i == current + 1 ? 0.6 : 0.4);
    return Opacity(
      opacity: opacity,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                dot,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: i < current
                          ? AppColors.tertiaryContainer
                          : AppColors.surfaceContainer,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            style: AppText.labelMd.copyWith(
                              color: isNow
                                  ? AppColors.primaryContainer
                                  : AppColors.onSurface,
                              fontWeight:
                                  isDone || isNow ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isNow)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryFixed.withValues(alpha: 0.5),
                              borderRadius: AppRadius.sm,
                            ),
                            child: Text(
                              'Now',
                              style: AppText.labelSm.copyWith(
                                color: AppColors.primaryContainer,
                              ),
                            ),
                          )
                        else
                          Text(
                            time != null
                                ? formatTime(time)
                                : (step.status == OrderStatus.delivered
                                    ? '--:--'
                                    : 'Pending'),
                            style: AppText.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      isDone || isNow ? step.done : pendingText,
                      style: AppText.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
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

  Widget _circle(Color bg, Color fg, IconData icon) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: fg),
      );
}
