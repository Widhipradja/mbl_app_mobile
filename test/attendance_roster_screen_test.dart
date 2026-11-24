import 'package:baraka_funds/screens/events/attendance_roster_screen.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/attendance_fixture.dart';

Future<void> _open(WidgetTester tester, FakeAttendanceRepo repo,
    {Future<void> Function()? onSignInAgain}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
      home: AttendanceRosterScreen(
          eventId: 'ev1', repo: repo, onSignInAgain: onSignInAgain)));
  await tester.pumpAndSettle();
}

int _checks() => find.byIcon(Icons.check_circle_rounded).evaluate().length;

void main() {
  testWidgets('shows server numbers and tab counts from the rows', (t) async {
    await _open(t, FakeAttendanceRepo([rosterJson()]));
    expect(find.text('Present 40 of 63 · Permission 5 · Absent: Not recorded yet'),
        findsOneWidget);
    expect(find.text('Men (1/2)'), findsOneWidget);
    expect(find.text('Women (0/1)'), findsOneWidget);
    expect(find.text('Budi X'), findsOneWidget);
    expect(find.text('Dewi X'), findsNothing); // women are on the other tab
  });

  group('U-03 toggle', () {
    testWidgets('sends one PUT, then reads the roster again', (t) async {
      final repo = FakeAttendanceRepo([
        rosterJson(),
        rosterJson(rows: [
          row('m1', 'Budi', here: true),
          row('m2', 'Candra', here: true),
          row('w1', 'Dewi', sex: 'F'),
        ], tally: {'expected': 63, 'present': 41, 'online': 3, 'permission': 5, 'absent': 17}),
      ]);
      await _open(t, repo);
      await t.tap(find.text('Candra X'));
      await t.pumpAndSettle();
      expect(repo.singles, [
        {'member': 'm2', 'is_attending': true}
      ]);
      expect(repo.rosterCalls, 2);
      expect(find.textContaining('Present 41 of 63'), findsOneWidget);
    });

    testWidgets('a refusal puts the tick back', (t) async {
      final repo = FakeAttendanceRepo([rosterJson()])
        ..singleError = failure(502, {'error': 'events is unavailable'});
      await _open(t, repo);
      expect(_checks(), 1);
      await t.tap(find.text('Candra X'));
      await t.pumpAndSettle();
      expect(_checks(), 1); // back to how it was
      expect(repo.singles.length, 1); // no automatic retry
      expect(repo.rosterCalls, 1);
      expect(find.textContaining('Could not reach the events service'),
          findsOneWidget);
    });
  });

  testWidgets('U-04 a note is sent alone and the numbers come from the server',
      (t) async {
    final repo = FakeAttendanceRepo([
      rosterJson(),
      rosterJson(tally: {'expected': 63, 'present': 40, 'online': 3, 'permission': 6, 'absent': 17}),
    ]);
    await _open(t, repo);
    await t.tap(find.byTooltip('Note').at(1)); // Candra
    await t.pumpAndSettle();
    expect(find.text('An absent member with a note counts as permission.'),
        findsOneWidget);
    await t.enterText(find.byType(TextField).last, 'sick');
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();
    expect(repo.singles, [
      {'member': 'm2', 'remark': 'sick'}
    ]);
    expect(find.textContaining('Permission 6'), findsOneWidget);
  });

  group('U-05 bulk', () {
    testWidgets('Mark all present is one bulk request', (t) async {
      final repo = FakeAttendanceRepo([rosterJson()]);
      await _open(t, repo);
      await t.tap(find.text('Mark all present'));
      await t.pumpAndSettle();
      expect(repo.bulks.length, 1);
      expect(repo.bulks.single['ids'], ['m1', 'm2', 'w1']);
      expect(repo.bulks.single['is_attending'], true);
      expect(repo.singles, isEmpty);
    });

    testWidgets('Clear all asks first, then sends one request', (t) async {
      final repo = FakeAttendanceRepo([rosterJson()]);
      await _open(t, repo);
      await t.tap(find.widgetWithText(OutlinedButton, 'Clear all'));
      await t.pumpAndSettle();
      expect(repo.bulks, isEmpty);
      await t.tap(find.widgetWithText(TextButton, 'Clear all'));
      await t.pumpAndSettle();
      expect(repo.bulks.single['is_attending'], false);
    });

    testWidgets('more than 1000 members: no bulk, no splitting', (t) async {
      final rows = [for (var i = 0; i < 1001; i++) row('m$i', 'N$i')];
      final repo = FakeAttendanceRepo([rosterJson(rows: rows)]);
      await _open(t, repo);
      final btn = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Mark all present'));
      expect(btn.onPressed, isNull);
      expect(find.textContaining('max 1000'), findsOneWidget);
    });
  });

  testWidgets('U-06 an empty roster offers Generate, then fills up', (t) async {
    final repo = FakeAttendanceRepo([
      rosterJson(rows: [], tally: {'expected': 0, 'present': 0, 'online': 0, 'permission': 0, 'absent': 0}),
      rosterJson(),
    ]);
    await _open(t, repo);
    expect(find.text('Nobody is on this roster yet.'), findsOneWidget);
    await t.tap(find.text('Generate attendance list'));
    await t.pumpAndSettle();
    expect(repo.syncs, 1);
    expect(find.text('Budi X'), findsOneWidget);
  });

  testWidgets('Generate from the app bar reports what changed', (t) async {
    final repo = FakeAttendanceRepo([rosterJson()]);
    await _open(t, repo);
    await t.tap(find.byTooltip('Generate attendance list'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Attendance list updated: 12 added, 0 removed'),
        findsOneWidget);
  });

  testWidgets('U-07 a Completed event is read-only with a banner', (t) async {
    final repo = FakeAttendanceRepo([rosterJson(status: 'Completed')]);
    await _open(t, repo);
    expect(find.textContaining('Reopen it in the web app'), findsOneWidget);
    expect(find.text('Mark all present'), findsNothing);
    expect(find.text('Clear all'), findsNothing);
    expect(find.text('Present 40 of 63 · Permission 5 · Absent 18'),
        findsOneWidget);
    expect(t.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    final gen = t.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.playlist_add_rounded));
    expect(gen.onPressed, isNull);
    await t.tap(find.text('Candra X'));
    await t.pumpAndSettle();
    expect(repo.singles, isEmpty);
    // Summary still opens.
    await t.tap(find.byTooltip('Summary'));
    await t.pumpAndSettle();
    expect(find.text('Expected'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
  });

  testWidgets('Summary of a running event hides Absent', (t) async {
    await _open(t, FakeAttendanceRepo([rosterJson()]));
    await t.tap(find.byTooltip('Summary'));
    await t.pumpAndSettle();
    expect(find.text('Not recorded yet'), findsOneWidget);
    expect(find.text('18'), findsNothing);
  });

  group('U-08 refusals', () {
    testWidgets('upstream_unauthorized keeps the session and offers sign in',
        (t) async {
      final repo = FakeAttendanceRepo([rosterJson()])
        ..rosterError = failure(403, {'code': 'upstream_unauthorized', 'error': 'x'});
      var signedIn = 0;
      await _open(t, repo, onSignInAgain: () async => signedIn++);
      expect(find.text('Your session is not recognized by the events service.'),
          findsOneWidget);
      expect(signedIn, 0); // nothing happens by itself
      await t.tap(find.text('Sign in again'));
      await t.pump();
      expect(signedIn, 1);
    });

    testWidgets('not_event_writer goes back to the previous screen', (t) async {
      final repo = FakeAttendanceRepo([rosterJson()])
        ..rosterError = failure(403, {'code': 'not_event_writer', 'error': 'x'});
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(
                  builder: (_) => AttendanceRosterScreen(eventId: 'ev1', repo: repo))),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text('open'), findsOneWidget); // back on the first screen
      expect(find.text('You do not have access to take attendance for this event.'),
          findsOneWidget);
    });

    testWidgets('a network error shows Retry and Retry reloads', (t) async {
      final repo = FakeAttendanceRepo([rosterJson()])
        ..rosterError = failure(503, {'error': 'events is unavailable'});
      await _open(t, repo);
      expect(find.text('Retry'), findsOneWidget);
      repo.rosterError = null;
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(find.text('Budi X'), findsOneWidget);
    });

    testWidgets('locked on write: told to reopen in web, roster reloaded', (t) async {
      final repo = FakeAttendanceRepo([rosterJson(), rosterJson(status: 'Completed')])
        ..singleError = failure(409, {'code': 'attendance_locked', 'error': 'x'});
      await _open(t, repo);
      await t.tap(find.text('Candra X'));
      await t.pumpAndSettle();
      expect(find.textContaining('Reopen it in the web app'), findsWidgets);
      expect(repo.rosterCalls, 2);
    });
  });

  testWidgets('an event that does not track attendance says so', (t) async {
    await _open(t, FakeAttendanceRepo([rosterJson(track: false, rows: [])]));
    expect(find.text('This event does not track attendance.'), findsOneWidget);
    expect(find.text('Generate attendance list'), findsNothing);
  });

  group('sex tabs', () {
    testWidgets('Unspecified appears only when someone is in it, and is not Women',
        (t) async {
      final repo = FakeAttendanceRepo([
        rosterJson(rows: [
          row('m1', 'Budi', here: true),
          row('w1', 'Dewi', sex: 'F'),
          row('u1', 'Eka', sex: ''),
          row('u2', 'Fajar', sex: 'X', here: true),
        ]),
      ]);
      await _open(t, repo);
      expect(find.text('Men (1/1)'), findsOneWidget);
      expect(find.text('Women (0/1)'), findsOneWidget);
      expect(find.text('Unspecified (1/2)'), findsOneWidget);
      await t.tap(find.text('Women (0/1)'));
      await t.pumpAndSettle();
      expect(find.text('Dewi X'), findsOneWidget);
      expect(find.text('Eka X'), findsNothing);
      await t.tap(find.text('Unspecified (1/2)'));
      await t.pumpAndSettle();
      expect(find.text('Eka X'), findsOneWidget);
      expect(find.text('Fajar X'), findsOneWidget);
    });

    testWidgets('no Unspecified tab when every row is M or F', (t) async {
      await _open(t, FakeAttendanceRepo([rosterJson()]));
      expect(find.textContaining('Unspecified'), findsNothing);
    });
  });

  group('reload after writes is coalesced', () {
    testWidgets('writes made during a reload share one more reload', (t) async {
      final repo = FakeAttendanceRepo([
        rosterJson(rows: [
          row('m1', 'Budi'),
          row('m2', 'Candra'),
          row('m3', 'Dodi'),
          row('m4', 'Eko'),
        ]),
      ]);
      await _open(t, repo);
      expect(repo.rosterCalls, 1);

      // First write: its reload starts and is held.
      repo.holdRoster = Completer<void>();
      await t.tap(find.text('Budi X'));
      await t.pump();
      await t.pump();
      expect(repo.rosterCalls, 2);

      // Three more writes land while that reload is still running.
      await t.tap(find.text('Candra X'));
      await t.pump();
      await t.tap(find.text('Dodi X'));
      await t.pump();
      await t.tap(find.text('Eko X'));
      await t.pump();
      expect(repo.singles.length, 4);
      expect(repo.rosterCalls, 2); // none started a reload of its own

      repo.holdRoster!.complete();
      await t.pumpAndSettle();
      expect(repo.rosterCalls, 3); // one reload for all three, not three
    });

    testWidgets('writes in flight together cause one reload', (t) async {
      final repo = FakeAttendanceRepo([rosterJson()]);
      await _open(t, repo);
      repo.holdWrite = Completer<void>();
      await t.tap(find.text('Budi X'));
      await t.pump();
      await t.tap(find.text('Candra X'));
      await t.pump();
      expect(repo.singles.length, 2); // both on the wire
      expect(repo.rosterCalls, 1);
      repo.holdWrite!.complete();
      await t.pumpAndSettle();
      expect(repo.rosterCalls, 2); // one reload, not one per write
    });
  });
}
