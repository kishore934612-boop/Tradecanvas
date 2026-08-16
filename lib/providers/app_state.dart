/// App-wide state: onboarding, chart preferences, and theme.
///
/// Preferences live in key-value storage; watchlists, drawings and chart state
/// live in local SQLite database.
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:app/core/di/service_locator.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/engine/session_overlay.dart';
import 'package:app/models/user_profile.dart';
import 'package:app/services/persistence/persistence_service.dart';
import 'package:app/services/persistence/shared_preferences_persistence.dart';
import 'package:app/services/persistence/sqlite_db_helper.dart';

class AppState extends ChangeNotifier {
  static const String _key = '@charty_appstate';

  UserProfile _profile = UserProfile();

  /// Only [ThemeMode.light] or [ThemeMode.dark] — there is no "system" option
  /// or accent-color choice; each mode maps to exactly one fixed palette
  /// (light = white/blue, dark = black/green).
  ThemeMode _themeMode = ThemeMode.dark;
  bool _loaded = false;

  bool _isAuthenticated = false;
  String? _username;
  String? _email;
  String? _photoUrl;
  String? _lastAuthError;

  /// Symbol the Chart tab reopens on.
  String _lastSymbol = 'BTCUSDT';

  /// Symbol previewed on the Dashboard tab. Unlike [_lastSymbol], selecting
  /// this needs to visibly update the dashboard immediately, so its setter
  /// notifies listeners.
  String _dashboardSymbol = 'BTCUSDT';

  AppState() {
    _load();
  }

  UserProfile get profile => _profile;
  ThemeMode get themeMode => _themeMode;
  bool get loaded => _loaded;
  bool get onboarded => _profile.onboarded;

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  String? get email => _email;
  String? get photoUrl => _photoUrl;
  String? get lastAuthError => _lastAuthError;
  String get lastSymbol => _lastSymbol;
  String get dashboardSymbol => _dashboardSymbol;

  PersistenceService get _persistence =>
      serviceLocator.isRegistered<PersistenceService>()
          ? serviceLocator<PersistenceService>()
          : SharedPreferencesPersistence();

  // ==========================================================
  // PERSISTENCE
  // ==========================================================

