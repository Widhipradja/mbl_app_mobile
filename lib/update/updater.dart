import 'package:package_info_plus/package_info_plus.dart';

import '../utils/constants.dart';
import 'apk_updater.dart';

Future<ApkUpdater>? _shared;

/// The app's one [ApkUpdater]: the installed package and build do not change
/// while it runs, so the prompt, the Tentang page and the Profil tab share it.
Future<ApkUpdater> appUpdater() => _shared ??= _build();

Future<ApkUpdater> _build() async {
  final info = await PackageInfo.fromPlatform();
  return ApkUpdater(
    baseUrl: AppConstants.updateHost,
    packageName: info.packageName,
    // The number written inside the APK; the publish script makes it match.
    currentVersionCode: int.tryParse(info.buildNumber) ?? 0,
  );
}
