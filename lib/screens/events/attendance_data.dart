import 'package:dio/dio.dart';

import '../../services/api_service.dart';
import 'event_data.dart';

String _s(dynamic v) => v?.toString().trim() ?? '';

int _i(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(_s(v)) ?? 0;
}

double _d(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(_s(v)) ?? 0;
}

Map<String, dynamic> _map(dynamic d) =>
    d is Map<String, dynamic> ? d : <String, dynamic>{};

/// The most member ids one bulk request may carry (server limit).
const attendanceBulkMax = 1000;

/// Longest note the server accepts.
const attendanceRemarkMax = 1000;

/// Event statuses; `Absent` is a number only for [attendanceCompleted].
const attendanceCompleted = 'Completed';

/// The server's count for one event. The app never works these out itself.
class AttendanceTally {
  const AttendanceTally({
    this.expected = 0,
    this.present = 0,
    this.online = 0,
    this.permission = 0,
    this.absent = 0,
  });

  factory AttendanceTally.fromJson(Map<String, dynamic> j) => AttendanceTally(
        expected: _i(j['expected']),
        present: _i(j['present']),
        online: _i(j['online']),
        permission: _i(j['permission']),
        absent: _i(j['absent']),
      );

  final int expected, present, online, permission, absent;
}

class AttendanceRow {
  const AttendanceRow({
    required this.memberId,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.sex = '',
    this.category = '',
    this.isAttending = false,
    this.presenceMode = 'offline',
    this.remark = '',
  });

  factory AttendanceRow.fromJson(Map<String, dynamic> j) => AttendanceRow(
        memberId: _s(j['member_id']),
        firstName: _s(j['first_name']),
        lastName: _s(j['last_name']),
        phone: _s(j['phone']),
        sex: _s(j['sex']).toUpperCase(),
        category: _s(j['category']),
        isAttending: j['is_attending'] == true,
        presenceMode: _s(j['presence_mode']) == 'online' ? 'online' : 'offline',
        remark: _s(j['remark']),
      );

  final String memberId, firstName, lastName, phone, sex, category;
  final bool isAttending;

  /// `offline` or `online`.
  final String presenceMode, remark;

  String get name {
    final n = '$firstName $lastName'.trim();
    return n.isEmpty ? '—' : n;
  }

  bool get isOnline => presenceMode == 'online';

  AttendanceRow copyWith(
          {bool? isAttending, String? presenceMode, String? remark}) =>
      AttendanceRow(
        memberId: memberId,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        sex: sex,
        category: category,
        isAttending: isAttending ?? this.isAttending,
        presenceMode: presenceMode ?? this.presenceMode,
        remark: remark ?? this.remark,
      );
}

/// `GET /events/:id/attendance`.
class AttendanceRoster {
  const AttendanceRoster({
    required this.event,
    required this.trackAttendance,
    this.rows = const [],
    this.tally,
  });

  factory AttendanceRoster.fromJson(dynamic d) {
    final m = _map(d);
    final ev = _map(m['event']);
    final rows = m['rows'];
    final tally = m['tally'];
    return AttendanceRoster(
      event: MobileEvent.fromJson(ev),
      trackAttendance: ev['track_attendance'] == true,
      rows: rows is List
          ? rows
              .whereType<Map<String, dynamic>>()
              .map(AttendanceRow.fromJson)
              .where((r) => r.memberId.isNotEmpty)
              .toList()
          : const [],
      tally: tally is Map<String, dynamic>
          ? AttendanceTally.fromJson(tally)
          : null,
    );
  }

  final MobileEvent event;
  final bool trackAttendance;
  final List<AttendanceRow> rows;

  /// `null` when the event does not track attendance.
  final AttendanceTally? tally;

  bool get isCompleted => event.status == attendanceCompleted;

  AttendanceRoster withRows(List<AttendanceRow> next) => AttendanceRoster(
      event: event, trackAttendance: trackAttendance, rows: next, tally: tally);
}

/// One card of the monthly report.
class MonthlyAttendanceItem {
  const MonthlyAttendanceItem({
    required this.eventId,
    required this.title,
    this.startDate = '',
    this.status = 'Scheduled',
    this.expected = 0,
    this.present = 0,
    this.online = 0,
    this.permission = 0,
    this.absent = 0,
    this.rate = 0,
  });

  factory MonthlyAttendanceItem.fromJson(Map<String, dynamic> j) {
    final day = _s(j['start_date']);
    return MonthlyAttendanceItem(
      eventId: _s(j['event_id']),
      title: _s(j['title']),
      startDate: day.length >= 10 ? day.substring(0, 10) : day,
      status: _s(j['status']).isEmpty ? 'Scheduled' : _s(j['status']),
      expected: _i(j['expected']),
      present: _i(j['present']),
      online: _i(j['online']),
      permission: _i(j['permission']),
      absent: _i(j['absent']),
      rate: _d(j['rate']),
    );
  }

  final String eventId, title, startDate, status;
  final int expected, present, online, permission, absent;

  /// Percent, from the server.
  final double rate;

  bool get isCompleted => status == attendanceCompleted;
}

class MonthlyAttendance {
  const MonthlyAttendance({required this.month, this.events = const []});

  factory MonthlyAttendance.fromJson(dynamic d) {
    final m = _map(d);
    final raw = m['events'];
    return MonthlyAttendance(
      month: _s(m['month']),
      events: raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(MonthlyAttendanceItem.fromJson)
              // The server already leaves Cancelled out; the spec says so too.
              .where((e) => e.status != 'Cancelled')
              .toList()
          : const [],
    );
  }

