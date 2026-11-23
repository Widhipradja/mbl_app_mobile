import 'package:baraka_funds/models/savings_ledgers.dart';
import 'package:baraka_funds/screens/savings/amal_chart_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A yearly report as the API sends it: one entry per month with its totals.
AmalJariyahYear _year(int year, Map<int, List<num>> byMonth) =>
    AmalJariyahYear.parse({
      'year': '$year',
      'earliest_year': 2024,
      'months': [
        for (final e in byMonth.entries)
          {
            'period': '$year-${e.key.toString().padLeft(2, '0')}',
            'totals': {
              'fr': e.value[0],
              'shodaqoh': e.value[1],
              'infaq': e.value[2],
              'total': e.value[0] + e.value[1] + e.value[2],
            },
          },
      ],
    });

Future<void> _pump(WidgetTester tester, Widget chart,
    {Size size = const Size(360, 800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: chart)),
  ));
}

void main() {
  test('a yearly report is read from the body, not from the response', () {
    final y = _year(2025, {
      1: [100000, 50000, 25000],
      2: [100000, 0, 0],
    });
    expect(y.months.length, 2);
    expect(y.total, 275000);
    expect(y.months.first.monthNumber, 1);
  });

  testWidgets('draws the summary, the bars and the running total',
      (tester) async {
    final data = _year(2025, {
      1: [100000, 50000, 25000],
      2: [100000, 0, 0],
      3: [0, 0, 300000],
    });
    final prev = _year(2024, {
      1: [80000, 0, 0],
      2: [80000, 40000, 0],
    });
    await _pump(
        tester,
        AmalChartView(
            year: 2025, data: data, previous: prev, onOpenMonth: (_, __) {}));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Total tahun 2025'), findsOneWidget);
    expect(find.text('Per bulan'), findsOneWidget);
    expect(find.text('Akumulasi'), findsOneWidget);
    // The last month with data starts selected, so its detail shows.
    expect(find.text('Maret 2025'), findsOneWidget);
    expect(find.text('Rincian bulan ini'), findsOneWidget);
  });

  testWidgets('tapping a bar shows that month and can open it',
      (tester) async {
    final data = _year(2025, {
      1: [100000, 50000, 25000],
      3: [0, 0, 300000],
    });
    int? openedYear, openedMonth;
    await _pump(
        tester,
        AmalChartView(
            year: 2025,
            data: data,
            previous: null,
            onOpenMonth: (y, m) {
              openedYear = y;
              openedMonth = m;
            }));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(RegExp('^Januari:')));
    await tester.pumpAndSettle();
    expect(find.text('Januari 2025'), findsOneWidget);

    await tester.ensureVisible(find.text('Rincian bulan ini'));
    await tester.tap(find.text('Rincian bulan ini'));
    expect(openedYear, 2025);
    expect(openedMonth, 1);
  });

  testWidgets('one month, no year before, a narrow phone', (tester) async {
    final data = _year(2025, {
      6: [1500000, 250000, 0],
    });
    await _pump(
        tester,
        AmalChartView(
            year: 2025, data: data, previous: null, onOpenMonth: (_, __) {}),
        size: const Size(320, 640));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Total tahun 2025'), findsOneWidget);
  });
}
