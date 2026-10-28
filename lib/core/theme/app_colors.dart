import 'package:flutter/material.dart';

/// Design tokens copied from the Stitch Tailwind config.
abstract final class AppColors {
  static const primary = Color(0xFFAB3500);
  static const primaryContainer = Color(0xFFFF6B35);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFF5F1900);
  static const primaryFixed = Color(0xFFFFDBD0);
  static const primaryFixedDim = Color(0xFFFFB59D);
  static const onPrimaryFixed = Color(0xFF390C00);
  static const onPrimaryFixedVariant = Color(0xFF832600);

  static const secondary = Color(0xFFB9052C);
  static const secondaryContainer = Color(0xFFDE2B41);
  static const secondaryFixed = Color(0xFFFFDAD9);

  static const tertiary = Color(0xFF006D37);
  static const tertiaryContainer = Color(0xFF00B15C);
  static const onTertiary = Color(0xFFFFFFFF);
  static const onTertiaryContainer = Color(0xFF003B1A);
  static const tertiaryFixed = Color(0xFF6BFE9C);
  static const tertiaryFixedDim = Color(0xFF4AE183);

  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);

  static const surface = Color(0xFFF8F9FF);
  static const surfaceDim = Color(0xFFD0DBED);
  static const surfaceVariant = Color(0xFFD9E3F6);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFEFF4FF);
  static const surfaceContainer = Color(0xFFE6EEFF);
  static const surfaceContainerHigh = Color(0xFFDEE9FC);
  static const surfaceContainerHighest = Color(0xFFD9E3F6);

  static const onSurface = Color(0xFF121C2A);
  static const onSurfaceVariant = Color(0xFF594139);
  static const outline = Color(0xFF8D7168);
  static const outlineVariant = Color(0xFFE1BFB5);
}

/// Tailwind's shadow-sm / shadow-md equivalents.
abstract final class AppShadows {
  static const sm = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const md = [
    BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
  ];
  static const lg = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10)),
  ];
}

abstract final class AppRadius {
  static const sm = BorderRadius.all(Radius.circular(4));
  static const lg = BorderRadius.all(Radius.circular(8));
  static const xl = BorderRadius.all(Radius.circular(12));
  static const xxl = BorderRadius.all(Radius.circular(16));
  static const xxxl = BorderRadius.all(Radius.circular(24));
  static const full = BorderRadius.all(Radius.circular(999));
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const margin = 16.0;
}
