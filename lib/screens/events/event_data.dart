import 'package:dio/dio.dart';

import '../../services/api_service.dart';

String _s(dynamic v) => v?.toString().trim() ?? '';

/// `YYYY-MM-DD` from a date or an RFC 3339 stamp, with no timezone shift.
String _day(dynamic v) {
  final s = _s(v);
  return s.length >= 10 ? s.substring(0, 10) : s;
}

/// `HH:MM` from `HH:MM` or `HH:MM:SS`.
String _hm(dynamic v) {
  final s = _s(v);
  return s.length >= 5 ? s.substring(0, 5) : s;
}

/// `YYYY-MM`
String eventPeriod(DateTime m) =>
    '${m.year}-${m.month.toString().padLeft(2, '0')}';

/// `YYYY-MM-DD`
String eventDay(DateTime d) =>
    '${eventPeriod(d)}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseEventDay(String s) {
  final d = DateTime.tryParse(s);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

class EventMaterial {
  const EventMaterial({required this.title, this.speaker = ''});

  factory EventMaterial.fromJson(Map<String, dynamic> j) =>
      EventMaterial(title: _s(j['title']), speaker: _s(j['speaker']));

  final String title, speaker;

  Map<String, dynamic> toJson() =>
      {'title': title, if (speaker.isNotEmpty) 'speaker': speaker};
}

class MobileEvent {
  const MobileEvent({
    required this.id,
    required this.title,
    required this.startDate,
    this.endDate = '',
    this.startTime = '',
    this.endTime = '',
    this.description = '',
    this.location = '',
    this.level = '',
    this.category = 'Umum',
    this.kind = 'event',
    this.status = 'Scheduled',
    this.materials = const [],
  });

  factory MobileEvent.fromJson(Map<String, dynamic> j) {
    final mats = j['materials'];
    return MobileEvent(
      id: _s(j['id']),
      title: _s(j['title']),
      description: _s(j['description']),
      location: _s(j['location']),
      level: _s(j['level']),
      category: _s(j['category']).isEmpty ? 'Umum' : _s(j['category']),
      kind: _s(j['kind']).isEmpty ? 'event' : _s(j['kind']),
      status: _s(j['status']).isEmpty ? 'Scheduled' : _s(j['status']),
      startDate: _day(j['start_date']),
      endDate: _day(j['end_date']),
      startTime: _hm(j['start_time']),
      endTime: _hm(j['end_time']),
      materials: mats is List
          ? mats
              .whereType<Map<String, dynamic>>()
              .map(EventMaterial.fromJson)
              .toList()
          : const [],
    );
  }

  final String id, title, description, location, level, category, kind, status;

  /// `YYYY-MM-DD`; [endDate] is empty for a single day.
  final String startDate, endDate;

  /// `HH:MM`, both empty for an all-day event or a multi-day one.
  final String startTime, endTime;
  final List<EventMaterial> materials;

  bool get isAnnouncement => kind == 'announcement';
  bool get isMultiDay => endDate.isNotEmpty && endDate != startDate;
  bool get hasTime => startTime.isNotEmpty && endTime.isNotEmpty;
  DateTime? get start => parseEventDay(startDate);
  DateTime? get end => parseEventDay(endDate.isEmpty ? startDate : endDate);
}

/// The form's choices. Categories are required and must be one of them;
/// locations are only suggestions (free text is fine).
class EventLookups {
  const EventLookups({this.categories = const [], this.locations = const []});

  final List<String> categories, locations;

  /// Values in the server's order, without blanks or repeats. Accepts
  /// `[{value, order}]` or a plain list of texts.
  static List<String> _values(dynamic raw) {
    if (raw is! List) return const [];
    final rows = <(int, String)>[];
    for (var i = 0; i < raw.length; i++) {
      final r = raw[i];
      final v = _s(r is Map ? r['value'] : r);
      if (v.isEmpty) continue;
      final order = r is Map ? int.tryParse('${r['order']}') : null;
      rows.add((order ?? i + 1, v));
    }
    // Stable: ties keep the server's sequence.
    final at = {for (var i = 0; i < rows.length; i++) rows[i]: i};
    rows.sort((a, b) {
      final c = a.$1.compareTo(b.$1);
      return c != 0 ? c : at[a]!.compareTo(at[b]!);
    });
    final seen = <String>{};
    return [
      for (final r in rows)
        if (seen.add(r.$2)) r.$2
    ];
  }

