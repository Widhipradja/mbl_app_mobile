class AttendanceTrend {
  final int day;
  final String month;
  final int year;
  final int totalAttended;
  final int totalExpected;
  final int totalEvents;
  final int totalRemarks;
  final double attendanceRate;

  AttendanceTrend({
    required this.day,
    required this.month,
    required this.year,
    required this.totalAttended,
    required this.totalExpected,
    required this.totalEvents,
    required this.totalRemarks,
    required this.attendanceRate,
  });

  static const _monthNames = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _parseMonth(dynamic raw) {
    if (raw is int) {
      return (raw >= 1 && raw <= 12) ? _monthNames[raw] : raw.toString();
    }
    final s = raw.toString().trim();
    final n = int.tryParse(s);
    if (n != null) {
      return (n >= 1 && n <= 12) ? _monthNames[n] : s;
    }
    return s; // already a name like "February"
  }

  factory AttendanceTrend.fromJson(Map<String, dynamic> json) {
    return AttendanceTrend(
      day: (json['day'] as num).toInt(),
      month: _parseMonth(json['month']),
      year: (json['year'] as num).toInt(),
      totalAttended: (json['total_attended'] as num).toInt(),
      totalExpected: (json['total_expected'] as num).toInt(),
      totalEvents: (json['total_events'] as num).toInt(),
      totalRemarks: (json['total_remarks'] as num? ?? 0).toInt(),
      attendanceRate: (json['attendance_rate'] as num).toDouble(),
    );
  }

  String get label {
    final abbr = month.length >= 3 ? month.substring(0, 3) : month;
    return '$day $abbr';
  }
}
