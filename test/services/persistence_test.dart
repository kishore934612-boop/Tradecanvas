/// Unit tests for the Persistence Layer — Phase 8
///
/// Tests run entirely against InMemoryPersistence, so no platform channel
/// or SharedPreferences plugin is needed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/persistence/persistence_service.dart';
import 'package:app/services/persistence/in_memory_persistence.dart';

void main() {
  late InMemoryPersistence store;

  setUp(() => store = InMemoryPersistence());

  // ────────────────────────────────────────────────────────────
  // STRING
  // ────────────────────────────────────────────────────────────
  group('String', () {
    test('readString returns null when key absent', () async {
      expect(await store.readString('x'), isNull);
    });

    test('writeString / readString round-trips', () async {
      await store.writeString('key', 'hello world');
      expect(await store.readString('key'), equals('hello world'));
    });

    test('overwrite replaces value', () async {
      await store.writeString('k', 'first');
      await store.writeString('k', 'second');
      expect(await store.readString('k'), equals('second'));
    });

    test('empty string is stored and retrieved', () async {
      await store.writeString('k', '');
      expect(await store.readString('k'), equals(''));
    });

    test('JSON payload survives round-trip', () async {
      const json = '{"balance":100000,"wins":5,"symbol":"BTC"}';
      await store.writeString('state', json);
      expect(await store.readString('state'), equals(json));
    });
  });

  // ────────────────────────────────────────────────────────────
  // STRING LIST
  // ────────────────────────────────────────────────────────────
  group('StringList', () {
    test('readStringList returns null when absent', () async {
      expect(await store.readStringList('list'), isNull);
    });

    test('writeStringList / readStringList round-trips', () async {
      await store.writeStringList('list', ['a', 'b', 'c']);
      expect(await store.readStringList('list'), equals(['a', 'b', 'c']));
    });

    test('empty list round-trips', () async {
      await store.writeStringList('list', []);
      expect(await store.readStringList('list'), isEmpty);
    });

    test('retrieved list is a copy — mutations do not affect store', () async {
      await store.writeStringList('list', ['x']);
      final retrieved = await store.readStringList('list');
      retrieved!.add('y');
      expect(await store.readStringList('list'), equals(['x']));
    });
  });

  // ────────────────────────────────────────────────────────────
  // BOOL
  // ────────────────────────────────────────────────────────────
  group('Bool', () {
    test('returns defaultValue when absent', () async {
      expect(await store.readBool('flag', defaultValue: true), isTrue);
      expect(await store.readBool('flag'), isFalse); // default = false
    });

    test('write true / read true', () async {
      await store.writeBool('flag', true);
      expect(await store.readBool('flag'), isTrue);
    });

    test('write false / read false', () async {
      await store.writeBool('flag', false);
      expect(await store.readBool('flag'), isFalse);
    });
  });

  // ────────────────────────────────────────────────────────────
  // INT
  // ────────────────────────────────────────────────────────────
  group('Int', () {
    test('returns defaultValue when absent', () async {
      expect(await store.readInt('n', defaultValue: 42), equals(42));
      expect(await store.readInt('n'), equals(0));
    });

    test('write / read round-trips', () async {
      await store.writeInt('n', 999);
      expect(await store.readInt('n'), equals(999));
    });

    test('negative int round-trips', () async {
      await store.writeInt('n', -1);
      expect(await store.readInt('n'), equals(-1));
    });
  });

  // ────────────────────────────────────────────────────────────
  // DOUBLE
  // ────────────────────────────────────────────────────────────
  group('Double', () {
    test('returns defaultValue when absent', () async {
      expect(await store.readDouble('d', defaultValue: 3.14), closeTo(3.14, 0.001));
      expect(await store.readDouble('d'), closeTo(0.0, 0.001));
    });

    test('write / read round-trips', () async {
      await store.writeDouble('d', 100000.99);
      expect(await store.readDouble('d'), closeTo(100000.99, 0.001));
    });
  });

  // ────────────────────────────────────────────────────────────
  // DELETE
  // ────────────────────────────────────────────────────────────
  group('Delete', () {
    test('delete removes a key', () async {
      await store.writeString('k', 'value');
      await store.delete('k');
      expect(await store.readString('k'), isNull);
    });

    test('delete on non-existent key does not throw', () async {
      await expectLater(store.delete('missing'), completes);
    });

    test('deleteAll clears all keys', () async {
      await store.writeString('a', '1');
      await store.writeInt('b', 2);
      await store.writeBool('c', true);
      await store.deleteAll();
      expect(await store.readString('a'), isNull);
      expect(await store.readInt('b'), equals(0));
      expect(await store.readBool('c'), isFalse);
    });
  });

  // ────────────────────────────────────────────────────────────
  // CONTAINS / KEYS
  // ────────────────────────────────────────────────────────────
  group('containsKey / getKeys', () {
    test('containsKey false when absent', () async {
      expect(await store.containsKey('x'), isFalse);
    });

    test('containsKey true after write', () async {
      await store.writeString('k', 'v');
      expect(await store.containsKey('k'), isTrue);
    });

    test('containsKey false after delete', () async {
      await store.writeString('k', 'v');
      await store.delete('k');
      expect(await store.containsKey('k'), isFalse);
    });

    test('getKeys returns all written keys', () async {
      await store.writeString('a', '1');
      await store.writeInt('b', 2);
      await store.writeBool('c', true);
      final keys = await store.getKeys();
      expect(keys, containsAll(['a', 'b', 'c']));
    });

    test('getKeys empty when store empty', () async {
      expect(await store.getKeys(), isEmpty);
    });

    test('getKeys after deleteAll is empty', () async {
      await store.writeString('a', 'v');
      await store.deleteAll();
      expect(await store.getKeys(), isEmpty);
    });
  });

  // ────────────────────────────────────────────────────────────
  // RAW STORE (InMemory test helper)
  // ────────────────────────────────────────────────────────────
  group('InMemoryPersistence helpers', () {
    test('rawStore reflects written values', () async {
      await store.writeString('x', 'val');
      expect(store.rawStore['x'], equals('val'));
    });

    test('seed populates store for tests', () {
      store.seed('balance', 50000.0);
      expect(store.rawStore['balance'], equals(50000.0));
    });

    test('rawStore is unmodifiable', () {
      expect(
        () => store.rawStore['k'] = 'v',
        throwsUnsupportedError,
      );
    });
  });

  // ────────────────────────────────────────────────────────────
  // INTERFACE COMPLETENESS
  // ────────────────────────────────────────────────────────────
  group('PersistenceService interface', () {
    test('InMemoryPersistence implements PersistenceService', () {
      expect(store, isA<PersistenceService>());
    });

    test('multiple independent instances are isolated', () async {
      final store2 = InMemoryPersistence();
      await store.writeString('k', 'store1');
      await store2.writeString('k', 'store2');
      expect(await store.readString('k'),  equals('store1'));
      expect(await store2.readString('k'), equals('store2'));
    });
  });

  // ────────────────────────────────────────────────────────────
  // SIMULATED TRADING STATE ROUND-TRIP
  // ────────────────────────────────────────────────────────────
  group('Trading state round-trip', () {
    test('full state JSON survives write/read cycle', () async {
      const key = '@tradeverse_state_v2';
      const state = '{'
          '"startingCapital":100000,'
          '"balance":95000,'
          '"positions":[],'
          '"trades":[{"id":"1","symbol":"BTC","pnl":500}],'
          '"wins":3,"losses":1'
          '}';

      await store.writeString(key, state);
      final retrieved = await store.readString(key);
      expect(retrieved, equals(state));
    });

    test('state deleted on account reset', () async {
      const key = '@tradeverse_state_v2';
      await store.writeString(key, '{"balance":50000}');
      await store.delete(key);
      expect(await store.readString(key), isNull);
    });

    test('settings and trading state are independent keys', () async {
      await store.writeString('@papertrade_settings', '{"themeMode":1}');
      await store.writeString('@tradeverse_state_v2', '{"balance":100000}');
      await store.delete('@tradeverse_state_v2');
      expect(await store.readString('@papertrade_settings'), isNotNull);
      expect(await store.readString('@tradeverse_state_v2'), isNull);
    });
  });
}
