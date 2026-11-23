import 'package:baraka_funds/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final index = {
    'apps': [
      {
        'package': 'com.baraka.app',
        'versions': [
          {
            'versionCode': 43,
            'versionName': 'mowning',
            'downloadUrl': 'apk/com.baraka.app/mowning_43.apk',
            'size': 64011327,
            'notes': '',
            'minVersionCode': null,
          },
          {
            'versionCode': 44,
            'versionName': 'Cappucino',
            'downloadUrl': 'apk/com.baraka.app/Cappucino_44.apk',
            'size': 63930535,
            'notes': ' Dompet Saya baru ',
            'minVersionCode': 40,
          },
          {'versionCode': 45, 'versionName': 'broken'}, // no file: skipped
        ],
      },
      {'package': 'other.app', 'versions': []},
    ],
  };

  test('picks the newest build with a file, as an absolute address', () {
    final r = UpdateService.parse(index, 'com.baraka.app')!;
    expect(r.versionCode, 44);
    expect(r.versionName, 'Cappucino');
    expect(r.url, 'https://apk.sangkarahub.app/apk/com.baraka.app/Cappucino_44.apk');
    expect(r.notes, 'Dompet Saya baru');
    expect(r.minVersionCode, 40);
    expect(r.size, 63930535);
  });

  test('is null for a package that is not published', () {
    expect(UpdateService.parse(index, 'com.desalabs.baraka_funds'), isNull);
    expect(UpdateService.parse(index, 'other.app'), isNull);
  });

  test('is null for a body that is not a manifest', () {
    expect(UpdateService.parse('oops', 'com.baraka.app'), isNull);
    expect(UpdateService.parse({'apps': 3}, 'com.baraka.app'), isNull);
  });

  test('a build below minVersionCode must update', () {
    final latest = UpdateService.parse(index, 'com.baraka.app')!;
    UpdateCheck at(int code) => UpdateCheck(
        state: UpdateState.available,
        installedName: 'x',
        installedCode: code,
        package: 'com.baraka.app',
        latest: latest);
    expect(at(39).mandatory, isTrue);
    expect(at(40).mandatory, isFalse);
  });
}
