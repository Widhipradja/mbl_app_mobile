import 'package:baraka_funds/screens/budget/budget_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sharedRequest', () {
    test('completes with the result (it once waited on itself forever)',
        () async {
      final running = <String, Future<int>>{};
      final v = await sharedRequest(running, 'a', () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 42;
      }).timeout(const Duration(seconds: 2));
      expect(v, 42);
      expect(running, isEmpty);
    });

    test('callers at the same time share one request', () async {
      final running = <String, Future<int>>{};
      var calls = 0;
      Future<int> fetch() async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return calls;
      }

      final both = await Future.wait([
        sharedRequest(running, 'a', fetch),
        sharedRequest(running, 'a', fetch),
      ]).timeout(const Duration(seconds: 2));
      expect(both, [1, 1]);
      expect(calls, 1);
    });

    test('different keys run apart, and a later call asks again', () async {
      final running = <String, Future<int>>{};
      var calls = 0;
      Future<int> fetch() async => ++calls;

      await sharedRequest(running, 'a', fetch);
      await sharedRequest(running, 'b', fetch);
      await sharedRequest(running, 'a', fetch);
      expect(calls, 3);
    });

    test('a failure reaches the caller and is not kept', () async {
      final running = <String, Future<int>>{};
      Future<int> boom() async => throw StateError('server down');

      await expectLater(
          sharedRequest(running, 'a', boom).timeout(const Duration(seconds: 2)),
          throwsA(isA<StateError>()));
      expect(running, isEmpty);
      expect(await sharedRequest(running, 'a', () async => 7), 7);
    });
  });
}
