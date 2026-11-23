import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import 'user_avatar.dart';

/// Avatar, greeting and name on the left; notifications and settings on the
/// right.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.username,
    required this.unseenNotices,
    required this.onOpenNotifications,
    required this.onOpenSettings,
    this.avatarUrl,
  });

  final String username;
  final String? avatarUrl;
  final int unseenNotices;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    // A smaller avatar leaves room for the name on narrow phones.
    final avatar = MediaQuery.sizeOf(context).width < 360 ? 44.0 : 52.0;
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Profil',
          child: InkWell(
            onTap: onOpenSettings,
            customBorder: const CircleBorder(),
            child: UserAvatar(size: avatar, imageUrl: avatarUrl),
          ),
        ),
        const SizedBox(width: Lx.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shrinks rather than truncating on narrow phones.
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child:
                    Text('Assalamu’alaikum,', maxLines: 1, style: Lx.greeting),
              ),
              // Long names wrap onto a second line instead of being cut.
              Text(
                username,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Lx.userName.copyWith(fontSize: 18),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: unseenNotices > 0
              ? 'Notifikasi, $unseenNotices belum dibaca'
              : 'Notifikasi',
          onPressed: onOpenNotifications,
          icon: Badge(
            isLabelVisible: unseenNotices > 0,
            label: Text('$unseenNotices'),
            child: const Icon(Icons.notifications_none_outlined,
                color: Lx.text, size: 26),
          ),
        ),
        IconButton(
          tooltip: 'Pengaturan',
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_outlined, color: Lx.text, size: 26),
        ),
      ],
    );
  }
}