  final String month;
  final List<MonthlyAttendanceItem> events;
}

class SyncResult {
  const SyncResult({this.added = 0, this.removed = 0});
  final int added, removed;
  bool get unchanged => added == 0 && removed == 0;
}

/// Calls the attendance endpoints through the one [ApiService].
class AttendanceRepository {
  const AttendanceRepository();

  Future<AttendanceRoster> roster(String eventId) async => AttendanceRoster
      .fromJson((await ApiService().getEventAttendance(eventId)).data);

  /// Only the fields given are sent.
  Future<void> setOne(
    String eventId,
    String memberId, {
    bool? isAttending,
    String? presenceMode,
    String? remark,
  }) =>
      ApiService().updateAttendanceMember(eventId, memberId, {
        if (isAttending != null) 'is_attending': isAttending,
        if (presenceMode != null) 'presence_mode': presenceMode,
        if (remark != null) 'remark': remark,
      });

  /// One request for all [memberIds] (the server accepts 1..1000).
  Future<void> setMany(
          String eventId, List<String> memberIds, bool isAttending) =>
      ApiService().setAttendanceMany(eventId, memberIds, isAttending);

  Future<SyncResult> sync(String eventId) async {
    final m = _map((await ApiService().syncAttendance(eventId)).data);
    return SyncResult(added: _i(m['added']), removed: _i(m['removed']));
  }

  Future<MonthlyAttendance> monthly(DateTime month) async =>
      MonthlyAttendance.fromJson(
          (await ApiService().getAttendanceMonthly(eventPeriod(month))).data);
}

const attendanceRepo = AttendanceRepository();

enum AttendanceFailure {
  /// 403 `not_event_writer`.
  notWriter,

  /// 403 `upstream_unauthorized`: the events service does not know the
  /// account. The session is fine; never sign the user out for it.
  notProvisioned,

  /// 403 without a code: the events module is off for this role.
  moduleOff,

  /// 409 `attendance_locked`.
  locked,

  /// 409 `not_tracked`.
  notTracked,

  /// 404 `not_rostered`.
  notRostered,

  /// 404 `event_not_found` (or a 404 with no code).
  eventNotFound,

  /// 400.
  badRequest,

  /// 401: the token itself is no good (the HTTP layer signs out).
  sessionEnded,

  /// 502 / 503 / 504, or no answer at all.
  unavailable,
  other,
}

String? _code(Object e) {
  if (e is DioException && e.response?.data is Map) {
    final c = _s((e.response!.data as Map)['code']);
    return c.isEmpty ? null : c;
  }
  return null;
}

String _reason(Object e) {
  if (e is DioException && e.response?.data is Map) {
    return _s((e.response!.data as Map)['error']);
  }
  return '';
}

AttendanceFailure attendanceFailure(Object e) {
  if (e is! DioException) return AttendanceFailure.other;
  final status = e.response?.statusCode;
  if (status == null) {
    // An expired token is refused before it is sent.
    if (e.type == DioExceptionType.cancel) return AttendanceFailure.sessionEnded;
    return AttendanceFailure.unavailable;
  }
  switch (status) {
    case 400:
      return AttendanceFailure.badRequest;
    case 401:
      return AttendanceFailure.sessionEnded;
    case 403:
      switch (_code(e)) {
        case 'not_event_writer':
          return AttendanceFailure.notWriter;
        case 'upstream_unauthorized':
          return AttendanceFailure.notProvisioned;
      }
      return AttendanceFailure.moduleOff;
    case 404:
      return _code(e) == 'not_rostered'
          ? AttendanceFailure.notRostered
          : AttendanceFailure.eventNotFound;
    case 409:
      switch (_code(e)) {
        case 'attendance_locked':
          return AttendanceFailure.locked;
        case 'not_tracked':
          return AttendanceFailure.notTracked;
      }
      return AttendanceFailure.other;
    case 502:
    case 503:
    case 504:
      return AttendanceFailure.unavailable;
  }
  return AttendanceFailure.other;
}

const attendanceNotRecognized =
    'Your session is not recognized by the events service.';

/// What to tell the user, in English like the rest of the attendance screens.
String attendanceError(Object e) {
  switch (attendanceFailure(e)) {
    case AttendanceFailure.notWriter:
      return 'You do not have access to take attendance for this event.';
    case AttendanceFailure.notProvisioned:
      return attendanceNotRecognized;
    case AttendanceFailure.moduleOff:
      return 'Events are not available for your account.';
    case AttendanceFailure.locked:
      return 'This event is completed, so its attendance is locked. '
          'Reopen it in the web app to change it.';
    case AttendanceFailure.notTracked:
      return 'This event does not track attendance.';
    case AttendanceFailure.notRostered:
      return 'That member is no longer on this roster. The list was refreshed.';
    case AttendanceFailure.eventNotFound:
      return 'This event no longer exists.';
    case AttendanceFailure.badRequest:
      final r = _reason(e);
      return r.isNotEmpty ? r : 'The server rejected that change.';
    case AttendanceFailure.sessionEnded:
      return 'Your session has expired. Please sign in again.';
    case AttendanceFailure.unavailable:
      return 'Could not reach the events service. Check your connection '
          'and try again.';
    case AttendanceFailure.other:
      return 'Something went wrong. Please try again.';
  }
}
