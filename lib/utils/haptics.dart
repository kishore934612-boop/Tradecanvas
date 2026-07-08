import 'package:flutter/services.dart';

/// Thin wrapper around [HapticFeedback] that can be globally toggled off via
/// the Settings screen. The [SettingsProvider] keeps [enabled] in sync.
class Haptics {
  Haptics._();

  static bool enabled = true;

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void vibrate() {
    if (enabled) HapticFeedback.vibrate();
  }
}
