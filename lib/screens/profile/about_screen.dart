import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/launcher_tokens.dart';
import '../../update/apk_updater.dart';
import '../../update/update_button.dart';
import '../../update/updater.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_ui.dart';

/// What the app is, which version is installed, and the update row: it checks
/// the update host and, when a newer build exists, downloads it, checks its
/// SHA-256 and opens Android's installer.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _features = [
    (Icons.account_balance_wallet_outlined, 'Dompet Saya',
        'Catat uang masuk dan keluar pribadi, atur anggaran bulanan'),
    (Icons.savings_outlined, 'Keuangan',
        'Kas organisasi: saldo, transaksi, persetujuan, dan pembukuan'),
    (Icons.event_note_outlined, 'Kegiatan',
        'Jadwal kegiatan dan materi, dikelola oleh pengurus'),
    (Icons.mosque_outlined, 'Tabungan Kurban',
        'Pantau tabungan kurban keluarga per bulan'),
    (Icons.menu_book_outlined, 'Amal Jariyah',
        'Buku amal bulanan dan setoran dengan bukti transfer'),
    (Icons.volunteer_activism_outlined, 'Zakat Fitrah',
        'Muzakki, mustahiq, dan laporan zakat'),
  ];

  Widget _hero() => Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: Lx.shadowSoft,
            ),
            child: const BarakaFundsAppIcon(size: 88),
          ),
          const SizedBox(height: Lx.s12),
          Text('Baraka', style: Lx.userName.copyWith(fontSize: 24)),
          const SizedBox(height: 2),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (_, snap) {
              final i = snap.data;
              return Text(
                i == null ? 'Memuat versi…' : 'Versi ${i.version} (${i.buildNumber})',
                style: Lx.metadata,
              );
            },
          ),
        ],
      );

  Widget _intro() => SectionCard(
        child: Text(
          'Baraka membantu jamaah dan pengurus mengelola keuangan, kegiatan, '
          'dan amal di satu aplikasi: dari catatan keuangan pribadi sampai '
          'kas organisasi, jadwal kegiatan, tabungan kurban, dan setoran amal '
          'jariyah. Modul yang tampil mengikuti hak akses akun Anda.',
          style: Lx.body.copyWith(color: Lx.text, height: 1.55),
        ),
      );

  // ── Update ───────────────────────────────────────────────────────────────

  /// The update row of the update host's kit, in a card.
  Widget _update() => SectionCard(
        child: FutureBuilder<ApkUpdater>(
          future: appUpdater(),
          builder: (_, snap) => snap.hasData
              ? UpdateButton(updater: snap.data!)
              : const Row(
                  children: [
                    SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: Lx.s12),
                    Text('Memeriksa pembaruan…', style: Lx.body),
                  ],
                ),
        ),
      );

  // ── Features ─────────────────────────────────────────────────────────────

  Widget _featureList() => SectionCard(
        title: 'Yang bisa dilakukan',
        padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s16, Lx.s16, Lx.s8),
        child: Column(
          children: [
            for (final (icon, name, body) in _features)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Lx.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CategoryAvatar(name, size: 36),
                    const SizedBox(width: Lx.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: Lx.cardHeading.copyWith(fontSize: 14)),
                          Text(body, style: Lx.metadata),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Lx.theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Tentang Aplikasi')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(Lx.s16, Lx.s8, Lx.s16, Lx.s24),
          children: [
            _hero(),
            const SizedBox(height: Lx.s20),
            _update(),
            _intro(),
            _featureList(),
          ],
        ),
      ),
    );
  }
}
