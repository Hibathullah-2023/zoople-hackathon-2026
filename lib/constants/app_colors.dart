import 'package:flutter/material.dart';

/// Nizhal Design System — Color Palette
/// Derived from the UI reference file
class AppColors {
  AppColors._();

  // ─── Brand Colors ───
  static const Color primary = Color(0xFF1E3A8A); // Primary Blue
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFE0E7FF);
  static const Color onPrimaryContainer = Color(0xFF1E3A8A);
  static const Color primaryFixed = Color(0xFF3B82F6);
  static const Color primaryFixedDim = Color(0xFF1E3A8A);

  // ─── Secondary ───
  static const Color secondary = Color(0xFF2563EB); // Secondary Blue
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFDBEAFE);
  static const Color onSecondaryContainer = Color(0xFF1E3A8A);
  static const Color secondaryFixed = Color(0xFF2563EB);
  static const Color secondaryFixedDim = Color(0xFF1D4ED8);

  // ─── Tertiary / Accent ───
  static const Color tertiary = Color(0xFF60A5FA); // Accent Blue
  static const Color onTertiary = Color(0xFF1F2937);
  static const Color tertiaryContainer = Color(0xFFEFF6FF);
  static const Color onTertiaryContainer = Color(0xFF1E3A8A);
  static const Color tertiaryFixed = Color(0xFF60A5FA);
  static const Color tertiaryFixedDim = Color(0xFF3B82F6);

  // ─── Error ───
  static const Color error = Color(0xFFDC2626); // Error / Alert
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onErrorContainer = Color(0xFFDC2626);

  // ─── Surface / Background ───
  static const Color surface = Color(0xFFFFFFFF); // Card Background
  static const Color surfaceDim = Color(0xFFF1F5F9);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF8FAFC);
  static const Color surfaceContainer = Color(0xFFF1F5F9);
  static const Color surfaceContainerHigh = Color(0xFFE2E8F0);
  static const Color surfaceContainerHighest = Color(0xFFCBD5E1);
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  static const Color onSurface = Color(0xFF1F2937); // Primary Text
  static const Color onSurfaceVariant = Color(0xFF64748B); // Secondary Text
  static const Color onBackground = Color(0xFF1F2937);
  static const Color background = Color(0xFFF8FAFC); // Background

  // ─── Outline ───
  static const Color outline = Color(0xFF64748B);
  static const Color outlineVariant = Color(0xFFDCE5F2); // Border

  // ─── Inverse ───
  static const Color inverseSurface = Color(0xFF1F2937);
  static const Color inverseOnSurface = Color(0xFFFFFFFF);
  static const Color inversePrimary = Color(0xFF60A5FA);

  // ─── Surface Tint ───
  static const Color surfaceTint = Color(0xFF1E3A8A);

  // ─── Priority Colors ───
  static const Color priorityCritical = Color(0xFFDC2626); // Error
  static const Color priorityHigh = Color(0xFFF59E0B); // Warning
  static const Color priorityMedium = Color(0xFF3B82F6);
  static const Color priorityLow = Color(0xFF16A34A); // Success

  // ─── Status Colors ───
  static const Color statusSubmitted = Color(0xFF64748B);
  static const Color statusUnderReview = Color(0xFF60A5FA);
  static const Color statusAssigned = Color(0xFF2563EB);
  static const Color statusInProgress = Color(0xFFF59E0B);
  static const Color statusResolved = Color(0xFF16A34A);
  static const Color statusClosed = Color(0xFF64748B);
  static const Color statusFake = Color(0xFFDC2626);

  // ─── Utility ───
  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFDCE5F2); // Border
  static const Color cardBorderTop = Color(0xFFDCE5F2); // Border
}
