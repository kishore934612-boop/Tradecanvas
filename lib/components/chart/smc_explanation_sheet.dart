/// SMC Explanation Sheet — informational card displayed when user taps an SMC structure overlay.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:app/constants/colors.dart';
import 'package:app/models/smc_type.dart';

class SmcExplanationSheet extends StatelessWidget {
  final SmcStructure structure;

  const SmcExplanationSheet({
    super.key,
    required this.structure,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isBullish = structure.isBullish;
    final accentColor = isBullish ? const Color(0xFF26A69A) : const Color(0xFFEF5350);

    final formattedTime = DateTime.fromMillisecondsSinceEpoch(structure.timestamp)
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
          // Header Row: Type Badge + Title + Close
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
                    child: Text(
                      structure.type.shortLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    structure.title,
                    style: TextStyle(
                      fontSize: 15,
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

          // Price & Status Details Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    Text('PRICE RANGE / LEVEL', style: TextStyle(fontSize: 10, color: colors.mutedForeground, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(
                      structure.secondaryPrice > 0
                          ? '\$${math.min(structure.price, structure.secondaryPrice).toStringAsFixed(2)} - \$${math.max(structure.price, structure.secondaryPrice).toStringAsFixed(2)}'
                          : '\$${structure.price.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.foreground),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('STATUS', style: TextStyle(fontSize: 10, color: colors.mutedForeground, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: structure.isMitigated
                            ? colors.mutedForeground.withValues(alpha: 0.15)
                            : colors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        structure.isMitigated ? 'MITIGATED' : 'OPEN / ACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: structure.isMitigated ? colors.mutedForeground : colors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Educational Breakdown
          Text(
            'Market Structure Context',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  structure.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.foreground,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Formed: $formattedTime',
                  style: TextStyle(fontSize: 11, color: colors.mutedForeground),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Non-financial advice disclaimer
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
                    'Market Structure Overlay: Visualizes institutional structure and liquidity dynamics. Does not constitute financial advice or trade signals.',
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
