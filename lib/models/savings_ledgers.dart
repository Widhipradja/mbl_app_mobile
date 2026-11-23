/// Models for Tabungan Kurban and Buku Amal Jariyah, read from the shodaqoh
/// service through the mobile gateway (`/api/m/v1/shodaqoh/me/*`; see
/// docs/KURBAN_AMAL_JARIYAH_API.md).
///
/// Amounts are strings in `qurban-savings` and `family-collection-summary` but
/// numbers in the family reports, so every amount goes through [_num], which
/// reads both. Parsers are defensive: unknown fields are ignored and a missing
/// total is summed from its parts.
library;

Map<String, dynamic> _map(dynamic v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};

double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

String _text(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k]?.toString().trim() ?? '';
    if (v.isNotEmpty) return v;
  }
  return '';
}

/// First of [keys] that is present, whatever its type.
dynamic _first(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    if (m[k] != null) return m[k];
  }
  return null;
}

/// The row list under [keys] (or `data` / `items`), or [raw] itself if a list.
List<Map<String, dynamic>> _rows(dynamic raw, List<String> keys) {
  dynamic src = raw;
  for (var i = 0; i < 3 && src is Map<String, dynamic>; i++) {
    src = _first(src, [...keys, 'data', 'items']);
  }
  return src is List
      ? src.whereType<Map<String, dynamic>>().toList()
      : const [];
}

/// The object holding the payload: the body itself, or its `data`.
Map<String, dynamic> _body(dynamic raw) {
  final m = _map(raw);
  final inner = m['data'];
  return inner is Map<String, dynamic> ? inner : m;
}

/// Who the data is about, and how to present it. Decided from `scope` and
/// `is_head_of_family`, never from the number of members.
class MemberScope {
  const MemberScope({required this.family, required this.isHead});

  /// Head of a family (KK): the whole family is listed, head first.
  final bool family;
  final bool isHead;

  factory MemberScope.parse(Map<String, dynamic> body) {
    final scope = (body['scope']?.toString() ?? '').toLowerCase();
    final head = body['is_head_of_family'] == true ||
        body['is_head_of_family']?.toString() == 'true';
    return MemberScope(family: scope == 'family' || head, isHead: head);
  }
}

// ── Tabungan Kurban ─────────────────────────────────────────────────────────

/// A month column of a savings cycle, e.g. key `2026-03`.
class CycleMonth {
  const CycleMonth(this.key);

  final String key;

  /// "Mar 26" for `2026-03`; anything unreadable is shown as it came.
  String label(List<String> names) {
    final m = RegExp(r'^(\d{4})-(\d{1,2})').firstMatch(key);
    if (m != null) {
      final month = int.parse(m.group(2)!);
      if (month >= 1 && month <= 12) {
        return '${names[month - 1]} ${m.group(1)!.substring(2)}';
      }
    }
    final n = int.tryParse(key);
    if (n != null && n >= 1 && n <= 12) return names[n - 1];
    return key;
  }
}

class QurbanMember {
  const QurbanMember({
    required this.name,
    required this.isHead,
    required this.byMonth,
    required this.total,
  });

  final String name;
  final bool isHead;

  /// Amount per month key; months not paid are absent (read as 0).
  final Map<String, double> byMonth;
  final double total;

  double paid(String monthKey) => byMonth[monthKey] ?? 0;

  static Map<String, double> byMonthOf(dynamic raw) => {
        if (raw is Map)
          for (final e in raw.entries) e.key.toString(): _num(e.value),
      };

  factory QurbanMember.fromJson(Map<String, dynamic> j) {
    final byMonth = byMonthOf(_first(j, ['by_month', 'months', 'monthly']));
    final sum = byMonth.values.fold<double>(0, (a, b) => a + b);
    final total = _num(j['total']);
    return QurbanMember(
      name: _text(j, ['name', 'member_name', 'full_name', 'nama']),
      isHead: j['is_head'] == true ||
          j['is_head_of_family'] == true ||
          _text(j, ['relationship', 'relation', 'role']).toLowerCase() ==
              'head',
      byMonth: byMonth,
      total: total > 0 ? total : sum,
    );
  }
}

class QurbanSavings {
  const QurbanSavings({
    required this.scope,
    required this.cycleName,
    required this.hasCycle,
    required this.months,
    required this.byMonth,
    required this.members,
    required this.total,
  });

  final MemberScope scope;

  /// Name of the running cycle; empty when it has none or none is given.
  final String cycleName;

  /// False when no savings cycle is running (`cycle: null`).
  final bool hasCycle;
  final List<CycleMonth> months;

  /// Totals of everyone per month, for every month of the cycle.
  final Map<String, double> byMonth;
  final List<QurbanMember> members;
  final double total;

  factory QurbanSavings.parse(dynamic raw) {
    final body = _body(raw);
    final cycle = body['cycle'];

    // Month columns: strings (`2026-03`), numbers, or `{month|period|key}`.
    final months = <CycleMonth>[];
    final rawMonths = body['months'];
    if (rawMonths is List) {
      for (final m in rawMonths) {
        final key = m is Map<String, dynamic>
            ? _text(m, ['key', 'month', 'period', 'ym', 'label'])
            : m.toString();
        if (key.isNotEmpty) months.add(CycleMonth(key));
      }
    }

    final members = [
      for (final r in _rows(body, ['members'])) QurbanMember.fromJson(r),
    ];
    final given = _num(body['total']);
    return QurbanSavings(
      scope: MemberScope.parse(body),
      cycleName: cycle is Map<String, dynamic>
          ? _text(cycle, ['name', 'title', 'label', 'code'])
          : '',
      hasCycle: cycle != null,
      months: months,
      byMonth: QurbanMember.byMonthOf(body['by_month']),
      members: members,
      total: given > 0 ? given : members.fold<double>(0, (a, m) => a + m.total),
    );
  }
}

