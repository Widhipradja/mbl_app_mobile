import 'dart:async';

import 'package:baraka_funds/screens/events/attendance_data.dart';
import 'package:dio/dio.dart';

Map<String, dynamic> row(String id, String first,
        {String sex = 'M', bool here = false, String mode = 'offline', String remark = ''}) =>
    {
      'member_id': id,
      'first_name': first,
      'last_name': 'X',
      'phone': '081',
      'sex': sex,
      'category': 'DEWASA',
      'is_attending': here,
      'presence_mode': mode,
      'remark': remark,
    };

/// A roster answer. [tally] defaults to numbers that do NOT match the rows, to
/// prove the screen shows the server's numbers and does not count.
Map<String, dynamic> rosterJson({
  String status = 'Ongoing',
  bool track = true,
  List<Map<String, dynamic>>? rows,
  Map<String, dynamic>? tally = const {
    'expected': 63,
    'present': 40,
    'online': 3,
    'permission': 5,
    'absent': 18,
  },
}) =>
    {
      'event': {
        'id': 'ev1',
        'title': 'Pengajian Kelompok',
        'status': status,
        'track_attendance': track,
        'start_date': '2026-11-12',
      },
      'rows': rows ??
          [
            row('m1', 'Budi', here: true),
            row('m2', 'Candra'),
            row('w1', 'Dewi', sex: 'F'),
          ],
      'tally': track ? tally : null,
    };

DioException failure(int status, Map<String, dynamic> body) {
  final req = RequestOptions(path: '/api/m/v1/events/ev1/attendance');
  return DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: status, data: body),
  );
}

/// Records every call; answers come from the lists/callbacks set by a test.
class FakeAttendanceRepo extends AttendanceRepository {
  FakeAttendanceRepo(this.rosters);

  /// Answers of successive `roster` calls; the last one repeats.
  final List<Map<String, dynamic>> rosters;
  int rosterCalls = 0;
  final singles = <Map<String, dynamic>>[];
  final bulks = <Map<String, dynamic>>[];
  int syncs = 0;
  Object? rosterError;

  /// While set and not finished, `roster` waits (to stage a slow reload).
  Completer<void>? holdRoster;

  /// Same for writes: keeps them in flight until completed.
  Completer<void>? holdWrite;
  Object? singleError;
  Object? bulkError;
  SyncResult syncResult = const SyncResult(added: 12, removed: 0);
  Map<String, Map<String, dynamic>> months = {};
  final monthCalls = <String>[];

  @override
  Future<AttendanceRoster> roster(String eventId) async {
    if (rosterError != null) throw rosterError!;
    final hold = holdRoster;
    final i = rosterCalls < rosters.length ? rosterCalls : rosters.length - 1;
    rosterCalls++;
    if (hold != null) await hold.future;
    return AttendanceRoster.fromJson(rosters[i]);
  }

  @override
  Future<void> setOne(String eventId, String memberId,
      {bool? isAttending, String? presenceMode, String? remark}) async {
    singles.add({
      'member': memberId,
      if (isAttending != null) 'is_attending': isAttending,
      if (presenceMode != null) 'presence_mode': presenceMode,
      if (remark != null) 'remark': remark,
    });
    if (holdWrite != null) await holdWrite!.future;
    if (singleError != null) throw singleError!;
  }

  @override
  Future<void> setMany(String eventId, List<String> ids, bool isAttending) async {
    bulks.add({'ids': ids, 'is_attending': isAttending});
    if (bulkError != null) throw bulkError!;
  }

  @override
  Future<SyncResult> sync(String eventId) async {
    syncs++;
    return syncResult;
  }

  @override
  Future<MonthlyAttendance> monthly(DateTime month) async {
    final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    monthCalls.add(key);
    return MonthlyAttendance.fromJson(months[key] ?? {'month': key, 'events': []});
  }
}
