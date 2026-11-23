import 'package:flutter/material.dart';

/// Shared visual tokens for the Zakat Fitrah screens (see the "Baraka UI
/// Template" design). Use these instead of new hard-coded colours.
class Bk {
  Bk._();

  // Brand
  static const brandDark = Color(0xFF064E3B);
  static const brand = Color(0xFF066046);
  static const brandSoft = Color(0xFFE6F2ED);

  // Surfaces & text
  static const ground = Color(0xFFF6F8F7);
  static const line = Color(0xFFE3EAE6);
  static const text = Color(0xFF0F1F1A);
  static const textMuted = Color(0xFF5B6B65);
  static const danger = Color(0xFFB42318);

  // Status (background / foreground pairs)
  static const doneBg = Color(0xFFDDF3E7);
  static const doneFg = Color(0xFF0B5F3A);
  static const pendingBg = Color(0xFFFDF3DC);
  static const pendingFg = Color(0xFF8A5A0B);
  static const externalBg = Color(0xFFEEF2FF);
  static const externalFg = Color(0xFF3730A3);
  static const idleBg = Color(0xFFF1F5F3);

  static const double radiusCard = 16;
  static const double radiusButton = 12;

  static BoxDecoration card({Color? border}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radiusCard),
        border: Border.all(color: border ?? line),
      );
}

/// Status always carries a text label, never colour alone.
class BkStatusPill extends StatelessWidget {
  const BkStatusPill({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
  });

  const BkStatusPill.done(this.label, {super.key})
      : bg = Bk.doneBg,
        fg = Bk.doneFg;
  const BkStatusPill.pending(this.label, {super.key})
      : bg = Bk.pendingBg,
        fg = Bk.pendingFg;
  const BkStatusPill.idle(this.label, {super.key})
      : bg = Bk.idleBg,
        fg = Bk.textMuted;

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
        ),
      );
}