/// Target and amount collected for one item (`family-collection-summary`).
class CollectionSummary {
  const CollectionSummary({required this.target, required this.collected});

  final double target;
  final double collected;

  bool get hasData => target > 0 || collected > 0;
  double get progress =>
      target > 0 ? (collected / target).clamp(0.0, 1.0).toDouble() : 0;

  factory CollectionSummary.parse(dynamic raw) {
    final b = _body(raw);
    return CollectionSummary(
      target: _num(_first(b, ['target', 'total_target', 'target_amount'])),
      collected: _num(_first(
          b, ['collected', 'total_collected', 'collected_amount', 'paid'])),
    );
  }
}

// ── Buku Amal Jariyah ───────────────────────────────────────────────────────

class AmalEntry {
  const AmalEntry({
    required this.name,
    required this.isHead,
    required this.fr,
    required this.shodaqoh,
    required this.infaq,
    required this.total,
  });

  final String name;
  final bool isHead;

  /// Fitrah (FR), shodaqoh and infaq given in the month.
  final double fr;
  final double shodaqoh;
  final double infaq;
  final double total;

  static double _field(Map<String, dynamic> j, List<String> keys) =>
      _num(_first(j, keys));

  factory AmalEntry.fromJson(Map<String, dynamic> j) {
    final fr = _field(j, ['fr', 'fitrah']);
    final shodaqoh = _field(j, ['shodaqoh', 'sodaqoh', 'sedekah']);
    final infaq = _field(j, ['infaq', 'infak']);
    final total = _num(j['total']);
    return AmalEntry(
      name: _text(j, ['name', 'member_name', 'full_name', 'nama']),
      isHead: j['is_head'] == true || j['is_head_of_family'] == true,
      fr: fr,
      shodaqoh: shodaqoh,
      infaq: infaq,
      total: total > 0 ? total : fr + shodaqoh + infaq,
    );
  }
}

/// One month of the Buku Amal Jariyah.
class AmalJariyahMonth {
  const AmalJariyahMonth({
    required this.scope,
    required this.period,
    required this.entries,
    required this.fr,
    required this.shodaqoh,
    required this.infaq,
    required this.total,
  });

  final MemberScope scope;

  /// `YYYY-MM` when the payload says which month it is, else empty.
  final String period;
  final List<AmalEntry> entries;
  final double fr;
  final double shodaqoh;
  final double infaq;
  final double total;

  bool get isEmpty => entries.isEmpty && total == 0;

  /// 1..12 from [period], or null.
  int? get monthNumber {
    final m = RegExp(r'^\d{4}-(\d{1,2})').firstMatch(period);
    final n = m == null ? null : int.parse(m.group(1)!);
    return n != null && n >= 1 && n <= 12 ? n : null;
  }

  factory AmalJariyahMonth.parse(dynamic raw) {
    final body = _body(raw);
    final entries = [
      for (final r in _rows(body, ['members', 'items', 'entries', 'rows']))
        AmalEntry.fromJson(r),
    ];

    // Column totals from the payload when given, else summed from the rows.
    final t = _map(_first(body, ['totals', 'summary']));
    double col(List<String> keys, double Function(AmalEntry) of) {
      final given = AmalEntry._field(t, keys);
      return given > 0 ? given : entries.fold<double>(0, (a, e) => a + of(e));
    }

    final fr = col(['fr', 'fitrah'], (e) => e.fr);
    final shodaqoh = col(['shodaqoh', 'sodaqoh', 'sedekah'], (e) => e.shodaqoh);
    final infaq = col(['infaq', 'infak'], (e) => e.infaq);
    final given = _num(t['total']);
    return AmalJariyahMonth(
      scope: MemberScope.parse(body),
      period: _text(body, ['period', 'month']),
      entries: entries,
      fr: fr,
      shodaqoh: shodaqoh,
      infaq: infaq,
      total: given > 0 ? given : fr + shodaqoh + infaq,
    );
  }
}

/// A year of the Buku Amal Jariyah: one report per month up to the current one.
class AmalJariyahYear {
  const AmalJariyahYear({
    required this.scope,
    required this.earliestYear,
    required this.months,
  });

  final MemberScope scope;

  /// Oldest year that has data: the limit for paging back. Null if unknown.
  final int? earliestYear;
  final List<AmalJariyahMonth> months;

  double get fr => months.fold(0, (a, m) => a + m.fr);
  double get shodaqoh => months.fold(0, (a, m) => a + m.shodaqoh);
  double get infaq => months.fold(0, (a, m) => a + m.infaq);
  double get total => months.fold(0, (a, m) => a + m.total);

  factory AmalJariyahYear.parse(dynamic raw) {
    final body = _body(raw);
    final months = <AmalJariyahMonth>[];
    final list = body['months'];
    if (list is List) {
      for (var i = 0; i < list.length; i++) {
        final r = list[i];
        if (r is! Map<String, dynamic>) continue;
        final m = AmalJariyahMonth.parse(r);
        // A report without its own month is placed by its position.
        months.add(m.monthNumber != null || m.period.isNotEmpty
            ? m
            : AmalJariyahMonth(
                scope: m.scope,
                period: '${_text(body, [
                      'year'
                    ])}-${(i + 1).toString().padLeft(2, '0')}',
                entries: m.entries,
                fr: m.fr,
                shodaqoh: m.shodaqoh,
                infaq: m.infaq,
                total: m.total,
              ));
      }
    }
    return AmalJariyahYear(
      scope: MemberScope.parse(body),
      earliestYear: int.tryParse(_text(body, ['earliest_year'])),
      months: months,
    );
  }
}
