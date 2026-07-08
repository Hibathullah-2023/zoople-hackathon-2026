import 'package:flutter/material.dart';

/// Nizhal Design System — Color Palette
/// Derived from the UI reference file (Material Design 3 dark theme)
class AppColors {
  AppColors._();

  // ─── Brand Colors ───
  static const Color primary = Color(0xFFBEC6E0);
  static const Color onPrimary = Color(0xFF283044);
  static const Color primaryContainer = Color(0xFF0F172A);
  static const Color onPrimaryContainer = Color(0xFF798098);
  static const Color primaryFixed = Color(0xFFDAE2FD);
  static const Color primaryFixedDim = Color(0xFFBEC6E0);

  // ─── Secondary (Teal Accent) ───
  static const Color secondary = Color(0xFF4FDBC8);
  static const Color onSecondary = Color(0xFF003731);
  static const Color secondaryContainer = Color(0xFF04B4A2);
  static const Color onSecondaryContainer = Color(0xFF003F38);
  static const Color secondaryFixed = Color(0xFF71F8E4);
  static const Color secondaryFixedDim = Color(0xFF4FDBC8);

  // ─── Tertiary ───
  static const Color tertiary = Color(0xFF3CDDC7);
  static const Color onTertiary = Color(0xFF003731);
  static const Color tertiaryContainer = Color(0xFF001C18);
  static const Color onTertiaryContainer = Color(0xFF009182);
  static const Color tertiaryFixed = Color(0xFF62FAE3);
  static const Color tertiaryFixedDim = Color(0xFF3CDDC7);

  // ─── Error ───
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // ─── Surface / Background ───
  static const Color surface = Color(0xFF081425);
  static const Color surfaceDim = Color(0xFF081425);
  static const Color surfaceBright = Color(0xFF2F3A4C);
  static const Color surfaceContainerLowest = Color(0xFF040E1F);
  static const Color surfaceContainerLow = Color(0xFF111C2D);
  static const Color surfaceContainer = Color(0xFF152031);
  static const Color surfaceContainerHigh = Color(0xFF1F2A3C);
  static const Color surfaceContainerHighest = Color(0xFF2A3548);
  static const Color surfaceVariant = Color(0xFF2A3548);

  static const Color onSurface = Color(0xFFD8E3FB);
  static const Color onSurfaceVariant = Color(0xFFC6C6CD);
  static const Color onBackground = Color(0xFFD8E3FB);
  static const Color background = Color(0xFF081425);

  // ─── Outline ───
  static const Color outline = Color(0xFF909097);
  static const Color outlineVariant = Color(0xFF45464D);

  // ─── Inverse ───
  static const Color inverseSurface = Color(0xFFD8E3FB);
  static const Color inverseOnSurface = Color(0xFF263143);
  static const Color inversePrimary = Color(0xFF565E74);

  // ─── Surface Tint ───
  static const Color surfaceTint = Color(0xFFBEC6E0);

  // ─── Priority Colors ───
  static const Color priorityCritical = Color(0xFFFF5252);
  static const Color priorityHigh = Color(0xFFFF9800);
  static const Color priorityMedium = Color(0xFFFFEB3B);
  static const Color priorityLow = Color(0xFF4CAF50);

  // ─── Status Colors ───
  static const Color statusSubmitted = Color(0xFF90A4AE);
  static const Color statusUnderReview = Color(0xFF42A5F5);
  static const Color statusAssigned = Color(0xFFAB47BC);
  static const Color statusInProgress = Color(0xFFFF9800);
  static const Color statusResolved = Color(0xFF66BB6A);
  static const Color statusClosed = Color(0xFF78909C);
  static const Color statusFake = Color(0xFFEF5350);

  // ─── Utility ───
  static const Color shimmerBase = Color(0xFF111C2D);
  static const Color shimmerHighlight = Color(0xFF1F2A3C);
  static const Color divider = Color(0x0DFFFFFF); // white/5
  static const Color cardBorderTop = Color(0x1AFFFFFF); // white/10
}
