import 'package:baraka_funds/update/apk_updater.dart';
import 'package:flutter_test/flutter_test.dart';

/// `https://apk.sangkarahub.app/com.baraka.app/latest.json` as the host
/// serves it (the kit's ApkUpdater reads this file).
const _latest = <String, dynamic>{
  'versionCode': 45,
  'versionName': '1.5.0',
  'releaseName': 'Cappucino',
  'minSdk': null,
  'minVersionCode': null,
  'notes': '',
  'size': 64128315,
  'sha256':
      '914DCF01239DF73D0EDC4CF2F289A22CD90BB490EA00C95B8CA6C9C06DF86F86',
  'file': 'apk/com.baraka.app/1.5.0_45.apk',
  'downloadUrl': 'apk/com.baraka.app/1.5.0_45.apk',
  'package': 'com.baraka.app',
};

void main() {
  final base = Uri.parse('https://apk.sangkarahub.app/');

  test('reads the host manifest: absolute address, file name, lower-case hash',
      () {
    final i = UpdateInfo.fromJson(_latest, base);
    expect(i.packageName, 'com.baraka.app');
    expect(i.versionCode, 45);
    expect(i.versionName, '1.5.0');
    expect(i.releaseName, 'Cappucino');
    expect(i.size, 64128315);
    expect(i.uri.toString(),
        'https://apk.sangkarahub.app/apk/com.baraka.app/1.5.0_45.apk');
    expect(i.fileName, '1.5.0_45.apk');
    expect(i.sha256, _latest['sha256'].toString().toLowerCase());
  });

  test('falls back to downloadUrl when file is missing', () {
    final i = UpdateInfo.fromJson({..._latest, 'file': null}, base);
    expect(i.fileName, '1.5.0_45.apk');
  });

  test('a manifest without a file is refused', () {
    expect(
        () => UpdateInfo.fromJson(
            {..._latest, 'file': null, 'downloadUrl': null}, base),
        throwsFormatException);
  });

  test('an update is mandatory only below minVersionCode', () {
    final plain = UpdateInfo.fromJson(_latest, base);
    expect(plain.isMandatoryFor(1), isFalse);

    final forced = UpdateInfo.fromJson({..._latest, 'minVersionCode': 40}, base);
    expect(forced.isMandatoryFor(39), isTrue);
    expect(forced.isMandatoryFor(40), isFalse);
  });
}
