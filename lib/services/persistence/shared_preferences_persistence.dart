/// SharedPreferences implementation of PersistenceService — Phase 8
///
/// Drop-in implementation backed by the shared_preferences package.
/// Swap this registration in the service locator to migrate to SQLite
/// or any other backend without touching business logic.
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/services/persistence/persistence_service.dart';

class SharedPreferencesPersistence implements PersistenceService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> _get() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<String?> readString(String key) async {
    final prefs = await _get();
    return prefs.getString(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    final prefs = await _get();
    await prefs.setString(key, value);
  }

  @override
  Future<List<String>?> readStringList(String key) async {
    final prefs = await _get();
    return prefs.getStringList(key);
  }

  @override
  Future<void> writeStringList(String key, List<String> value) async {
    final prefs = await _get();
    await prefs.setStringList(key, value);
  }

  @override
  Future<bool> readBool(String key, {bool defaultValue = false}) async {
    final prefs = await _get();
    return prefs.getBool(key) ?? defaultValue;
  }

  @override
  Future<void> writeBool(String key, bool value) async {
    final prefs = await _get();
    await prefs.setBool(key, value);
  }

  @override
  Future<int> readInt(String key, {int defaultValue = 0}) async {
    final prefs = await _get();
    return prefs.getInt(key) ?? defaultValue;
  }

  @override
  Future<void> writeInt(String key, int value) async {
    final prefs = await _get();
    await prefs.setInt(key, value);
  }

  @override
  Future<double> readDouble(String key, {double defaultValue = 0.0}) async {
    final prefs = await _get();
    return prefs.getDouble(key) ?? defaultValue;
  }

  @override
  Future<void> writeDouble(String key, double value) async {
    final prefs = await _get();
    await prefs.setDouble(key, value);
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await _get();
    await prefs.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    final prefs = await _get();
    await prefs.clear();
  }

  @override
  Future<bool> containsKey(String key) async {
    final prefs = await _get();
    return prefs.containsKey(key);
  }

  @override
  Future<Set<String>> getKeys() async {
    final prefs = await _get();
    return prefs.getKeys();
  }
}
