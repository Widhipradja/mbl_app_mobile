import 'package:flutter/material.dart';

/// Design tokens for the launcher home and the Information Hub
/// (docs/MOBILE_DASHBOARD_DESIGN.md §2). The module screens keep their own
/// tokens in `baraka_tokens.dart`.
class Lx {
  Lx._();

  static const font = 'Inter';

  // ── Colours ──────────────────────────────────────────────────────────────
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF173B80);
  static const primaryLight = Color(0xFFE5EEFF);
  static const skyBlue = Color(0xFF38BDF8);
  static const bannerStart = Color(0xFF1D4ED8);

  static const secondary = Color(0xFF7C3AED);
  static const secondaryLight = Color(0xFFEDE9FE);

  static const background = Color(0xFFF5F8FF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSecondary = Color(0xFFF0EBFF);

  static const text = Color(0xFF142B55);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF97316);
  static const fundraising = Color(0xFFEC4899);
  static const info = Color(0xFF2563EB);
  static const danger = Color(0xFFDC2626);
  static const border = Color(0xFFE5EAF5);
  static const launcherBorder = Color(0xFFA7C7FF);

  // ── Spacing (8px scale) ──────────────────────────────────────────────────
  static const double s4 = 4, s8 = 8, s12 = 12, s16 = 16, s20 = 20, s24 = 24;
  static const double s32 = 32;

  // ── Radius ───────────────────────────────────────────────────────────────
  static const double rSmall = 8, rButton = 12, rTile = 18, rCard = 18;
  static const double rSection = 24;

  // ── Shadows ──────────────────────────────────────────────────────────────
  static const shadowSoft = [
    BoxShadow(color: Color(0x12173B80), blurRadius: 16, offset: Offset(0, 4)),
  ];

  // ── Typography ───────────────────────────────────────────────────────────
  static const greeting = TextStyle(
      fontFamily: font,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.25,
      color: textSecondary);
  static const userName = TextStyle(
      fontFamily: font,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -0.4,
      color: text);
  static const sectionHeading = TextStyle(
      fontFamily: font,
      fontSize: 19,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.3,
      color: text);
  static const sectionSubtitle = TextStyle(
      fontFamily: font,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: textSecondary);
  static const cardHeading = TextStyle(
      fontFamily: font,
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: text);
  static const moduleLabel = TextStyle(
      fontFamily: font,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: text);
  static const body = TextStyle(
      fontFamily: font,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: textSecondary);
  static const metadata = TextStyle(
      fontFamily: font,
      fontSize: 11.5,
      fontWeight: FontWeight.w500,
      height: 1.3,
      color: textSecondary);
  static const button = TextStyle(
      fontFamily: font, fontSize: 13, fontWeight: FontWeight.w600, height: 1.2);

  static BoxDecoration card() => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(rCard),
        border: Border.all(color: border),
      );

  /// Light theme for the launcher screens, whatever the system brightness:
  /// their surfaces are fixed light colours.
  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: font,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(primary: primary, surface: surface, error: danger),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontFamily: font,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rButton),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rButton),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rButton),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
    ),
  );
}
