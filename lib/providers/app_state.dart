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
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/services/persistence/sqlite_db_helper.dart';
import 'package:app/services/sync/sync_coordinator.dart';

import 'package:app/constants/auth_config.dart';

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
  String? _photoUrl;
  bool _isProUser = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: AuthConfig.googleWebClientId,
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
  String? get photoUrl => _photoUrl;
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
        _photoUrl = state['photoUrl'];
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
          'photoUrl': _photoUrl,
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
        _photoUrl = account.photoUrl;
        await _save();

        // 1. Authenticate with Supabase using Google ID Token
        final authentication = await account.authentication;
        final idToken = authentication.idToken;
        final accessToken = authentication.accessToken;
        
        try {
          if (idToken != null) {
            await Supabase.instance.client.auth.signInWithIdToken(
              provider: OAuthProvider.google,
              idToken: idToken,
              accessToken: accessToken,
            );
          } else {
            Logger.instance.error(
              'Google Sign-In returned a null ID Token! Make sure you replaced AuthConfig.googleWebClientId with your real Web Client ID.'
            );
          }
        } catch (supabaseErr) {
          Logger.instance.error('Supabase authentication failed: $supabaseErr');
        }

        // 2. Local Profile Record & Migration Triggers
        final userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
        if (userId != 'guest') {
          final db = SqliteDbHelper.instance;
          final profileMap = {
            'user_id': userId,
            'display_name': _username,
            'email': _email,
            'photo_url': account.photoUrl,
            'joined_at': DateTime.now().toIso8601String(),
            'last_login': DateTime.now().toIso8601String(),
            'account_type': 'Registered',
          };
          await db.insert('profiles', profileMap);
          await SyncCoordinator.instance.enqueue('profiles', 'INSERT', userId, profileMap);

          // 3. Resolve Guest to Cloud Migration Sync
          bool hasBackup = false;
          try {
            final profileRes = await Supabase.instance.client
                .from('profiles')
                .select()
                .eq('user_id', userId)
                .maybeSingle();
            if (profileRes != null) {
              hasBackup = true;
            }
          } catch (_) {}

          if (hasBackup) {
            await SyncCoordinator.instance.syncDownAll(userId);
          } else {
            await SyncCoordinator.instance.migrateGuestToCloud(userId);
          }
        }

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
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    try {
      await SqliteDbHelper.instance.clearAllData();
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
    _photoUrl = null;
    _isProUser = false;
    setAppCurrency(_profile.currencySymbol);
    await _save();
    notifyListeners();
  }

  /// Updates the user's profile display name and profile picture avatar.
  Future<void> updateDisplayDetails({required String displayName, required String photoUrl}) async {
    _username = displayName;
    _photoUrl = photoUrl;
    await _save();

    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    if (userId != 'guest') {
      final db = SqliteDbHelper.instance;
      final existing = await db.query('profiles', where: 'user_id = ?', whereArgs: [userId]);
      final String joinedAt = existing.isNotEmpty ? (existing.first['joined_at'] as String) : DateTime.now().toIso8601String();
      final String lastLogin = existing.isNotEmpty ? (existing.first['last_login'] as String) : DateTime.now().toIso8601String();
      final String accountType = existing.isNotEmpty ? (existing.first['account_type'] as String) : 'Registered';
      final String email = existing.isNotEmpty ? (existing.first['email'] as String) : (_email ?? '');
      final String country = existing.isNotEmpty ? (existing.first['country'] as String? ?? '') : '';

      final profileMap = {
        'user_id': userId,
        'display_name': displayName,
        'email': email,
        'photo_url': photoUrl,
        'country': country,
        'joined_at': joinedAt,
        'last_login': lastLogin,
        'account_type': accountType,
      };

      // Replace locally
      await db.insert('profiles', profileMap);

      // Enqueue sync operation to Supabase
      await SyncCoordinator.instance.enqueue('profiles', 'INSERT', userId, profileMap);
    }
    notifyListeners();
  }
}
