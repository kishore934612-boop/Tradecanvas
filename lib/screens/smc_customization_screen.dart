/// Dedicated Smart Money Concepts (SMC) Customization Screen — full-page settings for market structure overlays.
library;

import 'package:flutter/material.dart';

import 'package:app/components/ui.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/smc_type.dart';
import 'package:app/utils/haptics.dart';

class SmcCustomizationScreen extends StatefulWidget {
  final SmcSettings settings;
  final ValueChanged<SmcSettings> onChanged;

  const SmcCustomizationScreen({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  State<SmcCustomizationScreen> createState() => _SmcCustomizationScreenState();
}

class _SmcCustomizationScreenState extends State<SmcCustomizationScreen> {
  late SmcSettings _current;

  @override
  void initState() {
    super.initState();
    _current = widget.settings;
  }

  void _update(SmcSettings next) {
    Haptics.selection();
    setState(() {
      _current = next;
    });
    widget.onChanged(next);
  }

  void _resetDefaults() {
    Haptics.medium();
    const defaults = SmcSettings();
    _update(defaults);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Smart Money Concepts',
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
            onPressed: _resetDefaults,
            child: Text(
              'Reset Defaults',
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section 1: Visualization Mode
          const _SectionLabel('Visualization Density Mode'),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final mode in SmcVisualizationMode.values) ...[
                    InkWell(
                      onTap: () =>
                          _update(_current.copyWith(visualizationMode: mode)),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _current.visualizationMode == mode
                              ? colors.primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _current.visualizationMode == mode
                                ? colors.primary
                                : colors.border.withValues(alpha: 0.3),
                            width: _current.visualizationMode == mode ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _current.visualizationMode == mode
                                      ? colors.primary
                                      : colors.mutedForeground,
                                  width: 2,
                                ),
                              ),
                              child: _current.visualizationMode == mode
                                  ? Center(
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: colors.primary,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mode.label,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: colors.foreground,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mode.description,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (mode != SmcVisualizationMode.values.last)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Zone Merging & Decluttering
          const _SectionLabel('Zone Merging & Decluttering'),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Merge Overlapping Zones',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                  subtitle: Text(
                    'Combine overlapping Order Blocks and FVGs of same directional bias',
                    style: TextStyle(fontSize: 11.5, color: colors.mutedForeground),
                  ),
                  value: _current.mergeOverlappingZones,
                  activeTrackColor: colors.primary,
                  onChanged: (val) =>
                      _update(_current.copyWith(mergeOverlappingZones: val)),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                SwitchListTile(
                  title: Text(
                    'Label Collision Avoidance',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                  subtitle: Text(
                    'Automatically shift structure badge positions to prevent text overlapping',
                    style: TextStyle(fontSize: 11.5, color: colors.mutedForeground),
                  ),
                  value: _current.enableCollisionAvoidance,
                  activeTrackColor: colors.primary,
                  onChanged: (val) =>
                      _update(_current.copyWith(enableCollisionAvoidance: val)),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                SwitchListTile(
                  title: Text(
                    'Hide Mitigated Order Blocks',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                  subtitle: Text(
                    'Remove OB zones once price retests and breaks through them',
                    style: TextStyle(fontSize: 11.5, color: colors.mutedForeground),
                  ),
                  value: _current.hideMitigatedOb,
                  activeTrackColor: colors.primary,
                  onChanged: (val) =>
                      _update(_current.copyWith(hideMitigatedOb: val)),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                SwitchListTile(
                  title: Text(
                    'Hide Mitigated Fair Value Gaps',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                  subtitle: Text(
                    'Remove FVG gaps after price fills the price imbalance',
                    style: TextStyle(fontSize: 11.5, color: colors.mutedForeground),
                  ),
                  value: _current.hideMitigatedFvg,
                  activeTrackColor: colors.primary,
                  onChanged: (val) =>
                      _update(_current.copyWith(hideMitigatedFvg: val)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: Engine Sensitivity & Limits
          const _SectionLabel('Detection Parameters & Limits'),
          GlassCard(
            child: Column(
              children: [
                _SliderTile(
                  title: 'Swing Pivot Sensitivity',
                  subtitle: '${_current.swingSensitivity} bars',
                  value: _current.swingSensitivity.toDouble(),
                  min: 2,
                  max: 15,
                  divisions: 13,
                  colors: colors,
                  onChanged: (val) =>
                      _update(_current.copyWith(swingSensitivity: val.toInt())),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                _SliderTile(
                  title: 'Max Visible Structures',
                  subtitle: '${_current.maxVisibleStructures} items',
                  value: _current.maxVisibleStructures.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 18,
                  colors: colors,
                  onChanged: (val) =>
                      _update(_current.copyWith(maxVisibleStructures: val.toInt())),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                _SliderTile(
                  title: 'Overlay Opacity',
                  subtitle: '${(_current.opacity * 100).toInt()}%',
                  value: _current.opacity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 18,
                  colors: colors,
                  onChanged: (val) => _update(_current.copyWith(opacity: val)),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                _SliderTile(
                  title: 'Lookback Consolidation Window',
                  subtitle: '${_current.lookbackBars} bars',
                  value: _current.lookbackBars.toDouble(),
                  min: 30,
                  max: 300,
                  divisions: 27,
                  colors: colors,
                  onChanged: (val) =>
                      _update(_current.copyWith(lookbackBars: val.toInt())),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                _SliderTile(
                  title: 'Min Breakout % Threshold',
                  subtitle: '${(_current.minBreakoutPct * 100).toStringAsFixed(2)}%',
                  value: _current.minBreakoutPct,
                  min: 0.0005,
                  max: 0.010,
                  divisions: 19,
                  colors: colors,
                  onChanged: (val) =>
                      _update(_current.copyWith(minBreakoutPct: val)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
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
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
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

class _SliderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ThemePalette colors;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: colors.primary,
              inactiveTrackColor: colors.border.withValues(alpha: 0.4),
              thumbColor: colors.primary,
              trackHeight: 3,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
