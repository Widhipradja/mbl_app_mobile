import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';
import '../../services/config_service.dart';
import '../../services/storage_service.dart';

/// The user's profile picture in a circle. Without a picture (none set, not a
/// web address, or it fails to load) it shows a person icon.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.size, this.imageUrl});

  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    var url = imageUrl?.trim() ?? '';
    // The server answers a path on its own host; the picture needs the
    // login token, so it is never fetched without it.
    final base = ConfigService.apiBaseUrl;
    if (url.startsWith('/')) url = '$base$url';
    final loadable = url.startsWith('http://') || url.startsWith('https://');
    final token = StorageService.getToken();
    // The token goes to our own API only, never to another host.
    final headers = token != null && url.startsWith(base)
        ? {'Authorization': 'Bearer $token'}
        : null;

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
          headers: headers,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : placeholder,
        ),
      ),
    );
  }
}
