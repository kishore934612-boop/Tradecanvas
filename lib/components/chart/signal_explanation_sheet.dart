/// Signal Explanation Sheet — educational popup displayed when user taps a strategy marker.
library;

import 'package:flutter/material.dart';

import 'package:app/constants/colors.dart';
import 'package:app/models/strategy_type.dart';

class SignalExplanationSheet extends StatelessWidget {
  final StrategySignal signal;

  const SignalExplanationSheet({
    super.key,
    required this.signal,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isBuy = signal.isBuy;
    final accentColor = isBuy ? const Color(0xFF26A69A) : const Color(0xFFEF5350);

    final formattedTime = DateTime.fromMillisecondsSinceEpoch(signal.timestamp)
        .toLocal()
        .toString()
        .substring(0, 16);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: accentColor.withValues(alpha: 0.8), width: 2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accentColor, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isBuy ? '▲ BUY' : '▼ SELL',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    signal.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: colors.mutedForeground, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Price & Time Details Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PRICE LEVEL', style: TextStyle(fontSize: 10, color: colors.mutedForeground, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('\$${signal.price.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.foreground)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('CANDLE TIME', style: TextStyle(fontSize: 10, color: colors.mutedForeground, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(formattedTime, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.foreground)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Educational Explanation Box
          Text(
            'Strategy Breakdown',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border.withValues(alpha: 0.6)),
            ),
            child: Text(
              signal.explanation,
              style: TextStyle(
                fontSize: 13,
                color: colors.foreground,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Compliance & Educational Notice
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.mutedForeground.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: colors.mutedForeground),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Educational Overlay: Technical analysis tools provide analytical context and are not financial advice or guaranteed performance indicators.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: colors.mutedForeground,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
