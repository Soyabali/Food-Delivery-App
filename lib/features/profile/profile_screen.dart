import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_routes.dart';
import '../../app/app.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/adaptive_dialogs.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/async_view.dart';
import '../../data/models.dart';
import '../../services/food_service.dart';
import '../../services/restaurant_service.dart';
import '../../state/auth_controller.dart';
import '../../state/orders_controller.dart';
import '../../state/preferences_controller.dart';
import '../shell/sheets.dart';

/// Not part of the Stitch export; hosts account actions (change password,
/// logout) in the app's visual language.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: "You'll need to sign in again to place orders.",
      confirmLabel: 'Log out',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<AuthController>().logout();
    // `go` discards the tab stacks so Back cannot reopen the dashboard.
    if (context.mounted) context.go(AppRoutes.login);
  }

  /// Mock mode only: wipes the on-device mock backend and signs out.
  Future<void> _resetDemo(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Reset demo data?',
      message:
          'Deletes demo accounts you created, orders, carts and favourites '
          'stored by the mock backend on this device, then signs you out.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final auth = context.read<AuthController>();
    await context.read<AppServices>().mockBackend?.resetAll();
    await auth.logout();
    if (context.mounted) context.go(AppRoutes.login);
  }

  void _showFavourites(BuildContext context) {
    final restaurants = context.read<RestaurantService>();
    final food = context.read<FoodService>();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final favs = sheetContext.watch<PreferencesController>().favorites;
        Future<(List<Restaurant>, List<Dish>)> load() async {
          final all = await restaurants.all();
          final dishes = await Future.wait(
            favs.dishes.map((id) => food.getDish(int.parse(id))),
          );
          return (
            all.where((r) => favs.restaurants.contains(r.id)).toList(),
            dishes,
          );
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Favourites', style: AppText.titleMd),
                  const SizedBox(height: 8),
                  RequestBuilder<(List<Restaurant>, List<Dish>)>(
                    requestKey: (favs.restaurants.length, favs.dishes.length),
                    request: load,
                    loading: const ListSkeleton(count: 2, imageSize: 44),
                    compactError: true,
                    isEmpty: (r) => r.$1.isEmpty && r.$2.isEmpty,
                    empty: const EmptyState(
                      icon: Icons.favorite_border,
                      title: 'No favourites yet',
                      message: 'Tap the heart on a restaurant or dish to save it.',
                    ),
                    builder: (context, data) => Column(
                      children: [
                        for (final r in data.$1)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: AppImage(r.image, width: 44, height: 44, borderRadius: AppRadius.lg),
                            title: Text(r.name, style: AppText.labelMd),
                            subtitle: Text(r.cuisineLine, style: AppText.bodySm),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              context.push(AppRoutes.restaurant(r.id));
                            },
                          ),
                        for (final d in data.$2)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: AppImage(d.image, width: 44, height: 44, borderRadius: AppRadius.lg),
                            title: Text(d.name, style: AppText.labelMd),
                            subtitle: Text(d.restaurantName, style: AppText.bodySm),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              context.push(AppRoutes.dish(d.id, restaurantId: d.restaurantId));
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final isDemo = context.read<AuthController>().isDemoMode;
    final prefs = context.watch<PreferencesController>();
    final orderCount = context.select<OrdersController, int>((o) => o.orders.length);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Profile', style: AppText.headlineMd),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AppCard(
            color: AppColors.surfaceContainerLow,
            shadow: null,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const ClipOval(
                  child: AppImage(
                    'assets/images/avatar.jpg',
                    width: 64,
                    height: 64,
                    placeholderIcon: Icons.person,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Guest', style: AppText.titleMd),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: AppText.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      if (user?.phone != null)
                        Text(
                          '+91 ${user!.phone}',
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: '$orderCount',
                  label: 'Orders',
                  onTap: () => context.go(AppRoutes.orders),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  value: '${prefs.favorites.count}',
                  label: 'Favourites',
                  onTap: () => _showFavourites(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Group(
            title: 'Account',
            children: [
              _Tile(
                icon: Icons.receipt_long_outlined,
                label: 'My Orders',
                onTap: () => context.go(AppRoutes.orders),
              ),
              _Tile(
                icon: Icons.location_on_outlined,
                label: 'Saved Addresses',
                value: prefs.address?.label,
                onTap: () => showAddressSheet(context),
              ),
              _Tile(
                icon: Icons.favorite_border,
                label: 'Favourites',
                onTap: () => _showFavourites(context),
              ),
              _Tile(
                icon: Icons.lock_reset,
                label: 'Change Password',
                onTap: () => context.push(AppRoutes.changePassword),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Group(
            title: 'Preferences',
            children: [
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                title: const Text('Order & offer notifications', style: AppText.labelMd),
                value: prefs.notificationsEnabled,
                onChanged: prefs.setNotifications,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Group(
            title: 'Support',
            children: [
              _Tile(
                icon: Icons.help_outline,
                label: 'Help & Support',
                onTap: () => showInfoDialog(
                  context,
                  title: 'Help & Support',
                  message:
                      'Live support chat is not part of this build yet.',
                ),
              ),
              _Tile(
                icon: Icons.info_outline,
                label: 'About Apna Food',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Apna Food',
                  applicationVersion: 'v2.4.0',
                  applicationIcon: const AppLogo(size: 40),
                  applicationLegalese: isDemo
                      ? 'Demo build: food data from DummyJSON; sign-in, cart, '
                          'orders and payment are simulated on this device.'
                      : null,
                ),
              ),
              if (isDemo)
                _Tile(
                  icon: Icons.restart_alt,
                  label: 'Reset demo data',
                  onTap: () => _resetDemo(context),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: AppColors.secondaryFixed.withValues(alpha: 0.5),
            borderRadius: AppRadius.xl,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppColors.secondary),
              title: Text(
                'Log out',
                style: AppText.labelLg.copyWith(color: AppColors.secondary),
              ),
              onTap: () => _logout(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.onTap});

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(value, style: AppText.headlineMd.copyWith(color: AppColors.primaryContainer)),
          Text(label, style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title.toUpperCase(),
            style: AppText.labelSm.copyWith(
              color: AppColors.outline,
              letterSpacing: 1,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: AppText.labelMd),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(value!, style: AppText.bodySm.copyWith(color: AppColors.outline)),
          const Icon(Icons.chevron_right, color: AppColors.outline),
        ],
      ),
      onTap: onTap,
    );
  }
}
