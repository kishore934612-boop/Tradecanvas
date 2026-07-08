/// Persistence Service — Phase 8
///
/// Abstract interface over any key-value store.
/// Business logic only depends on this interface, never on
/// SharedPreferences, SQLite, Isar, or any other backend directly.
///
/// Current implementation: SharedPreferencesPersistence.
/// Future: swap the registered singleton for SQLite / Isar / Supabase
///         without touching any business-logic code.
library;

// ============================================================
// INTERFACE
// ============================================================

abstract class PersistenceService {
  /// Read a JSON string by key. Returns null if absent.
  Future<String?> readString(String key);

  /// Write a JSON string. Overwrites any existing value.
  Future<void> writeString(String key, String value);

  /// Read a list of strings. Returns null if absent.
  Future<List<String>?> readStringList(String key);

  /// Write a list of strings.
  Future<void> writeStringList(String key, List<String> value);

  /// Read a boolean flag. Returns [defaultValue] if absent.
  Future<bool> readBool(String key, {bool defaultValue = false});

  /// Write a boolean flag.
  Future<void> writeBool(String key, bool value);

  /// Read an integer. Returns [defaultValue] if absent.
  Future<int> readInt(String key, {int defaultValue = 0});

  /// Write an integer.
  Future<void> writeInt(String key, int value);

  /// Read a double. Returns [defaultValue] if absent.
  Future<double> readDouble(String key, {double defaultValue = 0.0});

  /// Write a double.
  Future<void> writeDouble(String key, double value);

  /// Delete a key.
  Future<void> delete(String key);

  /// Delete all stored data (used for account reset).
  Future<void> deleteAll();

  /// Check whether a key exists.
  Future<bool> containsKey(String key);

  /// Return all stored keys.
  Future<Set<String>> getKeys();
}
