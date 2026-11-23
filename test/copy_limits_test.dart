import 'package:baraka_funds/screens/budget/budget_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('limitsToCopy', () {
    test('copies what the earlier period had into empty rows', () {
      final copy = limitsToCopy(
        previous: {'makan': 1500000, 'transport': 400000},
        current: {'makan': 0, 'transport': 0},
      );
      expect(copy, {'makan': 1500000, 'transport': 400000});
    });

    test('keeps what is already filled in', () {
      final copy = limitsToCopy(
        previous: {'makan': 1500000, 'transport': 400000},
        current: {'makan': 2000000, 'transport': 0},
      );
      expect(copy, {'transport': 400000});
    });

    test('skips categories without a budget before, or no longer listed', () {
      final copy = limitsToCopy(
        previous: {'makan': 0, 'lama': 900000, 'transport': 400000},
        current: {'makan': 0, 'transport': 0},
      );
      // "makan" had 0 (no budget), "lama" is not a row on screen any more.
      expect(copy, {'transport': 400000});
    });

    test('nothing to copy when the earlier period had no budgets', () {
      expect(limitsToCopy(previous: const {}, current: {'makan': 0}), isEmpty);
    });
  });
}