  Future<void> _load() async {
    try {
      final raw = await _persistence.readString(_key);
      if (raw != null) {
        final state = jsonDecode(raw) as Map<String, dynamic>;
        _profile = UserProfile.fromJson(
            (state['profile'] as Map<String, dynamic>?) ?? const {});
        final storedModeIndex = (state['themeMode'] as int?) ?? ThemeMode.dark.index;
        _themeMode = storedModeIndex == ThemeMode.light.index
            ? ThemeMode.light
            : ThemeMode.dark;
        _username = state['username'] as String?;
        _email = state['email'] as String?;
        _photoUrl = state['photoUrl'] as String?;
        _lastSymbol = state['lastSymbol'] as String? ?? 'BTCUSDT';
        _dashboardSymbol = state['dashboardSymbol'] as String? ?? 'BTCUSDT';
      }
    } catch (e) {
      Logger.instance.warning('AppState load failed: $e');
    }

    _isAuthenticated = false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await _persistence.writeString(
        _key,
        jsonEncode({
          'profile': _profile.toJson(),
          'themeMode': _themeMode.index,
          'username': _username,
          'email': _email,
          'photoUrl': _photoUrl,
          'lastSymbol': _lastSymbol,
          'dashboardSymbol': _dashboardSymbol,
        }),
      );
    } catch (e) {
      Logger.instance.warning('AppState save failed: $e');
    }
  }

  // ==========================================================
  // AUTH (Local mode)
  // ==========================================================

  Future<void> signOut() async {
    _isAuthenticated = false;
    _username = null;
    _email = null;
    _photoUrl = null;
    await _save();
    notifyListeners();
  }

  /// Explicit destructive reset, triggered only from Settings behind a
  /// confirmation dialog.
  Future<void> clearLocalData() async {
    try {
      await SqliteDbHelper.instance.clearAllData();
    } catch (e) {
      Logger.instance.error('Clearing local data failed: $e');
    }
    notifyListeners();
  }

  // ==========================================================
  // PREFERENCES
  // ==========================================================

  void completeOnboarding() {
    _profile.onboarded = true;
    _save();
    notifyListeners();
  }

  void setTraderType(String type) {
    _profile.traderType = type;
    _save();
    notifyListeners();
  }

  void setFavoriteCoins(List<String> coins) {
    _profile.favoriteCoins = coins.take(5).toList();
    _save();
    notifyListeners();
  }

  /// Only [ThemeMode.light] and [ThemeMode.dark] are supported.
  void setThemeMode(ThemeMode mode) {
    if (mode != ThemeMode.light && mode != ThemeMode.dark) return;
    _themeMode = mode;
    _save();
    notifyListeners();
  }

  void setHaptics(bool enabled) {
    _profile.hapticsEnabled = enabled;
    _save();
    notifyListeners();
  }

  void setDefaultTimeframe(String apiValue) {
    _profile.defaultTimeframe = apiValue;
    _save();
    notifyListeners();
  }

  void setChartTypePref(ChartTypePref type) {
    _profile.chartType = type;
    _save();
    notifyListeners();
  }

  void setGridStyle(GridStylePref style) {
    _profile.gridStyle = style;
    _save();
    notifyListeners();
  }

  void setGridVisibility(GridVisibilityPref v) {
    _profile.gridVisibility = v;
    _save();
    notifyListeners();
  }

  void setGridDensity(GridDensityPref d) {
    _profile.gridDensity = d;
    _save();
    notifyListeners();
  }



  void setCandleColors({int? bullish, int? bearish}) {
    if (bullish != null) _profile.customBullishColorValue = bullish;
    if (bearish != null) _profile.customBearishColorValue = bearish;
    _save();
    notifyListeners();
  }

  void setShowVolume(bool show) {
    _profile.showVolume = show;
    _save();
    notifyListeners();
  }

  void setRightOffsetPercent(double percent) {
    _profile.rightOffsetPercent = percent;
    _save();
    notifyListeners();
  }



  void setSessionConfig(SessionOverlayConfig config) {
    _profile.sessionConfig = config;
    _save();
    notifyListeners();
  }

  /// Remember the last charted symbol. Deliberately does not notify: this is
  /// written while a chart opens and would otherwise rebuild the whole tree.
  void setLastSymbol(String symbol) {
    if (_lastSymbol == symbol) return;
    _lastSymbol = symbol;
    _save();
  }

  /// Change the symbol previewed on the Dashboard tab. Notifies, since the
  /// Dashboard screen depends on this to know which coin to show.
  void setDashboardSymbol(String symbol) {
    if (_dashboardSymbol == symbol) return;
    _dashboardSymbol = symbol;
    _save();
    notifyListeners();
  }

  void setDefaultIndicators(Set<String> names) {
    _profile.defaultIndicators = names;
    _save();
    notifyListeners();
  }

  /// Up to 3 tools shown on the chart's quick-action toolbar.
  void setFavoriteDrawingTools(List<String> toolNames) {
    _profile.favoriteDrawingTools = toolNames.take(3).toList();
    _save();
    notifyListeners();
  }

  void setCrosshairMode(CrosshairMode mode) {
    _profile.crosshairMode = mode;
    _save();
    notifyListeners();
  }

  void setCrosshairShowLabels(bool show) {
    _profile.crosshairShowLabels = show;
    _save();
    notifyListeners();
  }

  void setAutoScale(bool enabled) {
    _profile.autoScale = enabled;
    _save();
    notifyListeners();
  }

  void setChartLocked(bool locked) {
    _profile.chartLocked = locked;
    _save();
    notifyListeners();
  }

  void addCustomPriceLine(double price) {
    if (_profile.customPriceLines.length >= 10) return;
    _profile.customPriceLines.add(price);
    _save();
    notifyListeners();
  }

  void removeCustomPriceLine(double price) {
    _profile.customPriceLines.remove(price);
    _save();
    notifyListeners();
  }

  void clearCustomPriceLines() {
    _profile.customPriceLines.clear();
    _save();
    notifyListeners();
  }

  Future<void> updateDisplayName(String displayName) async {
    _username = displayName;
    await _save();
    notifyListeners();
  }

  /// Reset preferences and show onboarding again. Does not delete chart data.
  Future<void> resetPreferences() async {
    _profile = UserProfile();
    _themeMode = ThemeMode.dark;
    await _save();
    notifyListeners();
  }
}
