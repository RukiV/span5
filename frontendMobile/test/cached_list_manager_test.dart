import 'package:flutter_test/flutter_test.dart';
import 'package:fbs/services/cached_list_manager.dart';

void main() {
  group('CachedListManager', () {
    test('fetch vult die notifier en values', () async {
      final manager = CachedListManager<int>(load: () async => [1, 2, 3]);

      expect(manager.isLoaded, isFalse);
      await manager.fetch();

      expect(manager.isLoaded, isTrue);
      expect(manager.values, [1, 2, 3]);
      expect(manager.notifier.value, [1, 2, 3]);
      expect(manager.lastError, isNull);
    });

    test('herlaai vervang vorige items', () async {
      final manager = CachedListManager<int>(load: () async => [1, 2, 3]);

      await manager.fetch();
      expect(manager.values, [1, 2, 3]);

      final manager2 = CachedListManager<int>(load: () async => [4, 5]);
      await manager2.fetch();

      expect(manager2.values, [4, 5]);
      expect(manager2.notifier.value, [4, 5]);
    });

    test("herlaai stel 'n vars notifier-momentopname", () async {
      final manager = CachedListManager<int>(load: () async => [1, 2, 3]);

      await manager.fetch();
      final firstSnapshot = manager.notifier.value;

      await manager.fetch();

      expect(identical(firstSnapshot, manager.notifier.value), isFalse);
    });

    test('mislukte laai laat die kas onaangeraak en stel lastError', () async {
      final manager = CachedListManager<int>(
        load: () async => throw Exception('netwerk fout'),
      );

      await manager.fetch();

      expect(manager.isLoaded, isFalse);
      expect(manager.values, isEmpty);
      expect(manager.notifier.value, isEmpty);
      expect(manager.lastError, isNotNull);
    });

    test("mislukking ná 'n sukses behou die vorige items", () async {
      var fail = false;
      final manager = CachedListManager<int>(load: () async {
        if (fail) throw Exception('netwerk fout');
        return [1, 2];
      });

      await manager.fetch();
      fail = true;
      await manager.fetch();

      expect(manager.values, [1, 2]);
      expect(manager.notifier.value, [1, 2]);
      expect(manager.lastError, isNotNull);
    });

    test("notifier kry 'n vars momentopname (List.from, nie dieselfde kas)",
        () async {
      final manager = CachedListManager<int>(load: () async => [1, 2, 3]);

      await manager.fetch();
      final snapshot = manager.notifier.value;
      final cache = manager.values;

      expect(snapshot, cache);
      expect(identical(snapshot, cache), isFalse);
    });

    test('ensureLoaded laai net wanneer die kas leeg is', () async {
      var loads = 0;
      final manager = CachedListManager<int>(load: () async {
        loads++;
        return [7];
      });

      await manager.ensureLoaded();
      expect(loads, 1);
      await manager.ensureLoaded();
      expect(loads, 1);
      expect(manager.isLoaded, isTrue);
    });

    test('gelyktydige fetch-oproepe deel een in-vlug versoek', () async {
      var loads = 0;
      final manager = CachedListManager<int>(load: () async {
        loads++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return [loads];
      });

      await Future.wait([
        manager.fetch(),
        manager.fetch(),
        manager.fetch(),
      ]);

      expect(loads, 1);
      expect(manager.values, [1]);
      expect(manager.notifier.value, [1]);
      expect(manager.lastError, isNull);
    });

    test('in-vlug-guard word ná voltooiing vrygestel', () async {
      var loads = 0;
      final manager = CachedListManager<int>(load: () async {
        loads++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return [loads];
      });

      await manager.fetch();
      expect(loads, 1);

      await manager.fetch();
      expect(loads, 2);
      expect(manager.values, [2]);
    });

    test('values is onveranderlik', () async {
      final manager = CachedListManager<int>(load: () async => [1]);

      await manager.fetch();

      expect(() => manager.values.add(2), throwsUnsupportedError);
    });

    test('ondersteun verskillende entiteitstipes', () async {
      final strings = CachedListManager<String>(load: () async => ['a', 'b']);
      final records = CachedListManager<({int id, String name})>(
        load: () async => [(id: 1, name: 'een')],
      );

      await strings.fetch();
      await records.fetch();

      expect(strings.values, ['a', 'b']);
      expect(records.values.single.name, 'een');
    });
  });
}
