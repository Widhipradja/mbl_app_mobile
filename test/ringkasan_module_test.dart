import 'package:baraka_funds/providers/home_summary_provider.dart';
import 'package:baraka_funds/screens/launcher/launcher_models.dart';
import 'package:flutter_test/flutter_test.dart';

Iterable<LauncherModule> _ringkasan(HomeSummaryProvider p) =>
    buildModules(p).where((m) => m.label == 'Ringkasan');

void main() {
  test('the tile shows when the server opens the dashboard module', () {
    final p = HomeSummaryProvider()..modules = {'dashboard': true};
    final tile = _ringkasan(p).single;
    expect(tile.route, '/ringkasan');
    expect(tile.push, isTrue);
  });

  test('the tile stays away when the module is closed', () {
    final p = HomeSummaryProvider()..modules = {'dashboard': false};
    expect(_ringkasan(p), isEmpty);
  });

  test('a server that does not know the module shows no tile', () {
    // Bootstrap answered, without "dashboard": an older server.
    final p = HomeSummaryProvider()..modules = {'budget': true};
    expect(_ringkasan(p), isEmpty);
  });

  test('before the bootstrap answers there is no tile either', () {
    final p = HomeSummaryProvider();
    expect(p.modules, isNull);
    expect(p.isModuleVisible('dashboard'), isFalse);
    expect(_ringkasan(p), isEmpty);
  });
}
