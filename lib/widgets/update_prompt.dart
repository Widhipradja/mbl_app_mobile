import 'package:flutter/material.dart';

import '../update/update_dialog.dart';
import '../update/updater.dart';

bool _promptedThisSession = false;

/// Once per app session, after login: asks the update host whether a newer
/// build of this app exists and, if so, shows the dialog (Nanti or Update
/// sekarang; a build below the host's `minVersionCode` can only update).
/// Called from the dashboard rather than `main()`: that is after sign-in, and
/// by then the router has a context to show the dialog on. Quiet when there
/// is nothing to offer, the host is unreachable, or the platform is not
/// Android.
Future<void> promptForUpdate(BuildContext context) async {
  if (_promptedThisSession) return;
  _promptedThisSession = true;
  final updater = await appUpdater();
  if (!context.mounted) return;
  await checkForUpdateAndPrompt(context, updater);
}
