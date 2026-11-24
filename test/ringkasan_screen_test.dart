import 'dart:async';

import 'package:baraka_funds/screens/ringkasan/ringkasan_data.dart';
import 'package:baraka_funds/screens/ringkasan/ringkasan_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ringkasan_fixture.dart';

Future<void> _open(
  WidgetTester tester,
  Future<RingkasanData> Function(String month) loader, {
  Size size = const Size(390, 2600),
  Map<String, bool> modules = _allOpen,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      MaterialApp(home: RingkasanScreen(loader: loader, modules: modules)));
  await tester.pumpAndSettle();
}

const _allOpen = {
  'dashboard': true,
  'dashboard_finance': true,
  'dashboard_shodaqoh': true,
  'jimpitan': true,
};

/// Opens a tab by its label.
Future<void> _goTo(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(Tab, label);
  await tester.ensureVisible(tab); // the bar scrolls on a narrow phone
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

/// [_goTo] while a spinner runs, so it cannot wait for things to settle.
Future<void> _goToLoading(WidgetTester tester, String label) async {
  final tab = find.widgetWithText(Tab, label);
  await tester.ensureVisible(tab);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(tab);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<RingkasanData> _ok(String month, [Map<String, dynamic>? parts]) async =>
    RingkasanData.parse(ringkasanAnswer(
      finance: parts?['finance'],
      members: parts?['members'],
      shodaqoh: parts?['shodaqoh'],
      jimpitan: parts?['jimpitan'],
    ));

void main() {
  testWidgets('shows the four tabs, each with its numbers', (tester) async {
    await _open(tester, _ok);

    expect(tester.takeException(), isNull);
    for (final t in ['Keuangan', 'Shodaqoh', 'Keanggotaan', 'Jimpitan']) {
      expect(find.widgetWithText(Tab, t), findsOneWidget);
    }
    expect(find.text('Saldo Kas'), findsOneWidget);
    expect(find.text('Rp 22.863.820'), findsOneWidget);
    expect(find.text('Dana per kategori'), findsOneWidget);

    await _goTo(tester, 'Shodaqoh');
    expect(find.text('Shodaqoh Bulanan'), findsOneWidget);
    expect(find.text('45 dari 120 anggota'), findsOneWidget);

    await _goTo(tester, 'Keanggotaan');
    expect(find.text('120'), findsOneWidget); // all members

    await _goTo(tester, 'Jimpitan');
    expect(find.text('Rp 1.250.000'), findsOneWidget);
  });

  testWidgets('each tab follows its server module', (tester) async {
    expect(ringkasanTabsFor((m) => true), RingkasanTab.values);
    expect(ringkasanTabsFor((m) => m == 'jimpitan'),
        [RingkasanTab.keanggotaan, RingkasanTab.jimpitan]);
    expect(ringkasanTabsFor((m) => true, closed: {RingkasanTab.keuangan}),
        isNot(contains(RingkasanTab.keuangan)));

    // dashboard_finance closed (the default until a tenant sets it).
    await _open(tester, _ok,
        modules: {..._allOpen, 'dashboard_finance': false});
    expect(find.widgetWithText(Tab, 'Keuangan'), findsNothing);
    expect(find.widgetWithText(Tab, 'Shodaqoh'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Keanggotaan'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Jimpitan'), findsOneWidget);
  });

  testWidgets('a tab the server refuses in the answer disappears',
      (tester) async {
    await _open(
        tester,
        (m) => _ok(m, {
              'finance': {'error': 'forbidden'}
            }));
    expect(find.widgetWithText(Tab, 'Keuangan'), findsNothing);
    expect(find.widgetWithText(Tab, 'Shodaqoh'), findsOneWidget);
    expect(find.text('45 dari 120 anggota'), findsOneWidget); // first tab now
  });

  testWidgets('modules closed leave only the tabs without one', (tester) async {
    await _open(tester, _ok, modules: const {'dashboard': true});
    // Keanggotaan has no module of its own, so it stays.
    expect(find.widgetWithText(Tab, 'Keanggotaan'), findsOneWidget);
    expect(find.byType(Tab), findsOneWidget);
  });

  testWidgets('Saldo Kas says its income and expense are of this month',
      (tester) async {
    await _open(tester, _ok);
    expect(find.text('Bulan ini'), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
  });

  testWidgets('a closed finance gate leaves the card out, quietly',
      (tester) async {
    await _open(
        tester,
        (m) => _ok(m, {
              'finance': {'error': 'forbidden'}
            }));
    expect(find.text('Saldo Kas'), findsNothing);
    expect(find.text('Dana per kategori'), findsNothing);
    expect(find.textContaining('Tidak tersedia'), findsNothing);
    await _goTo(tester, 'Keanggotaan');
    expect(find.text('120'), findsOneWidget);
  });

  testWidgets('funds hidden for a role that may not see them, Saldo Kas stays',
      (tester) async {
    await _open(
        tester,
        (m) => _ok(m, {
              'finance': {
                'data': {
                  'balance': '100',
                  'income': '0',
                  'expense': '0',
                  'as_of': '2026-11-01',
                  'recent_transactions': [],
                  'funds': null,
                  'funds_error': 'forbidden',
                },
              },
            }));
    expect(find.text('Saldo Kas'), findsOneWidget);
    expect(find.text('Rp 100'), findsOneWidget);
    expect(find.text('Dana per kategori'), findsNothing);
  });

  testWidgets('funds that fail otherwise get a short note', (tester) async {
    await _open(
        tester,
        (m) => _ok(m, {
              'finance': {
                'data': {
                  'balance': '100',
                  'income': '0',
                  'expense': '0',
                  'as_of': '2026-11-01',
                  'recent_transactions': [],
                  'funds': null,
                  'funds_error': 'unavailable',
                },
              },
            }));
    expect(find.text('Rp 100'), findsOneWidget);
    expect(find.textContaining('Dana per kategori belum bisa dimuat'),
        findsOneWidget);
  });

  testWidgets('shows the funds with the balance of each', (tester) async {
    await _open(tester, _ok);
    expect(find.text('Dana per kategori'), findsOneWidget);
    expect(find.text('Operasional'), findsOneWidget);
    expect(find.text('Rp 500'), findsOneWidget);
  });

  testWidgets('one section failing leaves the others', (tester) async {
    await _open(
        tester,
        (m) => _ok(m, {
              'members': {'error': 'not_configured'}
            }));
    expect(find.text('Rp 22.863.820'), findsOneWidget);
    await _goTo(tester, 'Keanggotaan');
    expect(find.text('Data ini belum diatur di server.'), findsOneWidget);
    await _goTo(tester, 'Jimpitan');
    expect(find.text('Rp 1.250.000'), findsOneWidget);
  });

  testWidgets('a failing call shows Coba lagi, and it works', (tester) async {
    var calls = 0;
    await _open(tester, (m) async {
      calls++;
      if (calls == 1) {
        throw DioException(
            requestOptions: RequestOptions(path: '/dashboard'),
            type: DioExceptionType.connectionError);
      }
      return _ok(m);
    });
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.text('Saldo Kas'), findsNothing);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Saldo Kas'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('the month stepper asks for that month', (tester) async {
    final asked = <String>[];
    await _open(tester, (m) {
      asked.add(m);
      return _ok(m);
    });
    await _goTo(tester, 'Shodaqoh');
    final now = DateTime.now();
    String key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
    expect(asked, [key(DateTime(now.year, now.month))]);

    await tester.tap(find.byTooltip('Bulan sebelumnya'));
    await tester.pumpAndSettle();
    expect(asked.last, key(DateTime(now.year, now.month - 1)));
    expect(asked.length, 2);
  });

  testWidgets('jimpitan lists a few entries and can show them all',
      (tester) async {
    final items = [
      for (var i = 1; i <= 8; i++)
        {
          'label': 'Entri $i',
          'date': '2026-11-${i.toString().padLeft(2, '0')}',
          'amount': '1000',
          'kind': i.isEven ? 'kas' : 'setoran',
        },
    ];
    await _open(
        tester,
        (m) => _ok(m, {
              'jimpitan': {
                'data': {
                  'total': '8000',
                  'setoran_total': '4000',
                  'kas_total': '4000',
                  'contributors': 8,
                  'items': items,
                },
              },
            }));
    await _goTo(tester, 'Jimpitan');
    expect(find.text('Entri 1'), findsOneWidget);
    expect(find.text('Entri 8'), findsNothing);

    await tester.ensureVisible(find.textContaining('Lihat semua'));
    await tester.tap(find.textContaining('Lihat semua'));
    await tester.pumpAndSettle();
    expect(find.text('Entri 8'), findsOneWidget);
  });

  testWidgets('a narrow phone with big numbers does not overflow',
      (tester) async {
    await _open(
        tester,
        (m) => _ok(m, {
              'finance': {
                'data': {
                  'balance': '1234567890123',
                  'income': '999999999999',
                  'expense': '888888888888',
                  'as_of': '2026-11-01',
                  'recent_transactions': [
                    {
                      'id': 'a',
                      'date': '2026-11-01',
                      'description':
                          'Deskripsi transaksi yang sangat panjang sekali '
                              'sampai tidak muat dalam satu baris layar kecil',
                      'type': 'expense',
                      'amount': '123456789012',
                    },
                  ],
                },
              },
            }),
        size: const Size(320, 2600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a month with nothing in jimpitan says so', (tester) async {
    await _open(
        tester,
        (m) => _ok(m, {
              'jimpitan': {
                'data': {
                  'total': '0',
                  'setoran_total': '0',
                  'kas_total': '0',
                  'contributors': 0,
                  'items': [],
                },
              },
            }));
    await _goTo(tester, 'Jimpitan');
    expect(find.textContaining('Belum ada jimpitan'), findsOneWidget);
  });

  testWidgets('changing month keeps Saldo Kas while the month loads',
      (tester) async {
    final gate = Completer<RingkasanData>();
    var calls = 0;
    await _open(tester, (m) {
      calls++;
      return calls == 1 ? _ok(m) : gate.future;
    });
    await _goTo(tester, 'Jimpitan');
    expect(find.text('Rp 1.250.000'), findsOneWidget);
    await tester.tap(find.byTooltip('Bulan sebelumnya'));
    await tester.pump();

    expect(find.text('Rp 1.250.000'), findsNothing); // waiting for the month
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await _goToLoading(tester, 'Keuangan'); // today's figures stay
    expect(find.text('Saldo Kas'), findsOneWidget);
    await _goToLoading(tester, 'Jimpitan');

    gate.complete(await _ok('x'));
    await tester.pumpAndSettle();
    expect(find.text('Rp 1.250.000'), findsOneWidget);
  });

  testWidgets('a month that fails keeps the rest and offers a retry',
      (tester) async {
    var calls = 0;
    await _open(tester, (m) async {
      calls++;
      if (calls == 2) {
        throw DioException(
            requestOptions: RequestOptions(path: '/dashboard'),
            type: DioExceptionType.connectionError);
      }
      return _ok(m);
    });
    await _goTo(tester, 'Jimpitan');
    await tester.tap(find.byTooltip('Bulan sebelumnya'));
    await tester.pumpAndSettle();

    expect(find.text('Rp 1.250.000'), findsNothing);
    expect(find.text('Coba lagi'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Rp 1.250.000'), findsOneWidget);
    expect(calls, 3);
  });
}
