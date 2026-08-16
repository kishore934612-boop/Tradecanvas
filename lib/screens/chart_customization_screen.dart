/// Chart Customization Screen — paired candle theme templates, canvas theme & grid options.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app/components/ui.dart';
import 'package:app/constants/colors.dart';

import 'package:app/models/user_profile.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/utils/haptics.dart';

class ChartCustomizationScreen extends StatelessWidget {
  const ChartCustomizationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Chart Customization',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.foreground,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.foreground),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Haptics.selection();
              appState.resetPreferences();
            },
            child: Text(
              'Reset',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          const _SectionLabel('Chart Type'),
          _ChartTypeCard(appState: appState),
          const SizedBox(height: 16),
          const _SectionLabel('Candle Color Templates'),
          _CandleColorsCard(appState: appState),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: colors.mutedForeground,
        ),
      ),
    );
  }
}

// ============================================================
// CHART TYPE CARD
// ============================================================

class _ChartTypeCard extends StatelessWidget {
  final AppState appState;
  const _ChartTypeCard({required this.appState});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final current = appState.profile.chartType;

    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, size: 20, color: colors.primary),
              const SizedBox(width: 10),
              Text(
                'Default Chart Style',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in ChartTypePref.values)
                ChoiceChip(
                  showCheckmark: false,
                  label: Text(type.label),
                  selected: current == type,
                  selectedColor: colors.primary.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        current == type ? FontWeight.bold : FontWeight.w500,
                    color: current == type
                        ? colors.primary
                        : colors.mutedForeground,
                  ),
                  onSelected: (_) {
                    Haptics.selection();
                    appState.setChartTypePref(type);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CANDLE COLOR TEMPLATES
// ============================================================

class CandleThemeTemplate {
  final String name;
  final int bullish;
  final int bearish;

  const CandleThemeTemplate({
    required this.name,
    required this.bullish,
    required this.bearish,
  });
}

class _CandleColorsCard extends StatelessWidget {
  final AppState appState;
  const _CandleColorsCard({required this.appState});

  static const List<CandleThemeTemplate> _templates = [
    CandleThemeTemplate(
      name: 'Ocean',
      bullish: 0xFF4CC9F0,
      bearish: 0xFFFF6B6B,
    ),
    CandleThemeTemplate(
      name: 'Binance Style',
      bullish: 0xFF0ECB81,
      bearish: 0xFFF6465D,
    ),
    CandleThemeTemplate(
      name: 'Modern Purple',
      bullish: 0xFF9B5DE5,
      bearish: 0xFFFF5A5F,
    ),
    CandleThemeTemplate(
      name: 'Arctic',
      bullish: 0xFF7FDBFF,
      bearish: 0xFFFF6B81,
    ),
    CandleThemeTemplate(
      name: 'Sakura',
      bullish: 0xFFC77DFF,
      bearish: 0xFFFF7096,
    ),
    CandleThemeTemplate(
      name: 'Monochrome Dark',
      bullish: 0xFFFFFFFF,
      bearish: 0xFF7A7A7A,
    ),
    CandleThemeTemplate(
      name: 'Monochrome Light',
      bullish: 0xFF1F1F1F,
      bearish: 0xFF9A9A9A,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currentBull = appState.profile.customBullishColorValue;
    final currentBear = appState.profile.customBearishColorValue;

    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_rounded, size: 20, color: colors.primary),
              const SizedBox(width: 10),
              Text(
                'Candle Theme Templates',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              for (final t in _templates)
                _TemplateTile(
                  template: t,
                  selected:
                      currentBull == t.bullish && currentBear == t.bearish,
                  onSelect: () {
                    Haptics.selection();
                    appState.setCandleColors(
                      bullish: t.bullish,
                      bearish: t.bearish,
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final CandleThemeTemplate template;
  final bool selected;
  final VoidCallback onSelect;

  const _TemplateTile({
    required this.template,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.12)
              : colors.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? colors.primary
                : colors.border.withValues(alpha: 0.4),
            width: selected ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                template.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
            ),
            // Bullish Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Color(template.bullish),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Bull',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Bearish Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Color(template.bearish),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Bear',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


