/// Models of Ringkasan (the dashboard module), read from
/// `GET /api/m/v1/dashboard?month=YYYY-MM`: Saldo Kas, Keanggotaan, Shodaqoh
/// Bulanan and Jimpitan. Every section is `{data}` or `{error}` and fails on
/// its own; money is a decimal string ("25000"). Parsers are defensive:
/// absent fields read as 0 / empty, unknown ones are ignored.
library;

import '../../services/api_service.dart';

int _amt(dynamic v) => double.tryParse('${v ?? ''}')?.round() ?? 0;
int _int(dynamic v) => double.tryParse('${v ?? ''}')?.round() ?? 0;
String _s(dynamic v) => v?.toString().trim() ?? '';
Map<String, dynamic> _map(dynamic v) =>
    v is Map<String, dynamic> ? v : const <String, dynamic>{};
List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

/// `YYYY-MM-DD` (a longer timestamp is cut to its date) as a date, or null
/// when it is empty or not a real date.
DateTime? _day(dynamic v) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(_s(v));
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final date = DateTime(y, mo, d);
  return date.year == y && date.month == mo && date.day == d ? date : null;
}

/// The tabs of Ringkasan and the server module that gates each one (the
/// bootstrap `modules` map; the server decides per tenant and role, and
/// answers 403 / `{error: forbidden}` on its own). Keanggotaan has no module
/// of its own: it follows `dashboard`, which gates the whole screen.
enum RingkasanTab {
  keuangan('Keuangan', 'dashboard_finance'),
  shodaqoh('Shodaqoh', 'dashboard_shodaqoh'),
  keanggotaan('Keanggotaan', null),
  jimpitan('Jimpitan', 'jimpitan');

  const RingkasanTab(this.label, this.module);

  final String label;
  final String? module;
}

/// The tabs to show: those whose module is open for this account, minus the
/// ones the answer itself marked `forbidden` ([closed], when it is known).
/// [moduleOpen] answers for a module key.
List<RingkasanTab> ringkasanTabsFor(
  bool Function(String module) moduleOpen, {
  Set<RingkasanTab> closed = const {},
}) =>
    [
      for (final t in RingkasanTab.values)
        if ((t.module == null || moduleOpen(t.module!)) && !closed.contains(t))
          t,
    ];

/// One section of the answer: its data, or the reason it is missing.
class RingkasanSection<T> {
  const RingkasanSection({this.data, this.error});

  final T? data;

  /// `forbidden`, `not_configured`, `timeout` or `unavailable`.
  final String? error;

  bool get hasData => data != null && error == null;

  /// The account may not see this section (a closed module gate): not a
  /// failure, so the card is simply left out.
  bool get forbidden => error == 'forbidden';

  /// `{data: ...}` or `{error: ...}`; anything else is "unavailable".
  static RingkasanSection<T> read<T>(
      dynamic raw, T Function(Map<String, dynamic>) parse) {
    if (raw is! Map<String, dynamic>) {
      return const RingkasanSection(error: 'unavailable');
    }
    final err = _s(raw['error']);
    if (err.isNotEmpty) return RingkasanSection(error: err);
    final data = raw['data'];
    if (data is! Map<String, dynamic>) {
      return const RingkasanSection(error: 'unavailable');
    }
    return RingkasanSection(data: parse(data));
  }
}

/// A plain-language reason for a section error code.
String ringkasanErrorText(String? code) {
  switch (code) {
    case 'forbidden':
      return 'Tidak tersedia untuk akun Anda.';
    case 'not_configured':
      return 'Data ini belum diatur di server.';
    case 'timeout':
      return 'Server terlalu lama menjawab. Coba lagi.';
    case 'unavailable':
      return 'Layanan sedang tidak tersedia. Coba lagi.';
    default:
      return 'Data belum bisa dimuat. Coba lagi.';
  }
}

// ── Saldo Kas ───────────────────────────────────────────────────────────────

class RingkasanTrx {
  const RingkasanTrx({
    required this.id,
    required this.date,
    required this.description,
    required this.type,
    required this.amount,
  });

  factory RingkasanTrx.fromJson(Map<String, dynamic> j) => RingkasanTrx(
        id: _s(j['id']),
        date: _day(j['date']),
        description: _s(j['description']),
        type: _s(j['type']),
        amount: _amt(j['amount']),
      );

  final String id, description, type;
  final DateTime? date;
  final int amount;

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
}

class RingkasanFund {
  const RingkasanFund({
    required this.key,
    required this.name,
    required this.income,
    required this.expense,
    required this.balance,
  });

  factory RingkasanFund.fromJson(Map<String, dynamic> j) => RingkasanFund(
        key: _s(j['key']),
        name: _s(j['name']),
        income: _amt(j['income']),
        expense: _amt(j['expense']),
        balance: _amt(j['balance']),
      );

  final String key, name;
  final int income, expense, balance;
}

/// Dana per kategori, in the order finance-hub gave.
class RingkasanFunds {
  const RingkasanFunds({
    required this.asOf,
    required this.totalBalance,
    required this.items,
  });

  factory RingkasanFunds.fromJson(Map<String, dynamic> j) => RingkasanFunds(
        asOf: _day(j['as_of']),
        totalBalance: _amt(j['total_balance']),
        items: _list(j['items']).map(RingkasanFund.fromJson).toList(),
      );

  final DateTime? asOf;
  final int totalBalance;
  final List<RingkasanFund> items;
}

class RingkasanFinance {
  const RingkasanFinance({
    required this.balance,
    required this.income,
    required this.expense,
    required this.asOf,
    required this.recent,
    required this.funds,
    required this.fundsError,
  });

