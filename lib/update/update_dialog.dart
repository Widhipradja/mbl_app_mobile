/// Ready-made "update available" dialog for [ApkUpdater].
///
/// Mandatory updates (manifest `minVersionCode`) cannot be dismissed.
library update_dialog;

import 'dart:io';

import 'package:flutter/material.dart';

import 'apk_updater.dart';

/// Checks once, then shows the dialog only when a newer build exists.
/// Safe to call from `main()` without awaiting.
Future<void> checkForUpdateAndPrompt(
  BuildContext context,
  ApkUpdater updater, {
  bool installImmediately = false,
}) async {
  final info = await updater.check();
  if (info == null || !context.mounted) return;
  if (installImmediately) {
    await updater.checkAndInstall();
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: !info.isMandatoryFor(updater.currentVersionCode),
    builder: (_) => UpdateDialog(updater: updater, info: info),
  );
}

class UpdateDialog extends StatefulWidget {
  final ApkUpdater updater;
  final UpdateInfo info;

  const UpdateDialog({super.key, required this.updater, required this.info});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double _progress = 0;
  String? _error;
  bool _busy = false;

  bool get _mandatory => widget.info.isMandatoryFor(widget.updater.currentVersionCode);

  String _human(int bytes) =>
      bytes >= 1 << 20 ? '${(bytes / (1 << 20)).toStringAsFixed(1)} MB'
                       : '${(bytes / 1024).round()} KB';

  Future<void> _update() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      final apk = await widget.updater.download(
        widget.info,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = (received / total).clamp(0.0, 1.0));
        },
      );
      final outcome = await widget.updater.install(apk);
      if (!mounted) return;
      switch (outcome) {
        case InstallOutcome.launched:
          // The installer activity is now on screen; the app gets stopped.
          break;
        case InstallOutcome.permissionDenied:
          setState(() => _error =
              'Izinkan "Instal aplikasi tidak dikenal" untuk app ini, lalu tekan Update lagi.');
          break;
        case InstallOutcome.unsupported:
          setState(() => _error = 'Update otomatis hanya tersedia di Android.');
          break;
        case InstallOutcome.failed:
          setState(() => _error = 'Jendela installer tidak bisa dibuka.');
          break;
      }
    } on StateError catch (e) {
      setState(() => _error = 'Unduhan rusak, coba lagi.\n$e');
    } on SocketException {
      setState(() => _error = 'Koneksi terputus saat mengunduh. Coba lagi.');
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final label = info.releaseName.isNotEmpty ? ' — ${info.releaseName}' : '';
    return AlertDialog(
      title: Text(_mandatory ? 'Update wajib$label' : 'Update tersedia$label'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Versi ${info.versionName} (${info.versionCode}) · ${_human(info.size)}'),
          if (info.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(info.notes, style: Theme.of(context).textTheme.bodySmall),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress == 0 ? null : _progress),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        if (!_mandatory && !_busy)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nanti'),
          ),
        FilledButton(
          onPressed: _busy ? null : _update,
          child: Text(_busy ? 'Memproses…' : 'Update sekarang'),
        ),
      ],
    );
  }
}
