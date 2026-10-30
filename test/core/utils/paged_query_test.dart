import 'package:attendix/core/utils/paged_query.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fetchInChunks', () {
    test('splits ids into chunks and keeps the order', () async {
      final calls = <List<int>>[];
      final result = await fetchInChunks<int, int>(
        List.generate(7, (i) => i),
        (chunk) async {
          calls.add(chunk);
          return chunk.map((i) => i * 10).toList();
        },
        chunkSize: 3,
      );
      expect(calls, [
        [0, 1, 2],
        [3, 4, 5],
        [6],
      ]);
      expect(result, [0, 10, 20, 30, 40, 50, 60]);
    });

    test('no ids: no request', () async {
      var called = false;
      final result = await fetchInChunks<int, int>([], (chunk) async {
        called = true;
        return chunk;
      });
      expect(result, isEmpty);
      expect(called, isFalse);
    });
  });
}
