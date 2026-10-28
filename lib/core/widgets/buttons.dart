import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Big orange 52px CTA with built-in loading state. While [loading] the
/// button ignores taps, preventing duplicate submissions.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leadingIcon,
    this.loading = false,
    this.loadingLabel,
    this.color = AppColors.primaryContainer,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? leadingIcon;
  final bool loading;
  final String? loadingLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: onPressed == null ? 0.6 : 1,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: AppRadius.xl,
          boxShadow: AppShadows.md,
        ),
        child: Material(
          color: color,
          borderRadius: AppRadius.xl,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Row(
                key: ValueKey(loading),
                mainAxisAlignment: MainAxisAlignment.center,
                children: loading
                    ? [
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          loadingLabel ?? 'Please wait…',
                          style: AppText.labelLg.copyWith(color: Colors.white),
                        ),
                      ]
                    : [
                        if (leadingIcon != null) ...[
                          Icon(leadingIcon, size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.labelLg.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (icon != null) ...[
                          const SizedBox(width: 6),
                          Icon(icon, size: 20, color: Colors.white),
                        ],
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tinted 52px secondary button (e.g. "Back to Home", social logins).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconWidget,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.xl,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconWidget != null) ...[iconWidget!, const SizedBox(width: 8)],
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.onSurface),
                const SizedBox(width: 8),
              ],
              Text(label, style: AppText.labelMd),
            ],
          ),
        ),
      ),
    );
  }
}

/// 40px round tinted icon button (back arrows etc.).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 40,
    this.iconSize = 20,
    this.background = AppColors.surfaceContainerLow,
    this.foreground = AppColors.onSurface,
    this.shadow = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  final double iconSize;
  final Color background;
  final Color foreground;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: shadow ? AppShadows.sm : null,
        ),
        child: Material(
          color: background,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(icon, size: iconSize, color: foreground),
          ),
        ),
      ),
    );
  }
}

/// Text-only link button in the brand orange.
class LinkButton extends StatelessWidget {
  const LinkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final TextStyle? style;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final textStyle =
        (style ?? AppText.labelMd).copyWith(color: AppColors.primaryContainer);
    return InkWell(
      onTap: onPressed,
      borderRadius: AppRadius.lg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.primaryContainer),
              const SizedBox(width: 6),
            ],
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}
