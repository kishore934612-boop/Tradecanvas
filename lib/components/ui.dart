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
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.radius = 12.0,
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

/// Standardised large screen header (title + optional trailing action).
class ScreenHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final bool showBackButton;

  const ScreenHeader({
    super.key,
    required this.title,
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
