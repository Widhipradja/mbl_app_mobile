import 'package:baraka_funds/screens/budget/budget_data.dart';
import 'package:flutter_test/flutter_test.dart';

BudgetCategoryLine _line(String name, int limit, int spent,
        {bool income = false}) =>
    BudgetCategoryLine(
      categoryId: name,
      name: name,
      isIncome: income,
      limit: limit,
      spent: spent,
      remaining: limit - spent,
      percent: limit == 0 ? 0 : spent * 100 / limit,
    );

List<String> _names(List<BudgetCategoryLine> lines) =>
    [for (final l in lines) l.name];

BudgetSummary _summary(List<BudgetCategoryLine> lines) => BudgetSummary(
    income: 0, expense: 0, net: 0, limitTotal: 0, categories: lines);

void main() {
  group('BudgetSummary.budgeted', () {
    test('budgets still running come first, most used first', () {
      final s = _summary([
        _line('Makan', 1000, 300), // 30%
        _line('Transport', 1000, 900), // 90%
        _line('Pulsa', 1000, 500), // 50%
      ]);
      expect(_names(s.budgeted), ['Transport', 'Pulsa', 'Makan']);
    });

    test('used-up and overspent budgets go to the bottom', () {
      final s = _summary([
        _line('Lewat', 1000, 1200), // 120%
        _line('Makan', 1000, 300), // 30%
        _line('Habis', 1000, 1000), // 100%
        _line('Transport', 1000, 900), // 90%
      ]);
      expect(_names(s.budgeted), ['Transport', 'Makan', 'Lewat', 'Habis']);
    });

    test('income and categories without a budget are left out', () {
      final s = _summary([
        _line('Gaji', 1000, 500, income: true),
        _line('Tanpa anggaran', 0, 500),
        _line('Makan', 1000, 300),
      ]);
      expect(_names(s.budgeted), ['Makan']);
    });
  });
}
