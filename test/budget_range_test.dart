import 'package:baraka_funds/screens/budget/budget_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BudgetRange', () {
    final payday = BudgetRange(DateTime(2026, 10, 25), DateTime(2026, 11, 24));

    test('a calendar month has no label', () {
      final r = BudgetRange.calendar(DateTime(2026, 11));
      expect(r.start, DateTime(2026, 11, 1));
      expect(r.end, DateTime(2026, 11, 30));
      expect(r.isCalendarMonth, isTrue);
      expect(r.label, isNull);
      expect(r.days, 30);
    });

    test('a payday period shows its dates, across month and year ends', () {
      expect(payday.isCalendarMonth, isFalse);
      expect(payday.label, '25 Okt – 24 Nov');
      expect(payday.days, 31);
      final newYear =
          BudgetRange(DateTime(2026, 12, 25), DateTime(2027, 1, 24));
      expect(newYear.label, '25 Des – 24 Jan');
      expect(newYear.days, 31);
    });

    test('February is a short period', () {
      final feb = BudgetRange(DateTime(2027, 1, 25), DateTime(2027, 2, 24));
      expect(feb.days, 31);
      final mar = BudgetRange(DateTime(2027, 2, 25), DateTime(2027, 3, 24));
      expect(mar.days, 28);
    });

    test('both ends belong to the period', () {
      expect(payday.contains(DateTime(2026, 10, 24)), isFalse);
      expect(payday.contains(DateTime(2026, 10, 25)), isTrue);
      expect(payday.contains(DateTime(2026, 11, 24, 23, 59)), isTrue);
      expect(payday.contains(DateTime(2026, 11, 25)), isFalse);
    });

    test('days counted stop at today while the period runs', () {
      expect(payday.daysCountedAt(DateTime(2026, 10, 25)), 1);
      expect(payday.daysCountedAt(DateTime(2026, 11, 5)), 12);
      expect(payday.daysCountedAt(DateTime(2026, 11, 24)), 31);
      // A past period counts all of it, a future one too.
      expect(payday.daysCountedAt(DateTime(2027, 1, 1)), 31);
      expect(payday.daysCountedAt(DateTime(2026, 9, 1)), 31);
    });
  });
}
