import 'package:baraka_funds/screens/events/attendance_data.dart';
import 'package:baraka_funds/screens/events/attendance_monthly_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/attendance_fixture.dart';

Map<String, dynamic> _ev(String id, String status, int present, double rate) => {
      'event_id': id,
      'title': 'Event $id',
      'start_date': '2026-11-12',
      'status': status,
      'expected': 63,
      'present': present,
      'online': 0,
      'permission': 5,
      'absent': 3,
      'rate': rate,
    };

void main() {
  testWidgets('U-09 one card per event; only Completed has a percent',
      (t) async {
    final repo = FakeAttendanceRepo([rosterJson()])
      ..months = {
        '2026-11': {
          'month': '2026-11',
          'events': [
            _ev('a', 'Completed', 55, 87.3),
            _ev('b', 'Ongoing', 12, 19.0),
            _ev('c', 'Scheduled', 0, 0),
            _ev('d', 'Cancelled', 0, 0),
          ],
        },
      };
    await t.pumpWidget(MaterialApp(
        home: AttendanceMonthlyScreen(repo: repo, initialMonth: DateTime(2026, 11))));
    await t.pumpAndSettle();
    expect(find.text('Event a'), findsOneWidget);
    expect(find.text('Event b'), findsOneWidget);
    expect(find.text('Event c'), findsOneWidget);
    expect(find.text('Event d'), findsNothing);
    expect(find.text('Present 55/63 (87%)'), findsOneWidget);
    expect(find.text('Permission 5 · Absent 3'), findsOneWidget);
    expect(find.text('Absent: Not recorded yet'), findsNWidgets(2));
    expect(find.textContaining('%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('U-09 changing month loads that month; empty month says so',
      (t) async {
    final repo = FakeAttendanceRepo([rosterJson()])
      ..months = {
        '2026-11': {'month': '2026-11', 'events': [_ev('a', 'Completed', 55, 87.3)]},
      };
    await t.pumpWidget(MaterialApp(
        home: AttendanceMonthlyScreen(repo: repo, initialMonth: DateTime(2026, 11))));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Bulan sebelumnya'));
    await t.pumpAndSettle();
    expect(repo.monthCalls, ['2026-11', '2026-10']);
    expect(find.text('No events with attendance this month.'), findsOneWidget);
    expect(find.text('Event a'), findsNothing);
  });

  testWidgets('a failure shows Retry', (t) async {
    final repo = FakeAttendanceRepo([rosterJson()]);
    await t.pumpWidget(MaterialApp(
        home: AttendanceMonthlyScreen(repo: _Failing(), initialMonth: DateTime(2026, 11))));
    await t.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(repo.monthCalls, isEmpty);
  });
}

class _Failing extends FakeAttendanceRepo {
  _Failing() : super([rosterJson()]);
  @override
  Future<MonthlyAttendance> monthly(DateTime month) async =>
      throw failure(502, {'error': 'events is unavailable'});
}
