import 'package:baraka_funds/screens/profile/profile_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseBirthDate', () {
    test('reads a real YYYY-MM-DD date', () {
      expect(parseBirthDate('1990-05-17'), DateTime(1990, 5, 17));
      expect(parseBirthDate(' 1990-05-17 '), DateTime(1990, 5, 17));
      expect(parseBirthDate('2000-02-29'), DateTime(2000, 2, 29)); // leap year
    });

    test('empty or missing means none', () {
      expect(parseBirthDate(''), isNull);
      expect(parseBirthDate('   '), isNull);
      expect(parseBirthDate(null), isNull);
    });

    test('a date that does not exist is refused, not moved to another day', () {
      expect(parseBirthDate('1990-02-30'), isNull); // tryParse would say 2 Mar
      expect(parseBirthDate('1990-13-01'), isNull);
      expect(parseBirthDate('1900-02-29'), isNull); // 1900 was not a leap year
    });

    test('only the exact format counts', () {
      for (final bad in [
        '17-05-1990',
        '1990-5-7',
        'abc',
        '1990-05-17T00:00:00Z',
        '19900517',
      ]) {
        expect(parseBirthDate(bad), isNull, reason: bad);
      }
    });
  });

  group('birthDateParam', () {
    test('is YYYY-MM-DD with no time or zone', () {
      expect(birthDateParam(DateTime(1990, 5, 17)), '1990-05-17');
      expect(birthDateParam(DateTime(2001, 1, 2, 23, 59)), '2001-01-02');
      expect(birthDateParam(DateTime(1900, 1, 1)), '1900-01-01');
    });

    test('round-trips with parseBirthDate', () {
      final d = DateTime(1985, 12, 31);
      expect(parseBirthDate(birthDateParam(d)), d);
    });
  });
}
