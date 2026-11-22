import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/launcher_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../utils/avatar_image.dart';
import '../launcher/user_avatar.dart';

/// Text for a failed profile / password call. The server's Indonesian `error`
/// is shown as it is for 403, 409, 422 and 429, and for the one 502 that asks
/// to save again; everything else gets a fixed message. Only 401 (handled by
/// the app's global handler) means the session is over.
String profileFailure(Object e, {String fallback = 'Gagal menyimpan.'}) {
  if (e is DioException) {
    final data = e.response?.data;
    final reason = data is Map ? data['error']?.toString().trim() ?? '' : '';
    switch (e.response?.statusCode) {
      case 403:
      case 409:
      case 422:
      case 429:
        if (reason.isNotEmpty) return reason;
        return 'Data ditolak server. Periksa isian Anda.';
      case 400:
        return 'Permintaan tidak valid. Periksa isian Anda.';
      case 404:
        return 'Akun tidak ditemukan.';
      case 502:
        if (reason.endsWith('Simpan ulang.')) return reason;
        return 'Layanan sedang tidak tersedia. Coba lagi nanti.';
      case 503:
      case 504:
        return 'Layanan sedang tidak tersedia. Coba lagi nanti.';
    }
    if (e.response == null) {
      return 'Tidak bisa terhubung ke server. Periksa koneksi Anda.';
    }
  }
  return fallback;
}

InputDecoration profileDecoration(String label, {Widget? suffix}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Lx.rButton),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    suffixIcon: suffix,
    filled: true,
    fillColor: Lx.surface,
    border: border(Lx.border),
    enabledBorder: border(Lx.border),
    focusedBorder: border(Lx.primary, 2),
  );
}

class ProfileErrorBox extends StatelessWidget {
  const ProfileErrorBox(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: Lx.s12),
        padding: const EdgeInsets.all(Lx.s12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3F2),
          borderRadius: BorderRadius.circular(Lx.rButton),
        ),
        child: Text(text, style: Lx.metadata.copyWith(color: Lx.danger)),
      );
}


/// A failed photo call: the server's own text for the photo rules (400, 413,
/// 415) and for the account (409, 422).
String avatarFailure(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    final reason = data is Map ? data['error']?.toString().trim() ?? '' : '';
    switch (e.response?.statusCode) {
      case 400:
      case 413:
      case 415:
        if (reason.isNotEmpty) return reason;
    }
  }
  return profileFailure(e, fallback: 'Foto gagal diperbarui. Coba lagi.');
}

/// The profile picture with a camera badge: tap to pick a new one from the
/// device or remove the current one. The photo is shrunk, then saved at once
/// and apart from the rest of the form ([onBusyChanged] lets the form keep
/// the two requests from running together).
class ProfilePhotoEditor extends StatefulWidget {
  const ProfilePhotoEditor({
    super.key,
    this.size = 96,
    this.enabled = true,
    this.onBusyChanged,
  });

  final double size;
  final bool enabled;
  final ValueChanged<bool>? onBusyChanged;

  /// A picture is shrunk before upload, so the original may be big; this only
  /// stops absurd files.
  static const maxOriginalBytes = 25 * 1024 * 1024;

  @override
  State<ProfilePhotoEditor> createState() => _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends State<ProfilePhotoEditor> {
  bool _busy = false;

  void _setBusy(bool v) {
    setState(() => _busy = v);
    widget.onBusyChanged?.call(v);
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _menu() async {
    final hasPhoto =
        (context.read<AuthProvider>().user?.avatar ?? '').trim().isNotEmpty;
    final pick = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih foto'),
              subtitle: const Text('JPG, PNG atau WebP'),
              onTap: () => Navigator.pop(ctx, 'pick'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Lx.danger),
                title: const Text('Hapus foto',
                    style: TextStyle(color: Lx.danger)),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || pick == null) return;
    if (pick == 'remove') {
      await _run(() => context.read<AuthProvider>().removeAvatar(),
          done: 'Foto profil dihapus.');
    } else {
      await _pick();
    }
  }

  Future<void> _pick() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = picked?.files.single;
      if (file == null || !mounted) return;
      final bytes = file.bytes;
      if (bytes == null) return _say('Foto tidak bisa dibuka. Coba lagi.');
      if (bytes.length > ProfilePhotoEditor.maxOriginalBytes) {
        return _say('Foto terlalu besar. Pilih foto yang lebih kecil.');
      }
      final auth = context.read<AuthProvider>();
      await _run(() async {
        final small = await prepareAvatar(bytes);
        if (small == null) {
          throw const FormatException('Pilih foto JPG, PNG atau WebP.');
        }
        await auth.setAvatar(small, 'avatar.jpg');
      }, done: 'Foto profil diperbarui.');
    } catch (e) {
      debugPrint('ProfilePhotoEditor pick error: $e');
      if (mounted) _say('Foto tidak bisa dibuka. Coba lagi.');
    }
  }

  Future<void> _run(Future<void> Function() action,
      {required String done}) async {
    _setBusy(true);
    try {
      await action();
      if (mounted) _say(done);
    } catch (e) {
      debugPrint('ProfilePhotoEditor error: $e');
      if (mounted) {
        _say(e is FormatException ? e.message : avatarFailure(e));
      }
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = context.select<AuthProvider, String?>((a) => a.user?.avatar);
    final active = widget.enabled && !_busy;
    return Center(
      child: Semantics(
        button: true,
        label: 'Ubah foto profil',
        child: GestureDetector(
          onTap: active ? _menu : null,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                    key: ValueKey(url), size: widget.size, imageUrl: url),
                if (_busy)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Color(0x66000000)),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                if (widget.enabled)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Lx.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.photo_camera_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
