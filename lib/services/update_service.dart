import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Where new builds are published (`index.json` lists every app and build).
const updateHost = 'https://apk.sangkarahub.app';

/// A build published on the update host.
class AppRelease {
  const AppRelease({
    required this.versionName,
    required this.versionCode,
    required this.url,
    this.notes = '',
    this.size = 0,
    this.minVersionCode,
    this.publishedAt,
  });

  final String versionName;
  final int versionCode;

  /// Absolute address of the APK.
  final String url;
  final String notes;
  final int size;

  /// Installs older than this must update before going on.
  final int? minVersionCode;
  final DateTime? publishedAt;
}

enum UpdateState {
  /// A newer build is published.
  available,

  /// This is the newest build.
  upToDate,

  /// The host has no build of this app (its package is not published).
  notPublished,

  /// The host could not be read.
  failed,

  /// Not offered on this platform (updates by APK are Android only).
  unsupported,
}

class UpdateCheck {
  const UpdateCheck({
    required this.state,
    required this.installedName,
    required this.installedCode,
    required this.package,
    this.latest,
  });

  final UpdateState state;
  final String installedName, package;
  final int installedCode;
  final AppRelease? latest;

  bool get available => state == UpdateState.available;

  /// The installed build is below the host's `minVersionCode`.
  bool get mandatory {
    final min = latest?.minVersionCode;
    return available && min != null && installedCode < min;
  }
}

/// Reads the update host to see whether a newer build of this app exists.
///
/// The host's own address is the only one contacted, with a plain client:
/// the login token is never sent there. Updates are installed by the user
/// from the downloaded APK, so nothing is ever installed silently.
class UpdateService {
  UpdateService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ));

  final Dio _dio;

  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// What the installed app is: package, version name and code.
  static Future<PackageInfo> installed() => PackageInfo.fromPlatform();

  Future<UpdateCheck> check() async {
    final info = await installed();
    final code = int.tryParse(info.buildNumber) ?? 0;
    UpdateCheck result(UpdateState s, [AppRelease? latest]) => UpdateCheck(
          state: s,
          installedName: info.version,
          installedCode: code,
          package: info.packageName,
          latest: latest,
        );
    if (!supported) return result(UpdateState.unsupported);

    try {
      final resp = await _dio.get('$updateHost/index.json',
          options: Options(headers: {'Cache-Control': 'no-cache'}));
      final latest = parse(resp.data, info.packageName);
      if (latest == null) return result(UpdateState.notPublished);
      return result(
        latest.versionCode > code
            ? UpdateState.available
            : UpdateState.upToDate,
        latest,
      );
    } catch (e) {
      debugPrint('UpdateService check error: $e');
      return result(UpdateState.failed);
    }
  }

  /// The newest build of [package] in an `index.json` body, or null when the
  /// package is not listed or has no build.
  @visibleForTesting
  static AppRelease? parse(dynamic body, String package) {
    final apps = body is Map ? body['apps'] : null;
    if (apps is! List) return null;
    for (final app in apps.whereType<Map>()) {
      if (app['package']?.toString() != package) continue;
      final builds = app['versions'];
      if (builds is! List) return null;
      AppRelease? best;
      for (final v in builds.whereType<Map>()) {
        final code = int.tryParse('${v['versionCode']}');
        final file = (v['downloadUrl'] ?? v['file'])?.toString() ?? '';
        if (code == null || file.isEmpty) continue;
        if (best != null && code <= best.versionCode) continue;
        best = AppRelease(
          versionName: v['versionName']?.toString() ?? '$code',
          versionCode: code,
          url: Uri.parse('$updateHost/').resolve(file).toString(),
          notes: v['notes']?.toString().trim() ?? '',
          size: int.tryParse('${v['size']}') ?? 0,
          minVersionCode: int.tryParse('${v['minVersionCode']}'),
          publishedAt: DateTime.tryParse('${v['publishedAt']}'),
        );
      }
      return best;
    }
    return null;
  }
}
