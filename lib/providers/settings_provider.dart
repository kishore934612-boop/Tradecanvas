import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:app/utils/haptics.dart';
// Phase 8: Persistence layer
import 'package:app/core/di/service_locator.dart';
import 'package:app/services/persistence/persistence_service.dart';
import 'package:app/services/persistence/shared_preferences_persistence.dart';

/// App-wide preferences: theme mode, haptics toggle and the starting balance
/// used when resetting the account.
class SettingsProvider extends ChangeNotifier {
  static const String _storageKey = '@papertrade_settings';

  ThemeMode _themeMode = ThemeMode.system;
  bool _hapticsEnabled = true;
  double _startingBalance = 100000.0;

  SettingsProvider() {
    _load();
  }

  ThemeMode get themeMode => _themeMode;
  bool get hapticsEnabled => _hapticsEnabled;
  double get startingBalance => _startingBalance;

  static const List<double> balanceOptions = [10000.0, 50000.0, 100000.0, 500000.0, 1000000.0];

  PersistenceService get _persistence =>
      serviceLocator.isRegistered<PersistenceService>()
          ? serviceLocator<PersistenceService>()
          : SharedPreferencesPersistence();

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _save();
    notifyListeners();
  }

  void setHapticsEnabled(bool value) {
    _hapticsEnabled = value;
    Haptics.enabled = value;
    _save();
    notifyListeners();
  }

  void setStartingBalance(double value) {
    _startingBalance = value;
    _save();
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      final raw = await _persistence.readString(_storageKey);
      if (raw != null) {
        final Map<String, dynamic> state = jsonDecode(raw);
        _themeMode = ThemeMode.values[(state['themeMode'] as int?) ?? ThemeMode.system.index];
        _hapticsEnabled = (state['hapticsEnabled'] as bool?) ?? true;
        _startingBalance = (state['startingBalance'] as num?)?.toDouble() ?? 100000.0;
        Haptics.enabled = _hapticsEnabled;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      await _persistence.writeString(
        _storageKey,
        jsonEncode({
          'themeMode':       _themeMode.index,
          'hapticsEnabled':  _hapticsEnabled,
          'startingBalance': _startingBalance,
        }),
      );
    } catch (_) {}
  }
}
