/// Smart Money Concepts (SMC) Selection Sheet — toggle Breakout, FVG, Order Blocks, Liquidity Sweeps, BOS, CHoCH.
library;

import 'package:flutter/material.dart';

import 'package:app/constants/colors.dart';
import 'package:app/models/smc_type.dart';
import 'package:app/screens/smc_customization_screen.dart';
import 'package:app/utils/haptics.dart';

class SmcSheet extends StatelessWidget {
  final Set<SmcType> enabled;
  final ValueChanged<SmcType> onToggle;
  final SmcSettings settings;
  final ValueChanged<SmcSettings> onSettingsChanged;

  const SmcSheet({
    super.key,
    required this.enabled,
    required this.onToggle,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final activeCount = enabled.length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.80,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Active Counter Badge + Settings + Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Smart Money Concepts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                  if (activeCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '$activeCount ACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: colors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.tune_rounded,
                        color: colors.primary, size: 20),
                    tooltip: 'SMC Settings',
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SmcCustomizationScreen(
                            settings: settings,
                            onChanged: onSettingsChanged,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: colors.mutedForeground, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // List of SMC Overlays
          Expanded(
            child: ListView.separated(
              itemCount: SmcType.values.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final type = SmcType.values[index];
                final active = enabled.contains(type);

                return InkWell(
                  onTap: () {
                    Haptics.selection();
                    onToggle(type);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: active
                          ? colors.primary.withValues(alpha: 0.16)
                          : colors.card.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active
                            ? colors.primary
                            : colors.border.withValues(alpha: 0.4),
                        width: active ? 1.8 : 1.0,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Checkbox Icon
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active
                                ? colors.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: active
                                  ? colors.primary
                                  : colors.mutedForeground,
                              width: 1.5,
                            ),
                          ),
                          child: active
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),

                        // Title & Description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: active
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: colors.foreground,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                type.description,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colors.mutedForeground,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
