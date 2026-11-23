import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/launcher_tokens.dart';
import '../../services/update_service.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_ui.dart';

/// What the app is, which version is installed, and whether a newer build is
/// published, with the link to download it.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, this.service});

  /// Tests pass their own; the app uses the real update host.
  final UpdateService? service;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final UpdateService _service = widget.service ?? UpdateService();
  UpdateCheck? _check;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _checking = true);
    final result = await _service.check();
    if (!mounted) return;
    setState(() {
      _check = result;
      _checking = false;
    });
  }

  Future<void> _download(AppRelease r) async {
    final ok = await launchUrl(Uri.parse(r.url),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa membuka tautan unduhan.')));
    }
  }

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
          Text(
            _check == null
                ? 'Memuat versi…'
                : 'Versi ${_check!.installedName} (${_check!.installedCode})',
            style: Lx.metadata,
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

  Widget _update() {
    final c = _check;
    if (_checking || c == null) {
      return const SectionCard(
        child: Row(
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: Lx.s12),
            Expanded(child: Text('Memeriksa pembaruan…', style: Lx.body)),
          ],
        ),
      );
    }
    switch (c.state) {
      case UpdateState.available:
        return _available(c);
      case UpdateState.upToDate:
        return _status(Icons.check_circle_rounded, Lx.success,
            'Aplikasi sudah terbaru',
            'Versi ${c.installedName} adalah yang terbaru.');
      case UpdateState.notPublished:
        return _status(Icons.info_outline_rounded, Lx.textSecondary,
            'Info pembaruan belum tersedia',
            'Aplikasi ini belum diterbitkan di server pembaruan.');
      case UpdateState.failed:
        return _status(Icons.cloud_off_rounded, Lx.danger,
            'Tidak bisa memeriksa pembaruan',
            'Periksa koneksi Anda, lalu coba lagi.',
            retry: true);
      case UpdateState.unsupported:
        return _status(Icons.phone_iphone_rounded, Lx.textSecondary,
            'Pembaruan lewat APK hanya untuk Android',
            'Di perangkat ini, perbarui lewat toko aplikasi.');
    }
  }

  Widget _status(IconData icon, Color color, String title, String body,
      {bool retry = false}) {
    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: Lx.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Lx.cardHeading.copyWith(fontSize: 14)),
                Text(body, style: Lx.metadata),
              ],
            ),
          ),
          if (retry)
            TextButton(onPressed: _run, child: const Text('Coba lagi'))
          else
            IconButton(
              tooltip: 'Periksa lagi',
              onPressed: _run,
              icon: const Icon(Icons.refresh_rounded, color: Lx.textSecondary),
            ),
        ],
      ),
    );
  }

  String _size(int bytes) => bytes <= 0
      ? ''
      : bytes >= 1048576
          ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
          : '${(bytes / 1024).round()} KB';

  Widget _available(UpdateCheck c) {
    final r = c.latest!;
    final size = _size(r.size);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Lx.s12),
      padding: const EdgeInsets.all(Lx.s16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(Lx.rCard),
        border: Border.all(color: Lx.launcherBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: Lx.primary, shape: BoxShape.circle),
                child: const Icon(Icons.system_update_alt_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: Lx.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        c.mandatory
                            ? 'Pembaruan wajib tersedia'
                            : 'Versi baru tersedia',
                        style: Lx.cardHeading),
                    Text(
                        '${r.versionName} (${r.versionCode})'
                        '${size.isEmpty ? '' : ' · $size'}',
                        style: Lx.metadata),
                  ],
                ),
              ),
            ],
          ),
          if (r.notes.isNotEmpty) ...[
            const SizedBox(height: Lx.s12),
            Text('Yang baru', style: Lx.metadata.copyWith(color: Lx.text)),
            const SizedBox(height: 2),
            Text(r.notes, style: Lx.body.copyWith(color: Lx.text)),
          ],
          const SizedBox(height: Lx.s16),
          FilledButton.icon(
            onPressed: () => _download(r),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Unduh pembaruan'),
          ),
          const SizedBox(height: Lx.s8),
          Text(
              'Setelah unduhan selesai, buka file APK dan ketuk Install. '
              'Data Anda tetap aman.',
              textAlign: TextAlign.center,
              style: Lx.metadata),
        ],
      ),
    );
  }

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
        body: RefreshIndicator(
          onRefresh: _run,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }
}
