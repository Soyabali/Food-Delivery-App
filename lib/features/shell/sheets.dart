import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/async_view.dart';
import '../../data/models.dart';
import '../../services/offer_service.dart';
import '../../state/preferences_controller.dart';

/// Saved addresses from GET /addresses; selecting calls
/// POST /addresses/{id}/select.
Future<void> showAddressSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) {
      final prefs = sheetContext.watch<PreferencesController>();
      Widget body;
      if (prefs.isLoading && prefs.addresses.isEmpty) {
        body = const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: ListSkeleton(count: 2, imageSize: 40),
        );
      } else if (prefs.error != null && prefs.addresses.isEmpty) {
        body = ErrorView(error: prefs.error!, onRetry: prefs.load, compact: true);
      } else {
        body = Column(
          children: [
            for (final a in prefs.addresses)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: a.id == prefs.address?.id
                      ? AppColors.primaryFixed.withValues(alpha: 0.4)
                      : AppColors.surfaceContainerLow,
                  borderRadius: AppRadius.xl,
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Icon(
                      a.icon == 'work' ? Icons.work_outline : Icons.home_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(a.label, style: AppText.labelLg),
                    subtitle: Text(
                      a.line,
                      style: AppText.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    trailing: a.id == prefs.address?.id
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.primaryContainer,
                          )
                        : null,
                    onTap: () async {
                      final ok = await runWithFeedback(
                        sheetContext,
                        () => prefs.selectAddress(a),
                      );
                      if (ok && sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                  ),
                ),
              ),
          ],
        );
      }
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Choose delivery address', style: AppText.titleMd),
              const SizedBox(height: 4),
              Text(
                'Your saved addresses',
                style: AppText.bodySm.copyWith(color: AppColors.outline),
              ),
              const SizedBox(height: 12),
              body,
            ],
          ),
        ),
      );
    },
  );
}

/// Notifications from GET /notifications.
Future<void> showNotificationsSheet(BuildContext context) {
  final offers = context.read<OfferService>();
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Notifications', style: AppText.titleMd),
            const SizedBox(height: 12),
            RequestBuilder<List<AppNotification>>(
              request: offers.getNotifications,
              loading: const ListSkeleton(count: 2, imageSize: 40),
              compactError: true,
              isEmpty: (items) => items.isEmpty,
              empty: Text(
                "You're all caught up.",
                textAlign: TextAlign.center,
                style: AppText.bodySm.copyWith(color: AppColors.outline),
              ),
              builder: (context, items) => Column(
                children: [
                  for (final n in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryFixed,
                        child: Icon(
                          switch (n.kind) {
                            'offer' => Icons.local_offer_outlined,
                            'delivery' => Icons.delivery_dining_outlined,
                            _ => Icons.notifications_none,
                          },
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(n.title, style: AppText.labelMd),
                      subtitle: Text(
                        n.body,
                        style: AppText.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      trailing: Text(
                        formatRelative(n.createdAt),
                        style: AppText.bodySm.copyWith(color: AppColors.outline),
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
}
