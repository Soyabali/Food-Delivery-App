import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale from the Stitch config (sizes, line heights, tracking).
abstract final class AppText {
  static const _jakarta = 'PlusJakartaSans';
  static const _inter = 'Inter';

  static const headlineXl = TextStyle(
    fontFamily: _jakarta,
    fontSize: 28,
    height: 34 / 28,
    letterSpacing: -0.56,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );
  static const headlineLg = TextStyle(
    fontFamily: _jakarta,
    fontSize: 24,
    height: 30 / 24,
    letterSpacing: -0.36,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );
  static const headlineMd = TextStyle(
    fontFamily: _jakarta,
    fontSize: 22,
    height: 28 / 22,
    letterSpacing: -0.22,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );
  static const titleMd = TextStyle(
    fontFamily: _jakarta,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );
  static const labelLg = TextStyle(
    fontFamily: _inter,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );
  static const labelMd = TextStyle(
    fontFamily: _inter,
    fontSize: 14,
    height: 18 / 14,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );
  static const labelSm = TextStyle(
    fontFamily: _inter,
    fontSize: 11,
    height: 14 / 11,
    letterSpacing: 0.22,
    fontWeight: FontWeight.w700,
    color: AppColors.onSurface,
  );
  static const bodyLg = TextStyle(
    fontFamily: _inter,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );
  static const bodyMd = TextStyle(
    fontFamily: _inter,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );
  static const bodySm = TextStyle(
    fontFamily: _inter,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: AppColors.onSurface,
  );
}
