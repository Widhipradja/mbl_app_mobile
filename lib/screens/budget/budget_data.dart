import 'package:dio/dio.dart';

import '../../services/api_service.dart';

int _amt(dynamic v) => double.tryParse('${v ?? ''}')?.round() ?? 0;
String _s(dynamic v) => v?.toString().trim() ?? '';
List<Map<String, dynamic>> _list(dynamic d) =>
    d is List ? d.whereType<Map<String, dynamic>>().toList() : const [];

/// `YYYY-MM`
String budgetPeriod(DateTime m) =>
    '${m.year}-${m.month.toString().padLeft(2, '0')}';

String budgetDay(DateTime d) =>
    '${budgetPeriod(d)}-${d.day.toString().padLeft(2, '0')}';

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
  });

  factory BudgetTxn.fromJson(Map<String, dynamic> j) {
    // `trx_date` is a date at midnight UTC: keep the calendar day.
    final d = DateTime.tryParse(_s(j['trx_date']));
    return BudgetTxn(
      id: _s(j['id']),
      categoryId: _s(j['category_id']),
      categoryName: _s(j['category_name']),
      amount: _amt(j['amount']),
      date: d == null ? DateTime.now() : DateTime(d.year, d.month, d.day),
      description: _s(j['description']),
    );
  }

  final String id, categoryId, categoryName, description;
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

  /// Expense categories with a budget, most used first.
  List<BudgetCategoryLine> get budgeted =>
      categories.where((c) => !c.isIncome && c.budgeted).toList()
        ..sort((a, b) => b.percent.compareTo(a.percent));

  /// Spent in the categories that have a budget (what [limitTotal] is
  /// measured against).
  int get spentInBudget => budgeted.fold(0, (s, c) => s + c.spent);
}

/// What the budget screens need from the backend.
class BudgetRepository {
  Future<BudgetSummary> summary(DateTime month) async {
    final d = (await ApiService().getBudgetSummary(budgetPeriod(month))).data;
    final m = d is Map<String, dynamic> ? d : <String, dynamic>{};
    return BudgetSummary(
      income: _amt(m['income']),
      expense: _amt(m['expense']),
      net: _amt(m['net']),
      limitTotal: _amt(m['limit_total']),
      categories:
          _list(m['categories']).map(BudgetCategoryLine.fromJson).toList(),
    );
  }

  /// Transactions of [month], newest first.
  Future<List<BudgetTxn>> transactions(DateTime month,
      {String? categoryId, int limit = 200}) async {
    final last = DateTime(month.year, month.month + 1, 0);
    final r = await ApiService().getBudgetTransactions(
      from: budgetDay(DateTime(month.year, month.month, 1)),
      to: budgetDay(last),
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
          required DateTime date}) =>
      {
        'amount': '$amount.00',
        'category_id': categoryId,
        'description': description,
        'trx_date': budgetDay(date),
        'source': 'app',
      };

  Future<void> addTransaction(
          {required int amount,
          required String categoryId,
          required String description,
          required DateTime date}) =>
      ApiService().createBudgetTransaction(_txnBody(
          amount: amount,
          categoryId: categoryId,
          description: description,
          date: date));

  Future<void> updateTransaction(String id,
          {required int amount,
          required String categoryId,
          required String description,
          required DateTime date}) =>
      ApiService().updateBudgetTransaction(
          id,
          _txnBody(
              amount: amount,
              categoryId: categoryId,
              description: description,
              date: date));

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
    }
    if (e.response == null) {
      return 'Tidak bisa terhubung ke server. Periksa koneksi Anda.';
    }
  }
  return 'Gagal memproses. Coba lagi.';
}
