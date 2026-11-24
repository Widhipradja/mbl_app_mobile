import 'package:baraka_funds/screens/events/attendance_data.dart';
import 'package:baraka_funds/screens/events/attendance_monthly_screen.dart';
import 'package:baraka_funds/screens/events/attendance_roster_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/attendance_fixture.dart';

void main() {
  group('roster parsing', () {
    test('keeps the server tally as it is', () {
      final r = AttendanceRoster.fromJson(rosterJson());
      expect(r.tally!.present, 40);
      expect(r.tally!.expected, 63);
      expect(r.rows.length, 3); // not 63: the tally is not worked out
      expect(r.trackAttendance, isTrue);
    });

    test('an event that does not track has no tally', () {
      final r = AttendanceRoster.fromJson(rosterJson(track: false, rows: []));
      expect(r.tally, isNull);
      expect(r.trackAttendance, isFalse);
      expect(attendanceSummaryLine(r), 'No roster yet');
    });
  });

  group('U-02 summary line', () {
    test('Completed shows Absent as a number', () {
      final r = AttendanceRoster.fromJson(rosterJson(status: 'Completed'));
      expect(attendanceSummaryLine(r),
          'Present 40 of 63 · Permission 5 · Absent 18');
    });

    for (final s in ['Scheduled', 'Ongoing', 'Cancelled']) {
      test('$s shows Not recorded yet, never the number', () {
        final r = AttendanceRoster.fromJson(rosterJson(status: s));
        final line = attendanceSummaryLine(r);
        expect(line, 'Present 40 of 63 · Permission 5 · Absent: Not recorded yet');
        expect(line, isNot(contains('18')));
      });
    }
  });

  group('U-08 failures', () {
    test('403 upstream_unauthorized is not a sign-out', () {
      final e = failure(403, {'code': 'upstream_unauthorized', 'error': 'x'});
      expect(attendanceFailure(e), AttendanceFailure.notProvisioned);
      expect(attendanceError(e), attendanceNotRecognized);
    });

    test('403 not_event_writer', () {
      final e = failure(403, {'code': 'not_event_writer', 'error': 'x'});
      expect(attendanceFailure(e), AttendanceFailure.notWriter);
      expect(attendanceError(e),
          'You do not have access to take attendance for this event.');
    });

    test('403 without a code is the module being off', () {
      expect(attendanceFailure(failure(403, {'error': 'module events is not enabled for your role'})),
          AttendanceFailure.moduleOff);
    });

    test('409 and 404 are told apart by code', () {
      expect(attendanceFailure(failure(409, {'code': 'attendance_locked'})),
          AttendanceFailure.locked);
      expect(attendanceFailure(failure(409, {'code': 'not_tracked'})),
          AttendanceFailure.notTracked);
      expect(attendanceFailure(failure(404, {'code': 'not_rostered'})),
          AttendanceFailure.notRostered);
      expect(attendanceFailure(failure(404, {'code': 'event_not_found'})),
          AttendanceFailure.eventNotFound);
      expect(attendanceError(failure(409, {'code': 'attendance_locked'})),
          contains('Reopen it in the web app'));
    });

    test('5xx is unavailable, 401 is a real session end', () {
      expect(attendanceFailure(failure(502, {})), AttendanceFailure.unavailable);
      expect(attendanceFailure(failure(401, {})), AttendanceFailure.sessionEnded);
    });
  });

  group('monthly', () {
    final json = {
      'month': '2026-11',
      'events': [
        {'event_id': 'a', 'title': 'A', 'start_date': '2026-11-12', 'status': 'Completed',
          'expected': 63, 'present': 55, 'online': 2, 'permission': 5, 'absent': 3, 'rate': 87.3},
        {'event_id': 'b', 'title': 'B', 'start_date': '2026-11-20', 'status': 'Ongoing',
          'expected': 63, 'present': 12, 'online': 0, 'permission': 0, 'absent': 51, 'rate': 19.0},
        {'event_id': 'c', 'title': 'C', 'start_date': '2026-11-21', 'status': 'Cancelled',
          'expected': 10, 'present': 0, 'online': 0, 'permission': 0, 'absent': 10, 'rate': 0},
      ],
    };

    test('drops Cancelled and keeps the rest', () {
      final m = MonthlyAttendance.fromJson(json);
      expect(m.events.map((e) => e.eventId), ['a', 'b']);
    });

    test('Completed has percent, others do not and hide Absent', () {
      final m = MonthlyAttendance.fromJson(json);
      expect(monthlyNumbersLine(m.events[0]), 'Present 55/63 (87%)');
      expect(monthlyDetailLine(m.events[0]), 'Permission 5 · Absent 3');
      expect(monthlyNumbersLine(m.events[1]), 'Present 12/63');
      expect(monthlyDetailLine(m.events[1]), 'Absent: Not recorded yet');
    });
  });
}
