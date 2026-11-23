import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/launcher_tokens.dart';
import '../services/update_service.dart';

bool _promptedThisSession = false;

/// Checks the update host once per app session and, when a newer build is
/// published, asks the user whether to download it. A build below the host's
/// `minVersionCode` can only be updated, not postponed. Quiet when there is
/// nothing to offer or the host cannot be reached.
Future<void> promptForUpdate(BuildContext context, {UpdateService? service}) async {
  if (_promptedThisSession || !UpdateService.supported) return;
  _promptedThisSession = true;

  final check = await (service ?? UpdateService()).check();
  if (!check.available || !context.mounted) return;
  final release = check.latest!;
  final mandatory = check.mandatory;

  await showDialog<void>(
    context: context,
    barrierDismissible: !mandatory,
    builder: (ctx) => PopScope(
      canPop: !mandatory,
      child: AlertDialog(
        icon: const Icon(Icons.system_update_alt_rounded,
            color: Lx.primary, size: 32),
        title: Text(mandatory ? 'Pembaruan wajib' : 'Versi baru tersedia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${check.installedName} → ${release.versionName}',
                style: Lx.cardHeading),
            if (release.notes.isNotEmpty) ...[
              const SizedBox(height: Lx.s8),
              Text(release.notes, style: Lx.body),
            ],
            const SizedBox(height: Lx.s8),
            Text(
                mandatory
                    ? 'Versi ini sudah tidak didukung. Perbarui untuk '
                        'melanjutkan.'
                    : 'Setelah diunduh, buka file APK dan ketuk Install.',
                style: Lx.metadata),
          ],
        ),
        actions: [
          if (!mandatory)
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Nanti')),
          FilledButton(
            onPressed: () async {
              await launchUrl(Uri.parse(release.url),
                  mode: LaunchMode.externalApplication);
              if (!mandatory && ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Unduh'),
          ),
        ],
      ),
    ),
  );
}
