import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';

/// Heading of a home-screen section: a title on the left and, on the right,
/// either a "Semua" link ([onAction]) or a plain note ([trailing], e.g.
/// "2 aktif").
class LauncherHeading extends StatelessWidget {
  const LauncherHeading({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  final String title;

  /// Read by screen readers, e.g. "Semua aplikasi".
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Lx.sectionHeading.copyWith(fontSize: 17),
            ),
          ),
        ),
        if (onAction != null)
          Semantics(
            button: true,
            label: actionLabel ?? 'Semua',
            excludeSemantics: true,
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(Lx.rSmall),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                child: const Padding(
                  padding: EdgeInsets.only(left: Lx.s8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 1,
                    child: Icon(Icons.chevron_right_rounded,
                        size: 26, color: Lx.primary),
                  ),
                ),
              ),
            ),
          )
        else if (trailing != null)
          Text(trailing!,
              style: Lx.button.copyWith(
                  fontSize: 13,
                  color: Lx.textSecondary,
                  fontWeight: FontWeight.w600)),
      ],
    );
  }
}
