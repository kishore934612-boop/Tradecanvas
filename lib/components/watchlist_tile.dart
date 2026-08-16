/// Shared watchlist row — used by the Dashboard's watchlist section.
library;

import 'package:flutter/material.dart';

import 'package:app/components/ui.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/instrument.dart';
import 'package:app/utils/haptics.dart';

class WatchlistTile extends StatelessWidget {
  final Instrument instrument;
  final double price;
  final double change;

  /// Closing prices, oldest first. Fewer than 2 points hides the sparkline.
  final List<double> sparkline;

  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const WatchlistTile({
    super.key,
    required this.instrument,
    required this.price,
    required this.change,
    required this.onTap,
    required this.onRemove,
    this.sparkline = const [],
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final up = change >= 0;
    final accent = up ? colors.positive : colors.negative;
    final hasPrice = price > 0;
    final symbolColor = colorForSymbol(instrument.base);

    return Dismissible(
      key: ValueKey('dismiss_${instrument.symbol}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: colors.negative.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline_rounded, color: colors.negative),
      ),
      onDismissed: (_) {
        Haptics.medium();
        onRemove();
      },
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: selected
              ? colors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
          children: [
            SymbolAvatar(label: instrument.base, color: symbolColor, size: 28),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        instrument.base,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.show_chart_rounded,
                            size: 13, color: colors.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    instrument.quote,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hasPrice ? instrument.formatPrice(price) : '—',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      hasPrice
                          ? '${up ? '+' : ''}${change.toStringAsFixed(2)}%'
                          : '—',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: accent,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.drag_handle_rounded,
                size: 18, color: colors.mutedForeground.withValues(alpha: 0.5)),
          ],
        ),
      ),
    ),
  );
}
}
