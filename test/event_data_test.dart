import 'package:baraka_funds/screens/events/event_data.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException failure(int status, Map<String, dynamic> body) {
  final req = RequestOptions(path: '/api/m/v1/events');
  return DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: status, data: body),
  );
}

void main() {
  group('EventLookups', () {
    test('keeps the server order, drops blanks and repeats', () {
      final l = EventLookups.fromJson({
        'categories': [
          {'value': 'Pengajian', 'order': 2},
          {'value': 'Umum', 'order': 1},
          {'value': 'Umum', 'order': 3},
          {'value': '  ', 'order': 4},
        ],
        'locations': [
          {'value': 'Masjid Al-Hidayah', 'order': 1},
        ],
      });
      expect(l.categories, ['Umum', 'Pengajian']);
      expect(l.locations, ['Masjid Al-Hidayah']);
    });

    test('ties in order keep the sequence they came in', () {
      final l = EventLookups.fromJson({
        'categories': [
          {'value': 'B', 'order': 1},
          {'value': 'A', 'order': 1},
        ],
      });
      expect(l.categories, ['B', 'A']);
    });

    test('empty lists, missing keys and plain texts are fine', () {
      expect(EventLookups.fromJson({'categories': [], 'locations': []}).categories,
          isEmpty);
      expect(EventLookups.fromJson(null).locations, isEmpty);
      expect(EventLookups.fromJson({'categories': ['Umum', 'Generus']}).categories,
          ['Umum', 'Generus']);
    });
  });

  group('errors', () {
    test('an unknown category is told apart and its text is shown', () {
      final e = failure(422,
          {'error': 'Kategori tidak dikenal. Pilih dari daftar kategori.'});
      expect(eventFailure(e), EventFailure.badCategory);
      expect(eventError(e),
          'Kategori tidak dikenal. Pilih dari daftar kategori.');
    });

    test('writer and provisioning refusals do not look alike', () {
      expect(
          eventFailure(failure(403, {
            'error': 'not allowed to manage events',
            'code': 'not_event_writer'
          })),
          EventFailure.notWriter);
      expect(
          eventFailure(failure(403, {
            'error': 'account is not authorized by event-reminder',
            'code': 'upstream_unauthorized'
          })),
          EventFailure.notProvisioned);
      expect(eventError(failure(403, {'error': 'tenant required'})),
          'Akun Anda belum terhubung ke organisasi.');
    });

    test('404, 413 and the 5xx family have their own text', () {
      expect(eventFailure(failure(404, {'error': 'event not found'})),
          EventFailure.notFound);
      expect(eventError(failure(413, {})), contains('terlalu besar'));
      for (final code in [502, 503, 504]) {
        expect(eventError(failure(code, {})), contains('coba lagi'));
      }
    });

    test('a 400 rule of event-reminder is relayed as it is', () {
      expect(
          eventError(failure(400, {'error': 'invalid event: end before start'})),
          'invalid event: end before start');
    });
  });
}
