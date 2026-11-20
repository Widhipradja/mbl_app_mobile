import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';

/// The user's profile picture in a circle. Without a picture (none set, not a
/// web address, or it fails to load) it shows a person icon.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.size, this.imageUrl});

  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final loadable = url.startsWith('http://') || url.startsWith('https://');

    final placeholder = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Lx.skyBlue, Lx.primary],
        ),
      ),
      child: Icon(Icons.person_rounded, size: size * 0.58, color: Colors.white),
    );
    if (!loadable) return placeholder;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : placeholder,
        ),
      ),
    );
  }
}
