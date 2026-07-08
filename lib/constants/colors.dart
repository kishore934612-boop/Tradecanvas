import 'package:flutter/material.dart';
import 'package:app/constants/markets.dart';

class ThemePalette {
  final Brightness brightness;
  final Color text;
  final Color tint;
  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color border;
  final Color input;
  final Color positive;
  final Color negative;
  final Color positiveBackground;
  final Color negativeBackground;
  final Color crypto;
  final Color forex;
  final Color stocks;

  final LinearGradient? customPrimaryGradient;

  const ThemePalette({
    required this.brightness,
    required this.text,
    required this.tint,
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.border,
    required this.input,
    required this.positive,
    required this.negative,
    required this.positiveBackground,
    required this.negativeBackground,
    required this.crypto,
    required this.forex,
    required this.stocks,

    this.customPrimaryGradient,
  });

  LinearGradient get primaryGradient => customPrimaryGradient ?? LinearGradient(
        colors: brightness == Brightness.dark
            ? [const Color(0xFF00E676), const Color(0xFF00B0FF)]
            : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get headerGradient => LinearGradient(
        colors: brightness == Brightness.dark
            ? [const Color(0xFF13172E), const Color(0xFF08090C)]
            : [const Color(0xFFEEF2FF), const Color(0xFFF0F3FA)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  LinearGradient get cardGradient => LinearGradient(
        colors: brightness == Brightness.dark
            ? [const Color(0xFF1D2233), const Color(0xFF131722)]
            : [const Color(0xFFFFFFFF), const Color(0xFFF8FAFC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get creditCardGradient => LinearGradient(
        colors: brightness == Brightness.dark
            ? [const Color(0xFF3B82F6), const Color(0xFF8B5CF6), const Color(0xFFEC4899)]
            : [const Color(0xFF4F46E5), const Color(0xFF06B6D4), const Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  Color get glowColor => brightness == Brightness.dark
      ? const Color(0x2600E676)
      : const Color(0x264F46E5);

  List<BoxShadow> get cardShadow => const [];

  List<BoxShadow> get glowShadow => const [];

  /// Standard "glass card" decoration shared by nearly every surface in the
  /// app. Centralizing it removes the copy-pasted card/border/shadow blocks.
  BoxDecoration cardDecoration({double radius = 12.0, double borderAlpha = 1.0}) {
    return BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: 0.8),
      boxShadow: cardShadow,
    );
  }
}

class AppColors {
  static const double radius = 8.0;

  static const ThemePalette light = ThemePalette(
    brightness: Brightness.light,
    text: Color(0xFF0F172A),
    tint: Color(0xFF4F46E5),
    background: Color(0xFFF8FAFC),
    foreground: Color(0xFF0F172A),
    card: Color(0xFFFFFFFF),
    cardForeground: Color(0xFF0F172A),
    primary: Color(0xFF4F46E5),
    primaryForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFFF1F5F9),
    secondaryForeground: Color(0xFF0F172A),
    muted: Color(0xFFF1F5F9),
    mutedForeground: Color(0xFF64748B),
    accent: Color(0xFFF59E0B),
    accentForeground: Color(0xFF0F172A),
    destructive: Color(0xFFEF4444),
    destructiveForeground: Color(0xFFFFFFFF),
    border: Color(0xFFE2E8F0),
    input: Color(0xFFF1F5F9),
    positive: Color(0xFF10B981),
    negative: Color(0xFFEF4444),
    positiveBackground: Color(0xFFD1FAE5),
    negativeBackground: Color(0xFFFEE2E2),
    crypto: Color(0xFFF59E0B),
    forex: Color(0xFF6366F1),
    stocks: Color(0xFF0EA5E9),

  );

  static const ThemePalette dark = ThemePalette(
    brightness: Brightness.dark,
    text: Color(0xFFF8FAFC),
    tint: Color(0xFF00E676),
    background: Color(0xFF090D16),
    foreground: Color(0xFFF8FAFC),
    card: Color(0xFF151B26),
    cardForeground: Color(0xFFF8FAFC),
    primary: Color(0xFF00E676),
    primaryForeground: Color(0xFF090D16),
    secondary: Color(0xFF1E293B),
    secondaryForeground: Color(0xFFF8FAFC),
    muted: Color(0xFF1E293B),
    mutedForeground: Color(0xFF94A3B8),
    accent: Color(0xFFF59E0B),
    accentForeground: Color(0xFF090D16),
    destructive: Color(0xFFF43F5E),
    destructiveForeground: Color(0xFFFFFFFF),
    border: Color(0xFF2E3B52),
    input: Color(0xFF1E293B),
    positive: Color(0xFF00E676),
    negative: Color(0xFFF43F5E),
    positiveBackground: Color(0xFF064E3B),
    negativeBackground: Color(0xFF4C0519),
    crypto: Color(0xFFF59E0B),
    forex: Color(0xFF6366F1),
    stocks: Color(0xFF0EA5E9),

  );

  /// Resolves the active palette from the [Theme]'s registered
  /// [AppThemeExtension]. This means the palette follows the app's chosen
  /// [ThemeMode] (light / dark / system) rather than the OS brightness alone,
  /// which is what makes the in-app theme toggle work. Falls back to the
  /// platform brightness if the extension is somehow missing.
  static ThemePalette of(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    if (ext != null) return ext.palette;
    final brightness = MediaQuery.of(context).platformBrightness;
    return brightness == Brightness.dark ? dark : light;
  }

  /// Returns the brand color for a given market type.
  static Color marketColor(ThemePalette p, MarketType type) {
    switch (type) {
      case MarketType.crypto:
        return p.crypto;
    }
  }

  static ThemePalette getPalette(int index, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    
    Color primaryColor;
    Color bgColor;
    Color cardColor;
    Color borderColor;
    LinearGradient gradient;
    
    switch (index) {
      case 1: // Sapphire
        primaryColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
        bgColor = isDark ? const Color(0xFF0B132B) : const Color(0xFFF1F5F9);
        cardColor = isDark ? const Color(0xFF1C2541) : const Color(0xFFFFFFFF);
        borderColor = isDark ? const Color(0xFF2C3E6B) : const Color(0xFFE2E8F0);
        gradient = isDark 
            ? const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF38BDF8)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF0284C7)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        break;
        
      case 2: // Emerald
        primaryColor = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
        bgColor = isDark ? const Color(0xFF06201B) : const Color(0xFFF0FDFA);
        cardColor = isDark ? const Color(0xFF0A3C32) : const Color(0xFFFFFFFF);
        borderColor = isDark ? const Color(0xFF165B4C) : const Color(0xFFCCFBF1);
        gradient = isDark 
            ? const LinearGradient(colors: [Color(0xFF059669), Color(0xFF34D399)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : const LinearGradient(colors: [Color(0xFF047857), Color(0xFF059669)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        break;
        
      case 3: // Sunset
        primaryColor = isDark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
        bgColor = isDark ? const Color(0xFF1C1917) : const Color(0xFFFAF7F5);
        cardColor = isDark ? const Color(0xFF292524) : const Color(0xFFFFFFFF);
        borderColor = isDark ? const Color(0xFF44403C) : const Color(0xFFF3EAE3);
        gradient = isDark 
            ? const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFFB923C)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : const LinearGradient(colors: [Color(0xFFC2410C), Color(0xFFEA580C)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        break;
        
      case 4: // Amethyst
        primaryColor = isDark ? const Color(0xFFE879F9) : const Color(0xFF9333EA);
        bgColor = isDark ? const Color(0xFF0F081D) : const Color(0xFFFAF5FF);
        cardColor = isDark ? const Color(0xFF1C1035) : const Color(0xFFFFFFFF);
        borderColor = isDark ? const Color(0xFF3B2668) : const Color(0xFFF3E8FF);
        gradient = isDark 
            ? const LinearGradient(colors: [Color(0xFF9333EA), Color(0xFFE879F9)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : const LinearGradient(colors: [Color(0xFF7E22CE), Color(0xFF9333EA)], begin: Alignment.topLeft, end: Alignment.bottomRight);
        break;
        
      case 0: // Classic
      default:
        return isDark ? dark : light;
    }
    
    final base = isDark ? dark : light;
    return ThemePalette(
      brightness: brightness,
      text: base.text,
      tint: primaryColor,
      background: bgColor,
      foreground: base.foreground,
      card: cardColor,
      cardForeground: base.cardForeground,
      primary: primaryColor,
      primaryForeground: isDark ? const Color(0xFF090D16) : const Color(0xFFFFFFFF),
      secondary: base.secondary,
      secondaryForeground: base.secondaryForeground,
      muted: isDark ? cardColor.withValues(alpha: 0.5) : base.muted,
      mutedForeground: base.mutedForeground,
      accent: base.accent,
      accentForeground: base.accentForeground,
      destructive: base.destructive,
      destructiveForeground: base.destructiveForeground,
      border: borderColor,
      input: isDark ? cardColor.withValues(alpha: 0.5) : base.input,
      positive: base.positive,
      negative: base.negative,
      positiveBackground: base.positiveBackground,
      negativeBackground: base.negativeBackground,
      crypto: base.crypto,
      forex: base.forex,
      stocks: base.stocks,
      customPrimaryGradient: gradient,
    );
  }
}

class ThemeOption {
  final int index;
  final String name;
  final Color primaryColor;
  final Color previewBg;

  const ThemeOption({
    required this.index,
    required this.name,
    required this.primaryColor,
    required this.previewBg,
  });
}

const List<ThemeOption> kThemeOptions = [
  ThemeOption(index: 0, name: 'Classic', primaryColor: Color(0xFF00E676), previewBg: Color(0xFF090D16)),
  ThemeOption(index: 1, name: 'Sapphire', primaryColor: Color(0xFF38BDF8), previewBg: Color(0xFF0F172A)),
  ThemeOption(index: 2, name: 'Emerald', primaryColor: Color(0xFF34D399), previewBg: Color(0xFF06201B)),
  ThemeOption(index: 3, name: 'Sunset', primaryColor: Color(0xFFFB923C), previewBg: Color(0xFF1C1917)),
  ThemeOption(index: 4, name: 'Amethyst', primaryColor: Color(0xFFD946EF), previewBg: Color(0xFF110720)),
];

/// Wraps a [ThemePalette] so it can live inside [ThemeData.extensions] and be
/// resolved with [Theme.of(context).extension]. Registering both the light and
/// dark palettes lets Flutter swap them automatically when [ThemeMode] changes.
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final ThemePalette palette;

  const AppThemeExtension(this.palette);

  @override
  AppThemeExtension copyWith({ThemePalette? palette}) {
    return AppThemeExtension(palette ?? this.palette);
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    // Palette is a discrete light/dark value; snapping at the midpoint avoids
    // lerping every individual color (which would be costly and rarely useful).
    if (other is! AppThemeExtension) return this;
    return t < 0.5 ? this : other;
  }
}

/// Convenience accessor: `context.colors` returns the active [ThemePalette].
extension PaletteContext on BuildContext {
  ThemePalette get colors => AppColors.of(this);
}
