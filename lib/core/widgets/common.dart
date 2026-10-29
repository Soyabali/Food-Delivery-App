import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Brand mark. The Stitch logo image URL is not publicly downloadable, so the
/// mark is drawn in code (burger glyph on the brand gradient).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryContainer, AppColors.secondaryContainer],
        ),
      ),
      child: Icon(Icons.lunch_dining, size: size * 0.6, color: Colors.white),
    );
  }
}

/// Network (http/https) or bundled image with loading and error placeholders,
/// so a slow or broken image URL never shows a broken-image icon.
class AppImage extends StatelessWidget {
  const AppImage(
    this.asset, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholderIcon = Icons.restaurant,
  });

  final String? asset;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final IconData placeholderIcon;

  /// Backend the app talks to (null with the mock backend). Set at startup.
  static Uri? backendOrigin;

  /// The backend stores uploaded images as `http://localhost:8000/media/...`
  /// (its own view of itself). On a phone or emulator `localhost` is the
  /// device, so such URLs are pointed at the backend's real host instead.
  static String resolveUrl(String url, {Uri? origin}) {
    final backend = origin ?? backendOrigin;
    final uri = Uri.tryParse(url);
    if (backend == null || uri == null) return url;
    if (uri.host != 'localhost' && uri.host != '127.0.0.1') return url;
    return uri
        .replace(scheme: backend.scheme, host: backend.host, port: backend.port)
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.surfaceContainer,
      alignment: Alignment.center,
      child: Icon(placeholderIcon, color: AppColors.outline, size: 28),
    );
    final source = asset;
    Widget image;
    if (source == null || source.isEmpty) {
      image = placeholder;
    } else if (source.startsWith('http')) {
      image = Image.network(
        resolveUrl(source),
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(
                width: width,
                height: height,
                color: AppColors.surfaceContainerLow,
              ),
        errorBuilder: (_, _, _) => placeholder,
      );
    } else {
      image = Image.asset(
        source,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

/// Indian food-type indicator: green dot (veg) or red square (non-veg).
class VegMark extends StatelessWidget {
  const VegMark({super.key, required this.isVeg, this.size = 16});

  final bool isVeg;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? AppColors.tertiary : AppColors.secondary;
    return Semantics(
      label: isVeg ? 'Vegetarian' : 'Non-vegetarian',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.2),
        ),
        alignment: Alignment.center,
        child: Container(
          width: size * 0.55,
          height: size * 0.55,
          decoration: BoxDecoration(
            color: color,
            shape: isVeg ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isVeg ? null : BorderRadius.circular(1.5),
          ),
        ),
      ),
    );
  }
}

class RatingPill extends StatelessWidget {
  const RatingPill(this.rating, {super.key});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        color: AppColors.tertiaryContainer,
        borderRadius: AppRadius.full,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 11, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: AppText.labelSm.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Small rounded label (e.g. "REQUIRED", "APPLIED", "Now").
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.icon,
    this.background = AppColors.surfaceContainer,
    this.foreground = AppColors.onSurface,
    this.uppercase = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.fontSize,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final bool uppercase;
  final EdgeInsets padding;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.full,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              uppercase ? label.toUpperCase() : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.labelSm.copyWith(
                color: foreground,
                fontSize: fontSize,
                letterSpacing: uppercase ? 0.8 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White rounded card with the Stitch shadow-sm.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = AppColors.surfaceContainerLowest,
    this.onTap,
    this.shadow = AppShadows.sm,
    this.gradient,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: AppRadius.xl,
        boxShadow: shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: AppRadius.xl,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.titleMd),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppText.bodySm.copyWith(color: AppColors.outline),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Friendly empty / error state used across lists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(title, style: AppText.headlineMd, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.xl,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                actionLabel!,
                style: AppText.labelMd.copyWith(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Circular +/- quantity control used in cart and dish details.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.min = 0,
    this.compact = true,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final int min;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final buttonSize = compact ? 24.0 : 36.0;
    Widget button(IconData icon, VoidCallback? onTap, {bool primary = false}) {
      return Material(
        color: primary
            ? AppColors.primaryContainer
            : AppColors.surfaceContainerLowest,
        shape: const CircleBorder(),
        elevation: 0.5,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: buttonSize,
            child: Icon(
              icon,
              size: compact ? 14 : 20,
              color: primary ? Colors.white : AppColors.onSurface,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 6, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.full,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Decrease quantity',
            child: button(
              Icons.remove,
              quantity > min ? () => onChanged(quantity - 1) : null,
            ),
          ),
          SizedBox(
            width: compact ? 28 : 40,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: compact ? AppText.labelMd : AppText.labelLg,
            ),
          ),
          Semantics(
            label: 'Increase quantity',
            child: button(
              Icons.add,
              quantity < 20 ? () => onChanged(quantity + 1) : null,
              primary: true,
            ),
          ),
        ],
      ),
    );
  }
}
