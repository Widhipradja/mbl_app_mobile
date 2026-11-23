import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/launcher_tokens.dart';
import 'launcher_models.dart';
import 'section_header.dart';

/// Shortcuts to the applications this user may operate. Information (events,
/// fundraising, announcements) belongs in the Information Hub, not here.
class AppLauncher extends StatelessWidget {
  const AppLauncher({
    super.key,
    required this.modules,
    required this.onSeeAll,
  });

  final List<LauncherModule> modules;
  final VoidCallback onSeeAll;

  /// Tiles shown on the home screen, the last being "Semua".
  static const _slots = 8;

  @override
  Widget build(BuildContext context) {
    final shown =
        modules.length > _slots - 1 ? modules.take(_slots - 1) : modules;

    final tiles = <Widget>[
      for (final m in shown)
        AppModuleTile(
          label: m.label,
          icon: m.icon,
          emoji: m.emoji,
          color: m.color,
          onTap: () => m.push ? context.push(m.route) : context.go(m.route),
        ),
      AppModuleTile(
        label: 'Semua',
        icon: Icons.grid_view_outlined,
        color: Lx.textSecondary,
        onTap: onSeeAll,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LauncherHeading(
          title: 'Aplikasi',
          actionLabel: 'Semua aplikasi',
          onAction: onSeeAll,
        ),
        const SizedBox(height: Lx.s8),
        if (modules.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: Lx.s12),
            child: Text(
              'Belum ada aplikasi untuk role Anda. Hubungi admin untuk '
              'mendapatkan akses.',
              style: Lx.body,
            ),
          )
        else
          LayoutBuilder(builder: (context, c) {
            // Four columns; larger fonts need wider tiles, so fewer.
            final scale =
                MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
            final perRow = scale > 1.3 ? 3 : 4;
            return _grid(tiles, perRow);
          }),
      ],
    );
  }

  Widget _grid(List<Widget> tiles, int perRow) {
    const gap = Lx.s12;
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += perRow)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : Lx.s16),
            // Tiles in a row share the tallest one's height.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < perRow; c++) ...[
                    if (c > 0) const SizedBox(width: gap),
                    Expanded(
                      child: i + c < tiles.length
                          ? tiles[i + c]
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One application shortcut: our icon on a white rounded square, the label
/// beneath it.
class AppModuleTile extends StatelessWidget {
  const AppModuleTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.emoji,
  });

  final String label;
  final IconData icon;

  /// Drawn in place of [icon] when set.
  final String? emoji;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Lx.rSmall),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Lx.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Lx.border),
              ),
              child: emoji != null
                  ? Text(emoji!,
                      style: const TextStyle(fontSize: 26, height: 1.15))
                  : Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: Lx.s8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Lx.moduleLabel.copyWith(fontSize: 12, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
