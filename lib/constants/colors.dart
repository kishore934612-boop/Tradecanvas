import 'package:flutter/material.dart';

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
  });

  LinearGradient get primaryGradient => const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF60A5FA), Color(0xFF06B6D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Three distinct, vivid accent colors used for the bottom nav and other
  /// spots that benefit from visually distinguishing sibling items rather
  /// than repeating the single brand [primary] color everywhere.
  List<Color> get navAccents => const [Color(0xFF3B82F6), Color(0xFF06B6D4), Color(0xFFEC4899)];

  /// Soft, blurred, multi-hue accent colors for decorative ambient
  /// background blobs (splash / dashboard headers). Kept separate from
  /// [primary] so headers feel lively rather than monochrome.
  List<Color> get ambientGlow => brightness == Brightness.dark
      ? const [Color(0xFF3B82F6), Color(0xFF7C3AED), Color(0xFF00B0FF)]
      : const [Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFF06B6D4)];

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

  Color get glowColor => Colors.transparent;

  /// Soft ambient elevation used by cards. Subtle by design — this is what
  /// separates a surface from the background without looking like a heavy
  /// Material shadow.
  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: brightness == Brightness.dark
              ? Colors.black.withValues(alpha: 0.2)
              : const Color(0xFF0F172A).withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];

  /// Clean, subtle shadow without heavy colored glow.
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

/// Deterministic, vivid color for a given symbol/base-asset string — used to
/// give each row in the watchlist a distinct identity instead of every tile
/// looking the same. Picked from a fixed, hand-tuned palette (rather than
/// raw HSV hashing) so every result stays legible on both themes.
Color colorForSymbol(String symbol) {
  const palette = [
    Color(0xFFF59E0B), // amber
    Color(0xFF6366F1), // indigo
    Color(0xFFEC4899), // pink
    Color(0xFF10B981), // emerald
    Color(0xFF06B6D4), // cyan
    Color(0xFFF43F5E), // rose
    Color(0xFF8B5CF6), // violet
    Color(0xFF22D3EE), // sky
    Color(0xFFEAB308), // yellow
    Color(0xFF14B8A6), // teal
  ];
  var hash = 0;
  for (final codeUnit in symbol.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

class AppColors {
  static const double radius = 8.0;

  /// Light theme: white background, soft blue accent.
  static const ThemePalette light = ThemePalette(
    brightness: Brightness.light,
    text: Color(0xFF0F172A),
    tint: Color(0xFF3B82F6),
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF0F172A),
    card: Color(0xFFFFFFFF),
    cardForeground: Color(0xFF0F172A),
    primary: Color(0xFF3B82F6),
    primaryForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFFF1F5F9),
    secondaryForeground: Color(0xFF0F172A),
    muted: Color(0xFFF1F5F9),
    mutedForeground: Color(0xFF64748B),
    accent: Color(0xFF3B82F6),
    accentForeground: Color(0xFFFFFFFF),
    destructive: Color(0xFFEF4444),
    destructiveForeground: Color(0xFFFFFFFF),
    border: Color(0xFFE2E8F0),
    input: Color(0xFFF1F5F9),
    positive: Color(0xFF10B981),
    negative: Color(0xFFEF4444),
    positiveBackground: Color(0xFFD1FAE5),
    negativeBackground: Color(0xFFFEE2E2),
  );

  /// Dark theme: black background, soft blue accent.
  static const ThemePalette dark = ThemePalette(
    brightness: Brightness.dark,
    text: Color(0xFFF8FAFC),
    tint: Color(0xFF3B82F6),
    background: Color(0xFF000000),
    foreground: Color(0xFFF8FAFC),
    card: Color(0xFF121212),
    cardForeground: Color(0xFFF8FAFC),
    primary: Color(0xFF3B82F6),
    primaryForeground: Color(0xFFFFFFFF),
    secondary: Color(0xFF1E293B),
    secondaryForeground: Color(0xFFF8FAFC),
    muted: Color(0xFF1E293B),
    mutedForeground: Color(0xFF94A3B8),
    accent: Color(0xFF3B82F6),
    accentForeground: Color(0xFFFFFFFF),
    destructive: Color(0xFFF43F5E),
    destructiveForeground: Color(0xFFFFFFFF),
    border: Color(0xFF2E3B52),
    input: Color(0xFF1E293B),
    positive: Color(0xFF00E676),
    negative: Color(0xFFF43F5E),
    positiveBackground: Color(0xFF064E3B),
    negativeBackground: Color(0xFF4C0519),
  );

  /// Resolves the active palette from the [Theme]'s registered
  /// [AppThemeExtension]. This means the palette follows the app's chosen
  /// [ThemeMode] (light / dark) rather than the OS brightness alone, which is
  /// what makes the in-app theme toggle work. Falls back to the platform
  /// brightness if the extension is somehow missing.
  static ThemePalette of(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    if (ext != null) return ext.palette;
    final brightness = MediaQuery.of(context).platformBrightness;
    return brightness == Brightness.dark ? dark : light;
  }

  static ThemePalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  // Trading & Charting Static Color Constants
  static const Color greenUp = Color(0xFF26A69A);
  static const Color redDown = Color(0xFFEF5350);
  static const Color primary = Color(0xFF2962FF);
  static const Color surface = Color(0xFF1E222D);
  static const Color surfaceBorder = Color(0xFF2A2E39);
  static const Color backgroundSecondary = Color(0xFF131722);
  static const Color textPrimary = Color(0xFFD1D4DC);
  static const Color textSecondary = Color(0xFF787B86);
  static const Color textMuted = Color(0xFF5D606B);
}

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
