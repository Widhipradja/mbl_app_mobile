import 'package:baraka_funds/screens/ringkasan/ringkasan_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/ringkasan_fixture.dart';

void main() {
  group('RingkasanData.parse', () {
    test('reads every section of a full answer', () {
      final d = RingkasanData.parse(ringkasanAnswer());
      expect(d.month, '2026-11');

      final f = d.finance.data!;
      expect(f.balance, 22863820);
      expect(f.income, 849953804);
      expect(f.expense, 827089984);
      expect(f.asOf, DateTime(2026, 9, 2));
      expect(f.recent.length, 2);
      expect(f.recent.first.description, 'Infaq Jumat');
      expect(f.recent.first.isIncome, isTrue);
      expect(f.recent.last.isIncome, isFalse);
      expect(f.recent.last.amount, 75001); // "75000.5" rounds to a rupiah
      expect(f.funds!.items.single.name, 'Operasional');
      expect(f.funds!.totalBalance, 1500);
      expect(f.fundsError, isNull);

      final m = d.members.data!;
      expect(m.total, 120);
      expect(m.active, 110);
      expect(m.newThisMonth, 3);
      expect(m.families, 40);
      expect(m.male, 60);
      expect(m.female, 60);
      expect(m.ageGroups.map((g) => g.label), ['0-17', '18-40']);

      expect(d.shodaqoh.data!.participants, 45);
      expect(d.shodaqoh.data!.totalMembers, 120);

      final j = d.jimpitan.data!;
      expect(j.total, 1250000);
      expect(j.setoranTotal, 1000000);
      expect(j.kasTotal, 250000);
      expect(j.contributors, 12);
      expect(j.items.length, 2);
      expect(j.items.first.isSetoran, isTrue);
      expect(j.items.first.date, DateTime(2026, 11, 20));
      expect(j.items.last.date, isNull); // undated
    });

    test('a section can be an error without taking the others down', () {
      final d = RingkasanData.parse(ringkasanAnswer(
        members: {'error': 'not_configured'},
        jimpitan: {'error': 'unavailable'},
      ));
      expect(d.members.error, 'not_configured');
      expect(d.members.data, isNull);
      expect(d.jimpitan.error, 'unavailable');
      expect(d.finance.hasData, isTrue);
      expect(d.shodaqoh.hasData, isTrue);
    });

    test('a closed finance gate is "forbidden", not a failure', () {
      final d = RingkasanData.parse(ringkasanAnswer(finance: {'error': 'forbidden'}));
      expect(d.finance.forbidden, isTrue);
      expect(d.finance.hasData, isFalse);
    });

    test('funds can fail alone: Saldo Kas stays', () {
      final d = RingkasanData.parse(ringkasanAnswer(finance: {
        'data': {
          'balance': '100',
          'income': '0',
          'expense': '0',
          'as_of': '2026-11-01',
          'recent_transactions': [],
          'funds': null,
          'funds_error': 'forbidden',
        },
      }));
      expect(d.finance.data!.balance, 100);
      expect(d.finance.data!.funds, isNull);
      expect(d.finance.data!.fundsError, 'forbidden');
    });

    test('a missing section or one of the wrong type counts as unavailable',
        () {
      final raw = ringkasanAnswer()..remove('members');
      raw['shodaqoh'] = 'oops';
      final d = RingkasanData.parse(raw);
      expect(d.members.error, 'unavailable');
      expect(d.shodaqoh.error, 'unavailable');
      expect(d.finance.hasData, isTrue);
    });

    test('absent fields read as zero and empty, never null', () {
      final d = RingkasanData.parse({
        'month': '2026-11',
        'finance': {'data': <String, dynamic>{}},
        'members': {'data': <String, dynamic>{}},
        'shodaqoh': {'data': <String, dynamic>{}},
        'jimpitan': {'data': <String, dynamic>{}},
      });
      expect(d.finance.data!.balance, 0);
      expect(d.finance.data!.recent, isEmpty);
      expect(d.finance.data!.asOf, isNull);
      expect(d.members.data!.ageGroups, isEmpty);
      expect(d.shodaqoh.data!.participants, 0);
      expect(d.jimpitan.data!.items, isEmpty);
    });

    test('an answer that is not an object is refused', () {
      expect(() => RingkasanData.parse('<html>'), throwsFormatException);
      expect(() => RingkasanData.parse(null), throwsFormatException);
    });
  });

  group('error text', () {
    test('every server code has a plain-language message', () {
      for (final code in [
        'forbidden',
        'not_configured',
        'timeout',
        'unavailable',
        'something_new',
      ]) {
        expect(ringkasanErrorText(code), isNotEmpty);
      }
      expect(ringkasanErrorText('not_configured'), contains('belum'));
    });
  });
}
