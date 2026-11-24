import 'package:baraka_funds/screens/events/event_data.dart';
import 'package:baraka_funds/screens/events/event_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/attendance_fixture.dart';

/// Answers the event read with the flag the detail response carries.
class _Events extends EventRepository {
  _Events(this.track);
  final bool? track;

  @override
  Future<MobileEvent> get(String id) async => MobileEvent.fromJson({
        'id': 'ev1',
        'title': 'Pengajian',
        'start_date': '2026-11-12',
        if (track != null) 'track_attendance': track,
      });
}

const _fromList = MobileEvent(id: 'ev1', title: 'Pengajian', startDate: '2026-11-12');

Future<void> _open(WidgetTester t, FakeAttendanceRepo repo,
    {required bool canManage, bool? track}) async {
  t.view.physicalSize = const Size(390, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
      home: EventDetailScreen(
          event: _fromList,
          canManage: canManage,
          events: _Events(track),
          attendance: repo)));
  await t.pumpAndSettle();
}

void main() {
  group('U-01 Attendance button', () {
    testWidgets('can_manage and track_attendance: shown, roster not read',
        (t) async {
      final repo = FakeAttendanceRepo([rosterJson()]);
      await _open(t, repo, canManage: true, track: true);
      expect(find.text('Attendance'), findsOneWidget);
      expect(repo.rosterCalls, 0); // names and phones stay on the server
    });

    testWidgets('can_manage but not tracked: a line instead', (t) async {
      final repo = FakeAttendanceRepo([rosterJson()]);
      await _open(t, repo, canManage: true, track: false);
      expect(find.text('Attendance'), findsNothing);
      expect(find.text('This event does not track attendance.'), findsOneWidget);
      expect(repo.rosterCalls, 0);
    });

    testWidgets('flag missing from the answer: neither button nor line',
        (t) async {
      await _open(t, FakeAttendanceRepo([rosterJson()]), canManage: true);
      expect(find.text('Attendance'), findsNothing);
      expect(find.text('This event does not track attendance.'), findsNothing);
    });

    testWidgets('not a manager: nothing', (t) async {
      final repo = FakeAttendanceRepo([rosterJson()]);
      await _open(t, repo, canManage: false, track: true);
      expect(find.text('Attendance'), findsNothing);
      expect(find.text('This event does not track attendance.'), findsNothing);
      expect(repo.rosterCalls, 0);
    });

    testWidgets('the roster is read when the roster screen opens', (t) async {
      final repo = FakeAttendanceRepo([rosterJson()]);
      await _open(t, repo, canManage: true, track: true);
      await t.tap(find.text('Attendance'));
      await t.pumpAndSettle();
      expect(find.text('Mark all present'), findsOneWidget);
      expect(repo.rosterCalls, 1);
    });
  });
}
