import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../services/api_service.dart';
import '../savings/ledger_widgets.dart' show monthNames;

int _amt(dynamic v) => double.tryParse('${v ?? ''}')?.round() ?? 0;
String _s(dynamic v) => v?.toString().trim() ?? '';
List<Map<String, dynamic>> _list(dynamic d) =>
    d is List ? d.whereType<Map<String, dynamic>>().toList() : const [];

/// The calendar day of a stored date. A date entered in the app is midnight
/// UTC (keep that day); one the server stamped with the current time
/// (no date given, e.g. from the web) is read in the phone's own zone.
DateTime? _calendarDay(DateTime? d) {
  if (d == null) return null;
  final midnightUtc = d.isUtc && d.hour == 0 && d.minute == 0 && d.second == 0;
  final day = midnightUtc ? d : d.toLocal();
  return DateTime(day.year, day.month, day.day);
}

/// `YYYY-MM`
String budgetPeriod(DateTime m) =>
    '${m.year}-${m.month.toString().padLeft(2, '0')}';

String budgetDay(DateTime d) =>
    '${budgetPeriod(d)}-${d.day.toString().padLeft(2, '0')}';

/// `YYYY-MM-DD` as a date, or null when it is empty or not a real date.
DateTime? _day(dynamic v) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(_s(v));
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  final date = DateTime(y, mo, d);
  return date.year == y && date.month == mo && date.day == d ? date : null;
}

/// The dates a `month` key covers for this user, as the server says
/// (`period_start` / `period_end`, both inclusive). With payday on the 25th,
/// `2026-11` is 25 Oct - 24 Nov. The app never works the dates out itself.
class BudgetRange {
  const BudgetRange(this.start, this.end);

  /// The whole calendar month: what every user had before periods.
  factory BudgetRange.calendar(DateTime month) => BudgetRange(
      DateTime(month.year, month.month, 1),
      DateTime(month.year, month.month + 1, 0));

  final DateTime start, end;

  bool get isCalendarMonth =>
      start.day == 1 &&
      end.year == start.year &&
      end.month == start.month &&
      end.day == DateTime(start.year, start.month + 1, 0).day;

