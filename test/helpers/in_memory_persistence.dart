/// In-memory [PersistenceService] fake.
///
/// Lives in test/ because the app always uses the SharedPreferences-backed
/// implementation; this exists purely to exercise the interface contract
/// without touching platform channels.
library;

import 'package:app/services/persistence/persistence_service.dart';

class InMemoryPersistence implements PersistenceService {
  final Map<String, Object?> _store = {};

  /// Read-only view of the backing map, for assertions.
  Map<String, Object?> get rawStore => Map.unmodifiable(_store);

  /// Put a value in directly, bypassing the typed writers.
  void seed(String key, Object? value) {
    _store[key] = value;
  }

  @override
  Future<String?> readString(String key) async => _store[key] as String?;

  @override
  Future<void> writeString(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<List<String>?> readStringList(String key) async {
    final value = _store[key];
    if (value == null) return null;
    return List<String>.from(value as List);
  }

  @override
  Future<void> writeStringList(String key, List<String> value) async {
    _store[key] = List<String>.from(value);
  }

  @override
  Future<bool> readBool(String key, {bool defaultValue = false}) async =>
      _store[key] as bool? ?? defaultValue;

  @override
  Future<void> writeBool(String key, bool value) async {
    _store[key] = value;
  }

  @override
  Future<int> readInt(String key, {int defaultValue = 0}) async =>
      _store[key] as int? ?? defaultValue;

  @override
  Future<void> writeInt(String key, int value) async {
    _store[key] = value;
  }

  @override
  Future<double> readDouble(String key, {double defaultValue = 0.0}) async =>
      _store[key] as double? ?? defaultValue;

  @override
  Future<void> writeDouble(String key, double value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _store.clear();
  }

  @override
  Future<bool> containsKey(String key) async => _store.containsKey(key);

  @override
  Future<Set<String>> getKeys() async => _store.keys.toSet();
}
