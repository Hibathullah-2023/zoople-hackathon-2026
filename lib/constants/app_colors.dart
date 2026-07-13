import 'package:flutter/material.dart';

/// Nizhal Design System — Color Palette
/// Derived from the UI reference file
class AppColors {
  AppColors._();

  // ─── Brand Colors ───
  static const Color primary = Color(0xFF14B8A6); // Teal
  static const Color onPrimary = Color(0xFF0F172A); // Deep Navy
  static const Color primaryContainer = Color(0xFF1E293B); // Dark Slate Blue
  static const Color onPrimaryContainer = Color(0xFFE2E8F0); // Off White
  static const Color primaryFixed = Color(0xFF2DD4BF); // Aqua Cyan
  static const Color primaryFixedDim = Color(0xFF14B8A6); // Teal

  // ─── Secondary ───
  static const Color secondary = Color(0xFF2DD4BF); // Aqua Cyan
  static const Color onSecondary = Color(0xFF0F172A);
  static const Color secondaryContainer = Color(0xFF1E293B);
  static const Color onSecondaryContainer = Color(0xFFE2E8F0);
  static const Color secondaryFixed = Color(0xFF2DD4BF);
  static const Color secondaryFixedDim = Color(0xFF14B8A6);

  // ─── Tertiary ───
  static const Color tertiary = Color(0xFF14B8A6);
  static const Color onTertiary = Color(0xFF0F172A);
  static const Color tertiaryContainer = Color(0xFF1E293B);
  static const Color onTertiaryContainer = Color(0xFFE2E8F0);
  static const Color tertiaryFixed = Color(0xFF2DD4BF);
  static const Color tertiaryFixedDim = Color(0xFF14B8A6);

  // ─── Error ───
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // ─── Surface / Background ───
  static const Color surface = Color(0xFF0F172A); // Deep Navy
  static const Color surfaceDim = Color(0xFF0F172A);
  static const Color surfaceBright = Color(0xFF1E293B); // Dark Slate Blue
  static const Color surfaceContainerLowest = Color(0xFF0B101E);
  static const Color surfaceContainerLow = Color(0xFF131D31);
  static const Color surfaceContainer = Color(0xFF1E293B);
  static const Color surfaceContainerHigh = Color(0xFF25334A);
  static const Color surfaceContainerHighest = Color(0xFF2E405C);
  static const Color surfaceVariant = Color(0xFF1E293B);

  static const Color onSurface = Color(0xFFE2E8F0); // Off White
  static const Color onSurfaceVariant = Color(
    0xFFE2E8F0,
  ); // Brighter Off White for high visibility
  static const Color onBackground = Color(0xFFE2E8F0);
  static const Color background = Color(0xFF0F172A); // Deep Navy

  // ─── Outline ───
  static const Color outline = Color(0xFF9CA3AF);
  static const Color outlineVariant = Color(0xFF4B5563);

  // ─── Inverse ───
  static const Color inverseSurface = Color(0xFFE2E8F0);
  static const Color inverseOnSurface = Color(0xFF0F172A);
  static const Color inversePrimary = Color(0xFF14B8A6);

  // ─── Surface Tint ───
  static const Color surfaceTint = Color(0xFF14B8A6);

  // ─── Priority Colors ───
  static const Color priorityCritical = Color(0xFFFF5252);
  static const Color priorityHigh = Color(0xFFFF9800);
  static const Color priorityMedium = Color(0xFFFFEB3B);
  static const Color priorityLow = Color(0xFF4CAF50);

  // ─── Status Colors ───
  static const Color statusSubmitted = Color(0xFF9CA3AF);
  static const Color statusUnderReview = Color(0xFF60A5FA);
  static const Color statusAssigned = Color(0xFFC084FC);
  static const Color statusInProgress = Color(0xFFF59E0B);
  static const Color statusResolved = Color(0xFF10B981);
  static const Color statusClosed = Color(0xFF6B7280);
  static const Color statusFake = Color(0xFFEF4444);

  // ─── Utility ───
  static const Color shimmerBase = Color(0xFF1E293B);
  static const Color shimmerHighlight = Color(0xFF25334A);
  static const Color divider = Color(0x1FFFFFFF);
  static const Color cardBorderTop = Color(0x33FFFFFF);
}