  factory RingkasanFinance.fromJson(Map<String, dynamic> j) {
    final funds = j['funds'];
    final fundsError = _s(j['funds_error']);
    return RingkasanFinance(
      balance: _amt(j['balance']),
      income: _amt(j['income']),
      expense: _amt(j['expense']),
      asOf: _day(j['as_of']),
      recent:
          _list(j['recent_transactions']).map(RingkasanTrx.fromJson).toList(),
      funds:
          funds is Map<String, dynamic> ? RingkasanFunds.fromJson(funds) : null,
      fundsError: fundsError.isEmpty ? null : fundsError,
    );
  }

  final int balance, income, expense;
  final DateTime? asOf;
  final List<RingkasanTrx> recent;

  /// Null when the list is not available; [fundsError] says why (`forbidden`
  /// hides it quietly, the rest are shown as a short note).
  final RingkasanFunds? funds;
  final String? fundsError;
}

// ── Keanggotaan ─────────────────────────────────────────────────────────────

class RingkasanAgeGroup {
  const RingkasanAgeGroup(this.label, this.total);
  final String label;
  final int total;
}

class RingkasanMembers {
  const RingkasanMembers({
    required this.total,
    required this.active,
    required this.newThisMonth,
    required this.families,
    required this.male,
    required this.female,
    required this.ageGroups,
  });

  factory RingkasanMembers.fromJson(Map<String, dynamic> j) {
    final gender = _map(j['gender']);
    return RingkasanMembers(
      total: _int(j['total_members']),
      active: _int(j['active_members']),
      newThisMonth: _int(j['new_this_month']),
      families: _int(j['total_families']),
      male: _int(gender['male']),
      female: _int(gender['female']),
      ageGroups: [
        for (final g in _list(j['age_groups']))
          RingkasanAgeGroup(_s(g['label']), _int(g['total'])),
      ],
    );
  }

  final int total, active, newThisMonth, families, male, female;
  final List<RingkasanAgeGroup> ageGroups;
}

// ── Shodaqoh Bulanan ────────────────────────────────────────────────────────

class RingkasanShodaqoh {
  const RingkasanShodaqoh(
      {required this.participants, required this.totalMembers});

  factory RingkasanShodaqoh.fromJson(Map<String, dynamic> j) =>
      RingkasanShodaqoh(
        participants: _int(j['participation_count']),
        totalMembers: _int(j['total_members']),
      );

  /// Members who gave this month, and all members (0 when not told).
  final int participants, totalMembers;
}

// ── Jimpitan ────────────────────────────────────────────────────────────────

class RingkasanJimpitanItem {
  const RingkasanJimpitanItem({
    required this.label,
    required this.date,
    required this.amount,
    required this.kind,
  });

  factory RingkasanJimpitanItem.fromJson(Map<String, dynamic> j) =>
      RingkasanJimpitanItem(
        label: _s(j['label']),
        date: _day(j['date']),
        amount: _amt(j['amount']),
        kind: _s(j['kind']),
      );

  final String label, kind;
  final DateTime? date;
  final int amount;

  /// A member's setoran, against an entry recorded in the cash book (`kas`).
  bool get isSetoran => kind == 'setoran';
}

class RingkasanJimpitan {
  const RingkasanJimpitan({
    required this.total,
    required this.setoranTotal,
    required this.kasTotal,
    required this.contributors,
    required this.items,
  });

  factory RingkasanJimpitan.fromJson(Map<String, dynamic> j) =>
      RingkasanJimpitan(
        total: _amt(j['total']),
        setoranTotal: _amt(j['setoran_total']),
        kasTotal: _amt(j['kas_total']),
        contributors: _int(j['contributors']),
        items: _list(j['items']).map(RingkasanJimpitanItem.fromJson).toList(),
      );

  /// The web's total: setoran plus the entries of the finance app.
  final int total, setoranTotal, kasTotal;

  /// Entries behind the total; [items] holds at most the newest 200.
  final int contributors;
  final List<RingkasanJimpitanItem> items;
}

// ── The answer ──────────────────────────────────────────────────────────────

class RingkasanData {
  const RingkasanData({
    required this.month,
    required this.finance,
    required this.members,
    required this.shodaqoh,
    required this.jimpitan,
  });

  /// Throws [FormatException] when [raw] is not an object (an HTML page from
  /// a proxy, say); a broken section only marks that section.
  factory RingkasanData.parse(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('dashboard');
    }
    return RingkasanData(
      month: _s(raw['month']),
      finance: RingkasanSection.read(raw['finance'], RingkasanFinance.fromJson),
      members: RingkasanSection.read(raw['members'], RingkasanMembers.fromJson),
      shodaqoh:
          RingkasanSection.read(raw['shodaqoh'], RingkasanShodaqoh.fromJson),
      jimpitan:
          RingkasanSection.read(raw['jimpitan'], RingkasanJimpitan.fromJson),
    );
  }

  final String month;
  final RingkasanSection<RingkasanFinance> finance;
  final RingkasanSection<RingkasanMembers> members;
  final RingkasanSection<RingkasanShodaqoh> shodaqoh;
  final RingkasanSection<RingkasanJimpitan> jimpitan;

  /// The tabs whose section the server refused for this account.
  Set<RingkasanTab> get forbiddenTabs => {
        if (finance.forbidden) RingkasanTab.keuangan,
        if (shodaqoh.forbidden) RingkasanTab.shodaqoh,
        if (members.forbidden) RingkasanTab.keanggotaan,
        if (jimpitan.forbidden) RingkasanTab.jimpitan,
      };
}

/// Loads Ringkasan of [month] (`YYYY-MM`) from the gateway.
Future<RingkasanData> loadRingkasan(String month) async =>
    RingkasanData.parse((await ApiService().getMobileDashboard(month)).data);
