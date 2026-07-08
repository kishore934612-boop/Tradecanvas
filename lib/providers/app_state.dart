import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:app/models/user_profile.dart';
import 'package:app/utils/formatters.dart';
// Phase 8: Persistence layer
import 'package:app/core/di/service_locator.dart';
import 'package:app/services/persistence/persistence_service.dart';
import 'package:app/services/persistence/shared_preferences_persistence.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:app/core/logging/logger.dart';

/// Holds onboarding state, the user profile, app-wide settings (theme, currency,
/// haptics). Persisted independently of trading data so a reset of the account
/// does not wipe the user's preferences.
class AppState extends ChangeNotifier {
  static const String _key = '@tradeverse_appstate';

  UserProfile _profile = UserProfile();
  ThemeMode _themeMode = ThemeMode.system;
  int _themeIndex = 0;
  bool _loaded = false;

  bool _isAuthenticated = false;
  String? _username;
  String? _email;
  bool _isProUser = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  AppState() {
    _load();
  }

  UserProfile get profile => _profile;
  ThemeMode get themeMode => _themeMode;
  int get themeIndex => _themeIndex;
  bool get loaded => _loaded;
  bool get onboarded => _profile.onboarded;

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  String? get email => _email;
  bool get isProUser => _isProUser;

  PersistenceService get _persistence =>
      serviceLocator.isRegistered<PersistenceService>()
          ? serviceLocator<PersistenceService>()
          : SharedPreferencesPersistence();

  Future<void> _load() async {
    try {
      final raw = await _persistence.readString(_key);
      if (raw != null) {
        final Map<String, dynamic> state = jsonDecode(raw);
        _profile = UserProfile.fromJson(state['profile'] ?? {});
        _themeMode = ThemeMode.values[(state['themeMode'] ?? ThemeMode.system.index) as int];
        _themeIndex = (state['themeIndex'] ?? 0) as int;
        _isAuthenticated = state['isAuthenticated'] ?? false;
        _username = state['username'];
        _email = state['email'];
        _isProUser = state['isProUser'] ?? false;
        setAppCurrency(_profile.currencySymbol);
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await _persistence.writeString(
        _key,
        jsonEncode({
          'profile':    _profile.toJson(),
          'themeMode':  _themeMode.index,
          'themeIndex': _themeIndex,
          'isAuthenticated': _isAuthenticated,
          'username': _username,
          'email': _email,
          'isProUser': _isProUser,
        }),
      );
    } catch (_) {}
  }

  // --- REAL GOOGLE SIGN-IN ---
  Future<bool> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _isAuthenticated = true;
        _username = account.displayName ?? 'Google Trader';
        _email = account.email;
        _profile.onboarded = true; // assume onboarded on sign in
        await _save();
        notifyListeners();
        return true;
      }
    } catch (e) {
      Logger.instance.error('Real Google sign in failed: $e');
    }
    return false;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    _isAuthenticated = false;
    _username = null;
    _email = null;
    _isProUser = false; // reset premium
    _profile.onboarded = false; // go back to onboarding setup or main screen
    await _save();
    notifyListeners();
  }

  void toggleProSubscription() {
    // Subscription UI only ("Coming Soon"), no-op
  }

  void completeOnboarding({
    required Experience experience,
    required Set<String> markets,
    required TradingStyle style,
    required double startingCapital,
    required String currencySymbol,
  }) {
    _profile
      ..onboarded = true
      ..experience = experience
      ..markets = markets
      ..style = style
      ..startingCapital = startingCapital
      ..currencySymbol = currencySymbol;
    setAppCurrency(currencySymbol);
    _save();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _save();
    notifyListeners();
  }

  void setThemeIndex(int index) {
    if (index >= 0 && index < 5) {
      _themeIndex = index;
      _save();
      notifyListeners();
    }
  }

  void setHaptics(bool enabled) {
    _profile.hapticsEnabled = enabled;
    _save();
    notifyListeners();
  }

  void setJournalPrompts(bool enabled) {
    _profile.journalPromptsEnabled = enabled;
    _save();
    notifyListeners();
  }

  void updateProfile({
    Experience? experience,
    Set<String>? markets,
    TradingStyle? style,
    String? currencySymbol,
  }) {
    if (experience != null) _profile.experience = experience;
    if (markets != null) _profile.markets = markets;
    if (style != null) _profile.style = style;
    if (currencySymbol != null) {
      _profile.currencySymbol = currencySymbol;
      setAppCurrency(currencySymbol);
    }
    _save();
    notifyListeners();
  }

  /// Wipes onboarding so the intro flow shows again (used by Settings).
  Future<void> resetOnboarding() async {
    _profile = UserProfile();
    _themeMode = ThemeMode.system;
    _themeIndex = 0;
    _isAuthenticated = false;
    _username = null;
    _email = null;
    _isProUser = false;
    setAppCurrency(_profile.currencySymbol);
    await _save();
    notifyListeners();
  }
}
