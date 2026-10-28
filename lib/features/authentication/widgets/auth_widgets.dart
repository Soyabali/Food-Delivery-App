import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: AppRadius.xl,
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 20, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppText.bodyMd.copyWith(color: const Color(0xFF93000A)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PerkBanner extends StatelessWidget {
  const PerkBanner({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.xl,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.tertiaryFixed,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.redeem, size: 18, color: AppColors.tertiary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.labelSm),
                Text(
                  subtitle,
                  style: AppText.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.surfaceDim, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: AppText.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.surfaceDim, height: 1)),
      ],
    );
  }
}

/// Multicolour Google "G", ported from the Stitch SVG.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final rect = Rect.fromCircle(center: Offset(12 * s, 12 * s), radius: 9 * s);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2 * s;
    const deg = 3.14159265 / 180;
    void arc(Color c, double start, double sweep) {
      paint.color = c;
      canvas.drawArc(rect, start * deg, sweep * deg, false, paint);
    }

    arc(const Color(0xFFEA4335), 200, 115); // red, top-left
    arc(const Color(0xFFFBBC05), 140, 62); // yellow, left
    arc(const Color(0xFF34A853), 45, 97); // green, bottom
    arc(const Color(0xFF4285F4), 0, 47); // blue, right
    canvas.drawRect(
      Rect.fromLTWH(12 * s, 10 * s, 11 * s, 4.2 * s),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
