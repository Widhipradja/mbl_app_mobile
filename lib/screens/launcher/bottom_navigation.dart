import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';

class LauncherNavItem {
  const LauncherNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// Unread count; 0 hides the badge.
  final int badge;
}

/// Fixed bottom bar: four equal items, the active one in the primary colour
/// with a bar under it. Sits above the device's bottom safe area.
class LauncherBottomNavigation extends StatelessWidget {
  const LauncherBottomNavigation({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
  });

  final List<LauncherNavItem> items;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Lx.surface,
        border: Border(top: BorderSide(color: Lx.border)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0D173B80), blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(child: _item(items[i], i)),
          ],
        ),
      ),
    );
  }

  Widget _item(LauncherNavItem item, int i) {
    final active = i == index;
    final color = active ? Lx.primary : Lx.textSecondary;
    return Semantics(
      button: true,
      selected: active,
      label: item.badge > 0
          ? '${item.label}, ${item.badge} belum dibaca'
          : item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onSelect(i),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Badge(
              isLabelVisible: item.badge > 0,
              label: Text('${item.badge}'),
              child: Icon(active ? item.activeIcon : item.icon,
                  size: 24, color: color),
            ),
            const SizedBox(height: Lx.s4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Lx.metadata.copyWith(
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: Lx.s8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: Lx.s12),
              decoration: BoxDecoration(
                color: active ? Lx.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