  factory EventLookups.fromJson(dynamic d) {
    final m = d is Map ? d : const {};
    return EventLookups(
      categories: _values(m['categories']),
      locations: _values(m['locations']),
    );
  }
}

class EventRepository {
  Map<String, dynamic> _map(dynamic d) =>
      d is Map<String, dynamic> ? d : <String, dynamic>{};

  MobileEvent _one(dynamic d) {
    final m = _map(d);
    return MobileEvent.fromJson(_map(m['event']).isNotEmpty ? _map(m['event']) : m);
  }

  /// Events of [month], by start date then time.
  Future<List<MobileEvent>> month(DateTime month) async {
    final d = (await ApiService().getMobileEvents(eventPeriod(month))).data;
    final raw = d is List ? d : _map(d)['events'];
    final list = raw is List
        ? raw.whereType<Map<String, dynamic>>().map(MobileEvent.fromJson)
        : const <MobileEvent>[];
    return list.toList()
      ..sort((a, b) {
        final c = a.startDate.compareTo(b.startDate);
        return c != 0 ? c : a.startTime.compareTo(b.startTime);
      });
  }

  Future<EventLookups> lookups() async =>
      EventLookups.fromJson((await ApiService().getEventLookups()).data);

  /// A hint for showing the controls; event-reminder still enforces.
  Future<bool> canManage() async {
    final d = (await ApiService().getEventAccess()).data;
    return _map(d)['can_manage'] == true;
  }

  Future<MobileEvent> get(String id) async =>
      _one((await ApiService().getMobileEvent(id)).data);

  Future<MobileEvent> create(Map<String, dynamic> body) async =>
      _one((await ApiService().createMobileEvent(body)).data);

  Future<MobileEvent> update(String id, Map<String, dynamic> body) async =>
      _one((await ApiService().updateMobileEvent(id, body)).data);

  Future<void> delete(String id) => ApiService().deleteMobileEvent(id);
}

final eventRepo = EventRepository();

/// What went wrong, so a screen can react (hide controls, refresh).
enum EventFailure { notWriter, notProvisioned, notFound, badCategory, other }

String? _code(Object e) {
  if (e is DioException && e.response?.data is Map) {
    return _s((e.response!.data as Map)['code']);
  }
  return null;
}

String _reason(Object e) {
  if (e is DioException && e.response?.data is Map) {
    return _s((e.response!.data as Map)['error']);
  }
  return '';
}

EventFailure eventFailure(Object e) {
  if (e is DioException) {
    final status = e.response?.statusCode;
    if (status == 403 && _code(e) == 'not_event_writer') {
      return EventFailure.notWriter;
    }
    if (status == 403 && _code(e) == 'upstream_unauthorized') {
      return EventFailure.notProvisioned;
    }
    if (status == 404) return EventFailure.notFound;
    // 422 "Kategori tidak dikenal. Pilih dari daftar kategori."
    if (status == 422 && _reason(e).toLowerCase().contains('kategori')) {
      return EventFailure.badCategory;
    }
  }
  return EventFailure.other;
}

/// A message for the user, by status. The server's own text is shown for
/// `400` (event-reminder's business rules).
String eventError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    final reason = data is Map ? _s(data['error']) : '';
    switch (e.response?.statusCode) {
      case 400:
        return reason.isNotEmpty ? reason : 'Data ditolak server. Periksa isian.';
      case 401:
        return 'Sesi Anda berakhir. Silakan masuk lagi.';
      case 403:
        switch (_code(e)) {
          case 'not_event_writer':
            return 'Anda tidak punya izin mengelola kegiatan.';
          case 'upstream_unauthorized':
            return 'Akun belum terdaftar di event-reminder.';
        }
        if (reason == 'tenant required') {
          return 'Akun Anda belum terhubung ke organisasi.';
        }
        return 'Modul kegiatan tidak tersedia untuk akun Anda.';
      case 404:
        return 'Kegiatan sudah tidak ada.';
      case 413:
        return 'Isi kegiatan terlalu besar. Kurangi keterangan atau materi.';
      case 422:
        return reason.isNotEmpty ? reason : 'Data ditolak server. Periksa isian.';
      case 502:
      case 503:
      case 504:
        return 'Layanan kegiatan sedang tidak tersedia. Isian Anda tetap '
            'ada, coba lagi sebentar lagi.';
      case 409:
        return reason.isNotEmpty ? reason : 'Data bentrok. Coba lagi.';
    }
    if (e.response == null) {
      return 'Tidak bisa terhubung ke server. Periksa koneksi Anda.';
    }
  }
  return 'Gagal memproses. Coba lagi.';
}
