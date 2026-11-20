import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../config/launcher_tokens.dart';

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
