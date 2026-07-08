/// In-Memory implementation of PersistenceService — Phase 8
///
/// Used in unit tests and as a fallback when SharedPreferences is unavailable.
/// All data is lost when the process exits.
library;

import 'package:app/services/persistence/persistence_service.dart';

class InMemoryPersistence implements PersistenceService {
  final Map<String, Object> _store = {};

  @override
  Future<String?> readString(String key) async =>
      _store[key] as String?;

  @override
  Future<void> writeString(String key, String value) async =>
      _store[key] = value;

  @override
  Future<List<String>?> readStringList(String key) async {
    final value = _store[key] as List<String>?;
    return value != null ? List<String>.from(value) : null;
  }

  @override
  Future<void> writeStringList(String key, List<String> value) async =>
      _store[key] = List<String>.from(value);

  @override
  Future<bool> readBool(String key, {bool defaultValue = false}) async =>
      (_store[key] as bool?) ?? defaultValue;

  @override
  Future<void> writeBool(String key, bool value) async =>
      _store[key] = value;

  @override
  Future<int> readInt(String key, {int defaultValue = 0}) async =>
      (_store[key] as int?) ?? defaultValue;

  @override
  Future<void> writeInt(String key, int value) async =>
      _store[key] = value;

  @override
  Future<double> readDouble(String key, {double defaultValue = 0.0}) async =>
      (_store[key] as double?) ?? defaultValue;

  @override
  Future<void> writeDouble(String key, double value) async =>
      _store[key] = value;

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();

  @override
  Future<bool> containsKey(String key) async => _store.containsKey(key);

  @override
  Future<Set<String>> getKeys() async => _store.keys.toSet();

  /// Test helper: access raw store for assertions.
  Map<String, Object> get rawStore => Map.unmodifiable(_store);

  /// Test helper: seed data directly.
  void seed(String key, Object value) => _store[key] = value;
}
