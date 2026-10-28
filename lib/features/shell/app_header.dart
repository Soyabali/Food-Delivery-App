import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/common.dart';
import '../../state/preferences_controller.dart';
import 'sheets.dart';

/// "DELIVER TO ⌄ / Home" header with notifications and profile avatar,
/// shared by the Home and Cart tabs.
class DeliveryHeader extends StatelessWidget implements PreferredSizeWidget {
  const DeliveryHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final address = context.watch<PreferencesController>().address;
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      shadowColor: Colors.black12,
      elevation: 1,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const AppLogo(size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    borderRadius: AppRadius.lg,
                    onTap: () => showAddressSheet(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              'DELIVER TO',
                              style: AppText.labelSm.copyWith(
                                color: AppColors.primary,
                                letterSpacing: 1,
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                        Text(
                          address?.label ?? 'Choose address',
                          overflow: TextOverflow.ellipsis,
                          style: AppText.labelMd,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => showNotificationsSheet(context),
                  icon: const Icon(Icons.notifications_outlined, size: 22),
                ),
                const ProfileAvatarButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Profile',
      child: InkResponse(
        onTap: () => context.go(AppRoutes.profile),
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryContainer.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: AppImage(
                'assets/images/avatar.jpg',
                width: size,
                height: size,
                placeholderIcon: Icons.person,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
