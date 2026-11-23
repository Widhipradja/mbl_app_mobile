/// In-app "Update" row for [ApkUpdater] — put it on the profile / about screen.
///
/// Shows the installed build, checks `<package>/latest.json`, and when a newer
/// build exists turns itself into a button that downloads the APK, verifies its
/// SHA-256 and opens Android's installer. No browser, no manual download, no
/// credentials.
library update_button;

import 'dart:io';

import 'package:flutter/material.dart';

import 'apk_updater.dart';

class UpdateButton extends StatefulWidget {
  const UpdateButton({
    super.key,
    required this.updater,
    this.title = 'Versi aplikasi',
    this.autocheck = true,
    this.showNotes = true,
  });

  final ApkUpdater updater;
  final String title;

  /// Check once when the widget first builds. Set false for a purely manual
  /// row (the user taps "Cek update").
  final bool autocheck;

  /// Show the manifest `notes` of the pending build under the row.
  final bool showNotes;

  @override
  State<UpdateButton> createState() => _UpdateButtonState();
}

enum _Phase { idle, checking, latest, available, downloading, error }

class _UpdateButtonState extends State<UpdateButton> {
  _Phase _phase = _Phase.idle;
  UpdateInfo? _info;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autocheck) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  bool get _busy => _phase == _Phase.checking || _phase == _Phase.downloading;

  String _human(int bytes) => bytes >= 1 << 20
      ? '${(bytes / (1 << 20)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).round()} KB';

  /// "Cappucino 1.6.0 (46)" — release name only when the publisher set one.
  String _label(UpdateInfo i) {
    final name = i.releaseName.isNotEmpty ? '${i.releaseName} ' : '';
    return '$name${i.versionName} (${i.versionCode})';
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() {
      _phase = _Phase.checking;
      _error = null;
    });
    final info = await widget.updater.check(); // never throws
    if (!mounted) return;
    setState(() {
      _info = info;
      _phase = info == null ? _Phase.latest : _Phase.available;
    });
  }

  Future<void> _install() async {
    final info = _info;
    if (info != null && info.versionCode <= widget.updater.currentVersionCode) {
      await _check();
      return;
    }
    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
      _error = null;
    });
    try {
      final apk = await widget.updater.download(
        info!,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = (received / total).clamp(0.0, 1.0));
        },
      );
      final outcome = await widget.updater.install(apk);
      if (!mounted) return;
      if (outcome == InstallOutcome.launched) {
        // The installer activity is on screen now; Android stops this app.
        setState(() => _phase = _Phase.available);
      } else if (outcome == InstallOutcome.permissionDenied) {
        setState(() {
          _phase = _Phase.error;
          _error = 'Izinkan "Instal aplikasi tidak dikenal" untuk app ini, '
              'lalu tekan Update lagi.';
        });
      } else if (outcome == InstallOutcome.unsupported) {
        setState(() {
          _phase = _Phase.error;
          _error = 'Update otomatis hanya tersedia di Android.';
        });
      } else {
        setState(() {
          _phase = _Phase.error;
          _error = 'Jendela installer tidak bisa dibuka.';
        });
      }
    } on StateError {
      setState(() {
        _phase = _Phase.error;
        _error = 'Unduhan rusak (SHA-256 tidak cocok). Coba lagi.';
      });
    } on SocketException {
      setState(() {
        _phase = _Phase.error;
        _error = 'Koneksi terputus saat mengunduh. Coba lagi.';
      });
    } catch (e) {
      setState(() {
        _phase = _Phase.error;
        _error = '$e';
      });
    }
  }

  String get _subtitle {
    final installed = 'Terpasang: ${widget.updater.currentVersionCode}';
    switch (_phase) {
      case _Phase.idle:
      case _Phase.checking:
        return '$installed · memeriksa…';
      case _Phase.latest:
        return '$installed · sudah versi terbaru';
      case _Phase.available:
        final i = _info;
        return i == null
            ? installed
            : 'Tersedia: ${_label(i)} · ${_human(i.size)}';
      case _Phase.downloading:
        return 'Mengunduh… ${(_progress * 100).round()}%';
      case _Phase.error:
        return _error ?? 'Gagal memeriksa update';
    }
  }

  Widget? get _trailing {
    if (_phase == _Phase.checking || _phase == _Phase.downloading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_phase == _Phase.available) {
      return FilledButton(
        onPressed: _install,
        child: const Text('Update'),
      );
    }
    return TextButton(
      onPressed: _check,
      child: const Text('Cek update'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = widget.showNotes ? _info?.notes ?? '' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(widget.title),
          subtitle: Text(
            _subtitle,
            style: _phase == _Phase.error
                ? TextStyle(color: theme.colorScheme.error)
                : null,
          ),
          trailing: _trailing,
        ),
        if (_phase == _Phase.downloading)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(
              value: _progress == 0 ? null : _progress,
            ),
          ),
        if (notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(notes, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}
