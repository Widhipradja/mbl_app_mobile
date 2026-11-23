import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../savings/ledger_widgets.dart' show monthNames;

int _amt(dynamic v) => double.tryParse('${v ?? ''}')?.round() ?? 0;
String _s(dynamic v) => v?.toString().trim() ?? '';
DateTime _date(dynamic v) =>
    DateTime.tryParse(_s(v))?.toLocal() ?? DateTime.now();
String _period(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

/// One transaction as the finance screens show it. Amounts are whole rupiah.
class FinanceTxn {
  const FinanceTxn({
    required this.id,
    required this.title,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.date,
    this.status = '',
    this.tags = '',
  });

  /// An item of `GET finance/transactions`.
  factory FinanceTxn.fromJson(Map<String, dynamic> j) => FinanceTxn(
        id: _s(j['id']),
        title: _s(j['description']).isNotEmpty
            ? _s(j['description'])
            : _s(j['category']),
        amount: _amt(j['amount']),
        isIncome: _s(j['trx_type']) == 'income',
        category: _s(j['category']),
        date: _date(j['requested_date']),
        status: _s(j['status']),
        tags: _s(j['tags']),
      );

  final String id;
  final String title;
  final int amount;
  final bool isIncome;
  final String category;
  final DateTime date;
  final String status;

  /// e.g. `#voice`.
  final String tags;

  bool get isVoice => tags.contains('#voice');
}

/// One month of the ledger: the balances answer plus the transaction list.
class FinanceMonth {
  const FinanceMonth({
    required this.month,
    required this.txns,
    required this.opening,
    required this.income,
    required this.expense,
    required this.closing,
    required this.difference,
  });

  final DateTime month;

  /// Newest first.
  final List<FinanceTxn> txns;
  final int opening, income, expense, closing;

  /// Ledger movement the register rows do not explain; should be 0.
  final int difference;

  int get net => income - expense;

  /// Expense per category, largest first.
  List<MapEntry<String, int>> get expenseByCategory {
    final m = <String, int>{};
    for (final t in txns.where((t) => !t.isIncome)) {
      m[t.category] = (m[t.category] ?? 0) + t.amount;
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }
}

/// An account a transaction is booked on (`finance/lookups/accounts`).
class FinanceAccount {
  const FinanceAccount({
    required this.id,
    required this.name,
    required this.isIncome,
  });

  final String id, name;

  /// `REVENUE` accounts are income, `EXPENSE` accounts are expense.
  final bool isIncome;
}

/// A transaction waiting for the treasurer (KU), or already decided.
class FinanceSubmission {
  const FinanceSubmission({
    required this.id,
    required this.submittedBy,
    required this.amount,
    required this.description,
    required this.accountName,
    required this.isIncome,
    required this.transcript,
    required this.status,
    required this.date,
  });

  factory FinanceSubmission.fromJson(Map<String, dynamic> j) =>
      FinanceSubmission(
        id: _s(j['id']),
        submittedBy: _s(j['submitted_by']),
        amount: _amt(j['amount']),
        description: _s(j['description']),
        accountName: _s(j['account_name']),
        isIncome: _s(j['trx_type']) == 'income',
        transcript: _s(j['transcript']),
        status: _s(j['status']),
        date: _date(j['requested_date']),
      );

  final String id, submittedBy, description, accountName, transcript, status;
  final int amount;
  final bool isIncome;
  final DateTime date;
}

class BookLine {
  const BookLine({
    required this.date,
    required this.category,
    required this.description,
    required this.income,
    required this.expense,
    required this.balance,
  });

  final DateTime date;
  final String category, description;
  final int income, expense, balance;
}

class BookGroup {
  const BookGroup({
    required this.label,
    required this.opening,
    required this.income,
    required this.expense,
    required this.closing,
    required this.lines,
  });

  final String label;
  final int opening, income, expense, closing;
  final List<BookLine> lines;
}

/// `finance/daily-bookkeeping`: lines per report group with running balance.
class FinanceBookkeeping {
  const FinanceBookkeeping({
    required this.groups,
    required this.totalOpening,
    required this.totalClosing,
    required this.difference,
  });

  final List<BookGroup> groups;
  final int totalOpening, totalClosing, difference;
}

/// The recording was heard but not understood (422): [transcript] is what
/// whisper heard, [candidates] the categories that could be meant.
class VoiceUnreadable implements Exception {
  const VoiceUnreadable(this.message, this.transcript, this.candidates);
  final String message, transcript;
  final List<String> candidates;
}

/// What the finance screens need from the backend.
abstract class FinanceRepository {
  Future<FinanceMonth> month(DateTime month);
  Future<FinanceBookkeeping> bookkeeping(DateTime month);
  Future<List<FinanceAccount>> accounts();
  Future<List<FinanceSubmission>> pending();

  /// A manual submission; the same [idempotencyKey] is safe to resend.
  Future<FinanceSubmission> submit({
    required String idempotencyKey,
    required FinanceAccount account,
    required int amount,
    required String description,
    required DateTime date,
    String transcript = '',
  });

  /// Throws [VoiceUnreadable] on 422.
  Future<FinanceSubmission> voice(List<int> bytes, String name);

  /// [action]: approve, reject (needs [reason]) or cancel.
  Future<FinanceSubmission> decide(String id, String action, {String? reason});
}

class ApiFinanceRepository implements FinanceRepository {
  static List<Map<String, dynamic>> _list(dynamic d) =>
      d is List ? d.whereType<Map<String, dynamic>>().toList() : const [];

  @override
  Future<FinanceMonth> month(DateTime month) async {
    final api = ApiService();
    final p = _period(month);
    final r = await Future.wait([
      api.getFinanceBalances(p),
      api.getFinanceTransactions(p),
    ]);
    final b = r[0].data is Map<String, dynamic>
        ? r[0].data as Map<String, dynamic>
        : <String, dynamic>{};
    final txns = _list(r[1].data).map(FinanceTxn.fromJson).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return FinanceMonth(
      month: DateTime(month.year, month.month),
      txns: txns,
      opening: _amt(b['opening_balance']),
      income: _amt(b['inflow']),
      expense: _amt(b['outflow']),
      closing: _amt(b['closing_balance']),
      difference: _amt(b['difference']),
    );
  }

  @override
  Future<FinanceBookkeeping> bookkeeping(DateTime month) async {
    final r = await ApiService().getFinanceBookkeeping(_period(month));
    final d = r.data is Map<String, dynamic>
        ? r.data as Map<String, dynamic>
        : <String, dynamic>{};
    BookGroup group(Map<String, dynamic> g) => BookGroup(
          label: _s(g['label']).isNotEmpty ? _s(g['label']) : _s(g['key']),
          opening: _amt(g['opening_balance']),
          income: _amt(g['total_income']),
          expense: _amt(g['total_expense']),
          closing: _amt(g['closing_balance']),
          lines: [
            for (final l in _list(g['lines']))
              BookLine(
                date: _date(l['date']),
                category: _s(l['category']),
                description: _s(l['description']),
                income: _amt(l['income']),
                expense: _amt(l['expense']),
                balance: _amt(l['balance']),
              ),
          ],
        );
    final ungrouped = d['ungrouped'];
    return FinanceBookkeeping(
      groups: [
        ..._list(d['groups']).map(group),
        if (ungrouped is Map<String, dynamic>) group(ungrouped),
      ],
      totalOpening: _amt(d['total_opening']),
      totalClosing: _amt(d['total_closing']),
      difference: _amt(d['difference']),
    );
  }

  @override
  Future<List<FinanceAccount>> accounts() async {
    final r = await ApiService().getFinanceAccounts();
    return [
      for (final a in _list(r.data))
        if (_s(a['id']).isNotEmpty && _s(a['name']).isNotEmpty)
          FinanceAccount(
            id: _s(a['id']),
            name: _s(a['name']),
            isIncome: _s(a['account_type']).toUpperCase() == 'REVENUE',
          ),
    ];
  }

  @override
  Future<List<FinanceSubmission>> pending() async {
    final r = await ApiService().getFinancePending();
    return _list(r.data).map(FinanceSubmission.fromJson).toList();
  }

  FinanceSubmission _one(Response r) => FinanceSubmission.fromJson(
      r.data is Map<String, dynamic> ? r.data as Map<String, dynamic> : {});

  @override
  Future<FinanceSubmission> submit({
    required String idempotencyKey,
    required FinanceAccount account,
    required int amount,
    required String description,
    required DateTime date,
    String transcript = '',
  }) async {
    final d = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return _one(await ApiService().submitFinanceTransaction({
      'idempotency_key': idempotencyKey,
      'account_id': account.id,
      'amount': '$amount.00',
      'description': description,
      'requested_date': d,
      if (transcript.isNotEmpty) 'transcript': transcript,
    }));
  }

  @override
  Future<FinanceSubmission> voice(List<int> bytes, String name) async {
    try {
      return _one(await ApiService().sendVoiceTransaction(bytes, name));
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 422 && data is Map) {
        throw VoiceUnreadable(
          _s(data['error']),
          _s(data['transcript']),
          [
            if (data['candidates'] is List)
              for (final c in data['candidates'] as List) _s(c),
          ],
        );
      }
      rethrow;
    }
  }

  @override
  Future<FinanceSubmission> decide(String id, String action,
          {String? reason}) async =>
      _one(await ApiService()
          .decideFinanceSubmission(id, action, reason: reason));
}

/// Swap for a fake in tests.
FinanceRepository financeRepo = ApiFinanceRepository();

/// A message for the user, by status (the server's own text is English).
String financeError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    final reason = data is Map ? _s(data['error']) : '';
    switch (e.response?.statusCode) {
      case 400:
        if (reason.contains('reason')) return 'Alasan penolakan wajib diisi.';
        return 'Data ditolak server. Periksa isian Anda.';
      case 401:
        return 'Sesi Anda berakhir. Silakan masuk lagi.';
      case 403:
        return 'Hanya bendahara (KU) yang bisa melakukan ini.';
      case 404:
        return 'Data tidak ditemukan.';
      case 409:
        return 'Pengajuan ini sudah diputuskan.';
      case 413:
        return 'Rekaman terlalu panjang (maksimal 10 MB). Rekam lebih singkat.';
      case 502:
        return 'Layanan transkripsi sedang tidak tersedia. Coba lagi.';
      case 503:
        return 'Fitur suara belum dikonfigurasi di server.';
    }
    if (e.response == null) {
      return 'Tidak bisa terhubung ke server. Periksa koneksi Anda.';
    }
  }
  return 'Gagal memproses. Coba lagi.';
}

// ---------------------------------------------------------------- formatting

String thousands(int v) => v
    .abs()
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

/// "Rp 1.250.000"
String rp(int v) => '${v < 0 ? '-' : ''}Rp ${thousands(v)}';

/// "8,2 jt", "350 rb": compact, for tight places.
String rpShort(int v) {
  final a = v.abs();
  if (a >= 1000000) {
    final s = (a / 1000000).toStringAsFixed(1).replaceAll('.', ',');
    return '${s.endsWith(',0') ? s.substring(0, s.length - 2) : s} jt';
  }
  if (a >= 1000) return '${(a / 1000).round()} rb';
  return '$a';
}

String monthLabel(DateTime m) => '${monthNames[m.month - 1]} ${m.year}';

const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

String dateLabel(DateTime d) =>
    '${_days[d.weekday - 1]}, ${d.day} ${monthNames[d.month - 1]} ${d.year}';

String dateShort(DateTime d) =>
    '${d.day} ${monthNames[d.month - 1].substring(0, 3)} ${d.year}';

/// Digits only, shown with thousands dots while typing.
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue v) {
    final digits = v.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = thousands(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