  bool contains(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  static int _between(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;

  /// Days in the period.
  int get days => _between(start, end) + 1;

  /// Days counted for averages: up to [today] while the period is running.
  int daysCountedAt(DateTime today) =>
      contains(today) ? _between(start, today) + 1 : days;

  /// "25 Okt - 24 Nov"; null for a plain calendar month (the title says it).
  String? get label {
    if (isCalendarMonth) return null;
    String short(DateTime d) =>
        '${d.day} ${monthNames[d.month - 1].substring(0, 3)}';
    return '${short(start)} – ${short(end)}';
  }
}

/// `GET /budget/settings`.
class BudgetSettings {
  const BudgetSettings({
    required this.startDay,
    required this.currentMonth,
    this.currentRange,
  });

  /// 1-28; 1 is every month from its first day.
  final int startDay;

  /// The `month` key of the period running today: where the screens open.
  final DateTime currentMonth;
  final BudgetRange? currentRange;
}

class BudgetCategory {
  const BudgetCategory({
    required this.id,
    required this.name,
    required this.isIncome,
    required this.active,
  });

  factory BudgetCategory.fromJson(Map<String, dynamic> j) => BudgetCategory(
        id: _s(j['id']),
        name: _s(j['name']),
        isIncome: _s(j['type']) == 'income',
        active: j['is_active'] != false,
      );

  final String id, name;
  final bool isIncome, active;
}

class BudgetTxn {
  const BudgetTxn({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.date,
    required this.description,
    this.source = 'app',
    this.transcript = '',
    this.categoryType = '',
  });

  factory BudgetTxn.fromJson(Map<String, dynamic> j) {
    final d = _calendarDay(DateTime.tryParse(_s(j['trx_date'])));
    return BudgetTxn(
      id: _s(j['id']),
      categoryId: _s(j['category_id']),
      categoryName: _s(j['category_name']),
      amount: _amt(j['amount']),
      date: d ?? DateTime.now(),
      description: _s(j['description']),
      source: _s(j['source']).isEmpty ? 'app' : _s(j['source']),
      transcript: _s(j['transcript']),
      categoryType: _s(j['category_type']),
    );
  }

  final String id, categoryId, categoryName, description;

  /// `app`, `voice` or `web`; [transcript] is only set for `voice`.
  final String source, transcript;

  bool get isVoice => source == 'voice';

  /// `income` or `expense` as the server stored it with the transaction, so
  /// the sign is known even after its category was deleted; empty when the
  /// transaction has no category.
  final String categoryType;

  /// [categoryType] as income (true), expense (false) or unknown (null).
  bool? get typeIncome => categoryType == 'income'
      ? true
      : categoryType == 'expense'
          ? false
          : null;
  final int amount;
  final DateTime date;
}

/// One category's line of the month summary.
class BudgetCategoryLine {
  const BudgetCategoryLine({
    required this.categoryId,
    required this.name,
    required this.isIncome,
    required this.limit,
    required this.spent,
    required this.remaining,
    required this.percent,
  });

  factory BudgetCategoryLine.fromJson(Map<String, dynamic> j) =>
      BudgetCategoryLine(
        categoryId: _s(j['category_id']),
        name: _s(j['category_name']),
        isIncome: _s(j['type']) == 'income',
        limit: _amt(j['limit']),
        spent: _amt(j['spent']),
        remaining: _amt(j['remaining']),
        percent: double.tryParse('${j['percent'] ?? ''}') ?? 0,
      );

  final String categoryId, name;
  final bool isIncome;

  /// 0 means no budget set for this category.
  final int limit, spent;

  /// Negative when over budget.
  final int remaining;

  /// May be above 100.
  final double percent;

  bool get budgeted => limit > 0;
  bool get over => budgeted && remaining < 0;
}

class BudgetSummary {
  const BudgetSummary({
    required this.income,
    required this.expense,
    required this.net,
    required this.limitTotal,
    required this.categories,
  });

  final int income, expense, net, limitTotal;
  final List<BudgetCategoryLine> categories;

  /// Expense categories with a budget: the ones still running first, most
  /// used first; the used-up and overspent ones (100% or more) at the bottom,
  /// as nothing is left to watch there.
  List<BudgetCategoryLine> get budgeted {
    bool done(BudgetCategoryLine c) => c.over || c.percent >= 100;
    return categories.where((c) => !c.isIncome && c.budgeted).toList()
      ..sort((a, b) {
        final byDone = (done(a) ? 1 : 0) - (done(b) ? 1 : 0);
        return byDone != 0 ? byDone : b.percent.compareTo(a.percent);
      });
  }

  /// Spent in the categories that have a budget (what [limitTotal] is
  /// measured against).
  int get spentInBudget => budgeted.fold(0, (s, c) => s + c.spent);
}

/// The server heard the recording but found no category (422). The amount
/// and type were read, so the user only picks a category.
class BudgetVoiceUnreadable implements Exception {
  const BudgetVoiceUnreadable({
    required this.message,
    required this.transcript,
    required this.amount,
    required this.isIncome,
    required this.candidates,
    this.description = '',
    this.amountSuspect = false,
  });

  final String message, transcript;

  /// The description cleaned of the amount; empty when the server gave none.
  final String description;

  /// "amount looks wrong": the amount read does not fit what was said, so it
  /// is not offered and the user types it.
  final bool amountSuspect;

  /// 0 when no amount could be read.
  final int amount;
  final bool isIncome;

  /// Category names the server thinks it could be.
  final List<String> candidates;
}

/// Which budgets of the earlier period can be copied into this one: those
/// that had an amount ([previous], by category id), for rows that are on
/// screen and still empty ([current] holds each row's amount, 0 for empty).
/// What the user already filled in is never replaced.
Map<String, int> limitsToCopy({
  required Map<String, int> previous,
  required Map<String, int> current,
}) =>
    {
      for (final e in previous.entries)
        if (e.value > 0 && current.containsKey(e.key) && current[e.key] == 0)
          e.key: e.value,
    };

/// Runs [fetch] once per [key] at a time: a second caller while it is running
/// gets the same future. The entry is dropped when it ends, whether it
/// succeeded or failed.
///
/// The cleanup must not return a value: `whenComplete` waits for a future its
/// callback returns, and `Map.remove` would hand back this very future, which
/// then waits for itself and never completes.
Future<T> sharedRequest<T>(
    Map<String, Future<T>> running, String key, Future<T> Function() fetch) {
  return running[key] ??= fetch().whenComplete(() {
    running.remove(key);
  });
}

/// What the budget screens need from the backend.
class BudgetRepository {
  int _startDay = 1;
  DateTime? _currentMonth;

  /// Period dates the server has told, by `month` key.
  final _ranges = <String, BudgetRange>{};
  final _summaries = <String, Future<BudgetSummary>>{};

  /// Payday of the user as last read; 1 until [settings] has answered (also
  /// for a server that does not know periods yet).
  int get startDay => _startDay;

  /// The `month` key of the period running today.
  DateTime get currentMonth {
    final now = DateTime.now();
    return _currentMonth ?? DateTime(now.year, now.month);
  }

  /// What [month] covers: the server's dates once heard, else the calendar
  /// month.
  BudgetRange rangeOf(DateTime month) =>
      _ranges[budgetPeriod(month)] ?? BudgetRange.calendar(month);

  BudgetSettings _readSettings(dynamic data) {
    final m = data is Map<String, dynamic> ? data : <String, dynamic>{};
    final day = m['period_start_day'];
    final cur = m['current_period'];
    final curMap =
        cur is Map<String, dynamic> ? cur : const <String, dynamic>{};
    final month = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(_s(curMap['month']));
    final start = _day(curMap['start']);
    final end = _day(curMap['end']);
    _startDay = day is int && day >= 1 && day <= 28 ? day : 1;
    final now = DateTime.now();
    _currentMonth = month == null
        ? DateTime(now.year, now.month)
        : DateTime(int.parse(month[1]!), int.parse(month[2]!));
    final range = start != null && end != null ? BudgetRange(start, end) : null;
    if (range != null) _ranges[budgetPeriod(_currentMonth!)] = range;
    return BudgetSettings(
        startDay: _startDay, currentMonth: _currentMonth!, currentRange: range);
  }

  Future<BudgetSettings> settings() async =>
      _readSettings((await ApiService().getBudgetSettings()).data);

  /// Saves the payday. It applies to every period, so what was known of the
  /// old ones is dropped.
  Future<BudgetSettings> setPeriodStartDay(int day) async {
    final data = (await ApiService().putBudgetSettings(day)).data;
    _ranges.clear();
    _summaries.clear();
    return _readSettings(data);
  }

  /// One request per month at a time: the screens ask for the summary and
  /// for the transactions together, and the latter needs the dates.
  Future<BudgetSummary> summary(DateTime month) => sharedRequest(
      _summaries, budgetPeriod(month), () => _fetchSummary(month));

  Future<BudgetSummary> _fetchSummary(DateTime month) async {
    final d = (await ApiService().getBudgetSummary(budgetPeriod(month))).data;
    final m = d is Map<String, dynamic> ? d : <String, dynamic>{};
    final start = _day(m['period_start']), end = _day(m['period_end']);
    if (start != null && end != null) {
      _ranges[budgetPeriod(month)] = BudgetRange(start, end);
    }
    return BudgetSummary(
      income: _amt(m['income']),
      expense: _amt(m['expense']),
      net: _amt(m['net']),
      limitTotal: _amt(m['limit_total']),
      categories:
          _list(m['categories']).map(BudgetCategoryLine.fromJson).toList(),
    );
  }

  /// Transactions of the period [month] stands for, newest first.
  Future<List<BudgetTxn>> transactions(DateTime month,
      {String? categoryId, int limit = 200}) async {
    // The dates come from the server; for a payday other than the 1st they
    // are learnt from the summary of that month first.
    if (!_ranges.containsKey(budgetPeriod(month)) && _startDay != 1) {
      try {
        await summary(month);
      } catch (e) {
        debugPrint('budget period lookup error: $e');
      }
    }
    final range = rangeOf(month);
    final r = await ApiService().getBudgetTransactions(
      from: budgetDay(range.start),
      to: budgetDay(range.end),
      categoryId: categoryId,
      limit: limit,
    );
    return _list(r.data).map(BudgetTxn.fromJson).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<BudgetCategory>> categories() async =>
      _list((await ApiService().getBudgetCategories()).data)
          .map(BudgetCategory.fromJson)
          .toList();

  Map<String, dynamic> _txnBody(
          {required int amount,
          required String categoryId,
          required String description,
          required DateTime date,
          String source = 'app'}) =>
      {
        'amount': '$amount.00',
        'category_id': categoryId,
        'description': description,
        'trx_date': budgetDay(date),
        'source': source,
      };

  Future<void> addTransaction(
          {required int amount,
          required String categoryId,
          required String description,
          required DateTime date,
          String source = 'app'}) =>
      ApiService().createBudgetTransaction({
        ..._txnBody(
            amount: amount,
            categoryId: categoryId,
            description: description,
            date: date,
            source: source),
      });

  /// The transaction is created by the server on 200. Throws
  /// [BudgetVoiceUnreadable] on 422.
  Future<BudgetTxn> voice(List<int> bytes, String name) async {
    try {
      final r = await ApiService().sendBudgetVoice(bytes, name);
      return BudgetTxn.fromJson(
          r.data is Map<String, dynamic> ? r.data as Map<String, dynamic> : {});
    } on DioException catch (e) {
      final d = e.response?.data;
      if (e.response?.statusCode == 422 && d is Map) {
        final suspect = _s(d['error']).startsWith('amount looks wrong');
        throw BudgetVoiceUnreadable(
          message: _s(d['error']),
          transcript: _s(d['transcript']),
          description: _s(d['description']),
          amountSuspect: suspect,
          amount: suspect ? 0 : _amt(d['amount']),
          isIncome: _s(d['trx_type']) == 'income',
          candidates: [
            if (d['candidates'] is List)
              for (final c in d['candidates'] as List) _s(c),
          ],
        );
      }
      rethrow;
    }
  }

  /// PUT sends every field again, so the stored [source] goes back as it
  /// was: editing a voice entry must not turn it into an app one.
  Future<void> updateTransaction(String id,
          {required int amount,
          required String categoryId,
          required String description,
          required DateTime date,
          String source = 'app'}) =>
      ApiService().updateBudgetTransaction(
          id,
          _txnBody(
              amount: amount,
              categoryId: categoryId,
              description: description,
              date: date,
              source: source));

  Future<void> deleteTransaction(String id) =>
      ApiService().deleteBudgetTransaction(id);

  Future<BudgetCategory> addCategory(String name, bool income) async {
    final r = await ApiService()
        .createBudgetCategory(name, income ? 'income' : 'expense');
    return BudgetCategory.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> updateCategory(BudgetCategory c,
          {String? name, bool? income, bool? active}) =>
      ApiService().updateBudgetCategory(c.id, name ?? c.name,
          (income ?? c.isIncome) ? 'income' : 'expense', active ?? c.active);

  Future<void> deleteCategory(String id) =>
      ApiService().deleteBudgetCategory(id);

  /// `category_id → amount` of the month.
  Future<Map<String, int>> limits(DateTime month) async => {
        for (final l in _list(
            (await ApiService().getBudgetLimits(budgetPeriod(month))).data))
          _s(l['category_id']): _amt(l['amount']),
      };

  Future<void> setLimit(String categoryId, int amount, DateTime month) =>
      ApiService()
          .putBudgetLimit(categoryId, '$amount.00', budgetPeriod(month));
}

final budgetRepo = BudgetRepository();

/// A message for the user, by status.
String budgetError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    final reason = data is Map ? _s(data['error']) : '';
    switch (e.response?.statusCode) {
      case 400:
        if (reason.contains('amount')) return 'Nominal harus lebih dari Rp 0.';
        if (reason.contains('category')) return 'Kategori tidak ditemukan.';
        return 'Data ditolak server. Periksa isian Anda.';
      case 401:
        return 'Sesi Anda berakhir. Silakan masuk lagi.';
      case 403:
        return 'Modul budget tidak aktif untuk akun Anda.';
      case 404:
        return 'Data tidak ditemukan. Mungkin sudah dihapus.';
      case 413:
        return 'Rekaman terlalu panjang (maksimal 10 MB). Rekam lebih singkat.';
      case 500:
        return 'Server sedang bermasalah. Coba lagi.';
      case 502:
      case 504:
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
