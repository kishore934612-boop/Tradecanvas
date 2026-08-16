import 'package:flutter/material.dart';
import 'package:app/constants/colors.dart';

/// Reusable card surface with the app's glassy border + shadow treatment.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
    this.margin,
    this.radius = 10.0,
    this.onTap,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? colors.border, width: 0.8),
        boxShadow: colors.cardShadow,
      ),
      child: child,
    );
    if (onTap == null) return Container(margin: margin, child: content);
    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: content,
        ),
      ),
    );
  }
}

/// Standardised large screen header (title + optional leading/trailing action).
class ScreenHeader extends StatelessWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final bool showBackButton;

  const ScreenHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      height: 64.0,
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          bottom: BorderSide(
            color: colors.border.withValues(alpha: 0.6),
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      alignment: Alignment.center,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBackButton) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                margin: const EdgeInsets.only(right: 12.0),
                child: Icon(Icons.arrow_back_rounded, color: colors.foreground, size: 24.0),
              ),
            ),
          ] else if (leading != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: leading!,
            ),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: colors.foreground,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12.0),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// A selectable rounded pill (used for filters and segmented choices).
class PillButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  const PillButton({super.key, required this.label, required this.active, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          gradient: active ? colors.primaryGradient : null,
          color: active ? null : colors.card,
          border: Border.all(color: active ? Colors.transparent : colors.border, width: 1.0),
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: active ? colors.glowShadow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14.0, color: active ? (colors.brightness == Brightness.dark ? Colors.black : Colors.white) : colors.mutedForeground),
              const SizedBox(width: 6.0),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.bold,
                color: active ? (colors.brightness == Brightness.dark ? Colors.black : Colors.white) : colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CoinMeta {
  final String symbol;
  final String badgeText;
  final Color primaryColor;
  final List<Color>? gradient;

  const CoinMeta({
    required this.symbol,
    required this.badgeText,
    required this.primaryColor,
    this.gradient,
  });

  static const Map<String, CoinMeta> registry = {
    'BTC': CoinMeta(
      symbol: 'BTC',
      badgeText: '₿',
      primaryColor: Color(0xFFF7931A),
    ),
    'ETH': CoinMeta(
      symbol: 'ETH',
      badgeText: 'Ξ',
      primaryColor: Color(0xFF627EEA),
    ),
    'USDT': CoinMeta(
      symbol: 'USDT',
      badgeText: '₮',
      primaryColor: Color(0xFF26A17B),
    ),
    'USDC': CoinMeta(
      symbol: 'USDC',
      badgeText: '\$',
      primaryColor: Color(0xFF2775CA),
    ),
    'SOL': CoinMeta(
      symbol: 'SOL',
      badgeText: 'S',
      primaryColor: Color(0xFF9945FF),
      gradient: [Color(0xFF14F195), Color(0xFF9945FF)],
    ),
    'BNB': CoinMeta(
      symbol: 'BNB',
      badgeText: '❖',
      primaryColor: Color(0xFFF3BA2F),
    ),
    'XRP': CoinMeta(
      symbol: 'XRP',
      badgeText: '✕',
      primaryColor: Color(0xFF23292F),
    ),
    'ADA': CoinMeta(
      symbol: 'ADA',
      badgeText: '₳',
      primaryColor: Color(0xFF0033AD),
    ),
    'DOGE': CoinMeta(
      symbol: 'DOGE',
      badgeText: 'Ð',
      primaryColor: Color(0xFFC2A633),
    ),
    'AVAX': CoinMeta(
      symbol: 'AVAX',
      badgeText: 'A',
      primaryColor: Color(0xFFE84142),
    ),
    'DOT': CoinMeta(
      symbol: 'DOT',
      badgeText: 'P',
      primaryColor: Color(0xFFE6007A),
    ),
    'LINK': CoinMeta(
      symbol: 'LINK',
      badgeText: '⬡',
      primaryColor: Color(0xFF375BD2),
    ),
    'LTC': CoinMeta(
      symbol: 'LTC',
      badgeText: 'Ł',
      primaryColor: Color(0xFF345D9D),
    ),
    'SHIB': CoinMeta(
      symbol: 'SHIB',
      badgeText: 'S',
      primaryColor: Color(0xFFFFA409),
    ),
    'MATIC': CoinMeta(
      symbol: 'MATIC',
      badgeText: 'M',
      primaryColor: Color(0xFF8247E5),
    ),
  };

  static CoinMeta getFor(String symbol) {
    final clean = symbol
        .toUpperCase()
        .replaceAll('USDT', '')
        .replaceAll('BUSD', '')
        .replaceAll('USD', '');
    if (registry.containsKey(clean)) return registry[clean]!;
    if (registry.containsKey(symbol.toUpperCase())) {
      return registry[symbol.toUpperCase()]!;
    }

    final fallbackColor = colorForSymbol(symbol);
    return CoinMeta(
      symbol: clean,
      badgeText: clean.isNotEmpty ? clean[0] : '?',
      primaryColor: fallbackColor,
    );
  }
}

/// Round, colorful initial-letter avatar for a trading symbol. Gives every
/// watchlist/search row a distinct identity color instead of a flat icon.
class SymbolAvatar extends StatelessWidget {
  final String label;
  final Color color;
  final double size;

  const SymbolAvatar({
    super.key,
    required this.label,
    required this.color,
    this.size = 36.0,
  });

  @override
  Widget build(BuildContext context) {
    final meta = CoinMeta.getFor(label);
    final clean = meta.symbol.toLowerCase();
    final bgColors = meta.gradient ??
        [meta.primaryColor, meta.primaryColor.withValues(alpha: 0.8)];

    final fallbackBadge = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: bgColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Text(
        meta.badgeText,
        style: TextStyle(
          fontSize: size * (meta.badgeText.length > 2 ? 0.32 : 0.44),
          fontWeight: FontWeight.w900,
          color: meta.primaryColor == const Color(0xFFFFFFFF)
              ? Colors.black
              : Colors.white,
        ),
      ),
    );

    if (clean.isEmpty) return fallbackBadge;

    final iconUrl = 'https://assets.coincap.io/assets/icons/$clean@2x.png';

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.network(
          iconUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallbackBadge,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return fallbackBadge;
          },
        ),
      ),
    );
  }
}

/// Small rounded-square icon badge with a gradient fill — used to give
/// settings rows / section headers a colorful anchor instead of a plain
/// muted-colored icon.
class GradientIconBadge extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final double size;
  final double iconSize;

  const GradientIconBadge({
    super.key,
    required this.icon,
    required this.colors,
    this.size = 36.0,
    this.iconSize = 18.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: iconSize, color: Colors.white),
    );
  }
}

/// Compact label/value stat tile.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const StatTile({super.key, required this.label, required this.value, this.valueColor, this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(12.0),
      radius: 10.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13.0, color: colors.mutedForeground),
                const SizedBox(width: 4.0),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11.0, color: colors.mutedForeground, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Text(
            value,
            style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: valueColor ?? colors.foreground),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: colors.foreground)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Generic empty-state with an optional call-to-action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const EmptyState({super.key, required this.icon, required this.message, this.ctaLabel, this.onCta});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 42.0, color: colors.mutedForeground),
            const SizedBox(height: 14.0),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.0, color: colors.mutedForeground, fontWeight: FontWeight.w500, height: 1.4),
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: onCta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.brightness == Brightness.dark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                ),
                child: Text(ctaLabel!, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
