/// In-app APK updater for apps distributed by `apk-host`.
///
/// Flow: read `<baseUrl>/<packageName>/latest.json` → compare `versionCode`
/// with the installed build → download the APK to the cache dir → verify its
/// SHA-256 → hand it to Android's package installer.
///
/// Deliberately Android-only. iOS cannot sideload apps, so on iOS this class
/// returns null from [ApkUpdater.check] and never shows UI.
library apk_updater;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// One published build, as described by `<package>/latest.json`.
class UpdateInfo {
  final String packageName;
  final String versionName;

  /// Human label set at publish time (`releaseName`); `''` when the build has none.
  final String releaseName;
  final int versionCode;
  final int size;
  final String sha256;
  final String notes;
  final int? minSdk;

  /// If the installed versionCode is below this, the update is mandatory.
  final int? minVersionCode;

  /// Absolute URL of the APK (base URL already applied).
  final Uri uri;

  /// File name to download to, e.g. `1.2.1_13.apk`.
  final String fileName;

  const UpdateInfo({
    required this.packageName,
    required this.versionName,
    this.releaseName = '',
    required this.versionCode,
    required this.size,
    required this.sha256,
    required this.notes,
    required this.uri,
    required this.fileName,
    this.minSdk,
    this.minVersionCode,
  });

  /// [base] must carry the same prefix the manifest is served under
  /// (e.g. `https://apk.example.com/` or `https://example.com/apks/`), because
  /// `file` in the manifest is relative.
  factory UpdateInfo.fromJson(Map<String, dynamic> json, Uri base) {
    final rel = (json['file'] as String? ?? json['downloadUrl'] as String? ?? '').trim();
    if (rel.isEmpty) {
      throw const FormatException('manifest entry has no "file" field');
    }
    return UpdateInfo(
      packageName: json['package'] as String? ?? '',
      versionName: json['versionName'] as String? ?? '',
      releaseName: (json['releaseName'] as String? ?? '').trim(),
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
      sha256: (json['sha256'] as String? ?? '').toLowerCase(),
      notes: json['notes'] as String? ?? '',
      minSdk: (json['minSdk'] as num?)?.toInt(),
      minVersionCode: (json['minVersionCode'] as num?)?.toInt(),
      uri: base.resolve(rel),
      fileName: rel.split('/').last,
    );
  }

  bool isMandatoryFor(int installedVersionCode) =>
      minVersionCode != null && installedVersionCode < minVersionCode!;

  @override
  String toString() => 'UpdateInfo($packageName $versionName/$versionCode)';
}

enum InstallOutcome { launched, permissionDenied, unsupported, failed }

class ApkUpdater {
  /// Host root, with the prefix the manifest lives under. Trailing slash optional.
  final String baseUrl;

  /// Application id, e.g. `app.widhipradja.generus` — must match the published folder.
  final String packageName;

  /// Installed versionCode (`int.parse(PackageInfo.buildNumber)` on Android).
  final int currentVersionCode;

  final http.Client _client;

  ApkUpdater({
    required this.baseUrl,
    required this.packageName,
    required this.currentVersionCode,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri get _base => Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');

  /// Returns the pending update, or null when up to date / not Android / offline.
  ///
  /// Never throws: a broken network or a bad manifest must not keep the app
  /// from starting. Callers get null and carry on.
  Future<UpdateInfo?> check({Duration timeout = const Duration(seconds: 8)}) async {
    if (!Platform.isAndroid) return null;
    try {
      final uri = _base.resolve(Uri.encodeComponent(packageName) + '/latest.json');
      final res = await _client
          .get(uri, headers: const {'Cache-Control': 'no-cache'})
          .timeout(timeout);
      if (res.statusCode != 200) return null;
      final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final info = UpdateInfo.fromJson(map, _base);
      if (info.versionCode <= currentVersionCode) return null;
      if (info.minSdk != null && _sdkIntOrNull() != null && _sdkIntOrNull()! < info.minSdk!) {
        return null; // build would not install on this device
      }
      return info;
    } catch (_) {
      return null;
    }
  }

  /// Downloads to the cache dir, resuming nothing but reusing an already
  /// verified file. Throws [StateError] if the SHA-256 does not match.
  Future<File> download(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final target = File('${dir.path}/${info.fileName}');

    if (await target.exists() && await _sha256Of(target) == info.sha256) {
      onProgress?.call(info.size, info.size);
      return target; // already downloaded on a previous attempt
    }

    final part = File('${target.path}.part');
    if (await part.exists()) await part.delete();

    final res = await _client.send(http.Request('GET', info.uri));
    if (res.statusCode != 200) {
      throw HttpException('download failed: HTTP ${res.statusCode}', uri: info.uri);
    }

    final total = res.contentLength ?? info.size;
    var received = 0;
    final sink = part.openWrite();
    try {
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    final digest = await _sha256Of(part);
    if (info.sha256.isNotEmpty && digest != info.sha256) {
      await part.delete();
      throw StateError('sha256 mismatch: got $digest, expected ${info.sha256}');
    }
    if (await target.exists()) await target.delete();
    return part.rename(target.path);
  }

  /// Fires Android's installer. The user still confirms the install; nothing is
  /// silent. Needs `REQUEST_INSTALL_PACKAGES` in the manifest.
  Future<InstallOutcome> install(File apk) async {
    if (!Platform.isAndroid) return InstallOutcome.unsupported;

    final perm = Permission.requestInstallPackages;
    if (!await perm.isGranted) {
      final status = await perm.request();
      if (!status.isGranted) return InstallOutcome.permissionDenied;
    }

    final res = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    return res.type == ResultType.done ? InstallOutcome.launched : InstallOutcome.failed;
  }

  /// check → download → install, with progress callbacks. Returns null if there
  /// was nothing to do. Used by the startup check.
  Future<UpdateInfo?> checkAndInstall({
    void Function(UpdateInfo info)? onFound,
    void Function(int received, int total)? onProgress,
  }) async {
    final info = await check();
    if (info == null) return null;
    onFound?.call(info);
    final apk = await download(info, onProgress: onProgress);
    await install(apk);
    return info;
  }

  void dispose() => _client.close();

  static Future<String> _sha256Of(File f) async {
    final digest = await sha256.bind(f.openRead()).first;
    return digest.toString();
  }

  /// `Build.VERSION.SDK_INT` without a plugin. Reading `ro.build.version.sdk`
  /// through the shell is cheap and only used to skip un-installable builds.
  static int? _sdkIntOrNull() {
    try {
      final out = Process.runSync('getprop', const ['ro.build.version.sdk']);
      return int.tryParse((out.stdout as String).trim());
    } catch (_) {
      return null;
    }
  }
}
