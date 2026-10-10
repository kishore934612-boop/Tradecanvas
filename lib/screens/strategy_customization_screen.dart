/// Dedicated Strategy Customization Screen — full-page settings for educational strategy overlays.
library;

import 'package:flutter/material.dart';

import 'package:app/components/ui.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/strategy_type.dart';
import 'package:app/utils/haptics.dart';

class StrategyCustomizationScreen extends StatefulWidget {
  final StrategySettings settings;
  final ValueChanged<StrategySettings> onChanged;

  const StrategyCustomizationScreen({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  State<StrategyCustomizationScreen> createState() =>
      _StrategyCustomizationScreenState();
}

class _StrategyCustomizationScreenState
    extends State<StrategyCustomizationScreen> {
  late StrategySettings _current;

  @override
  void initState() {
    super.initState();
    _current = widget.settings;
  }

  void _update(StrategySettings next) {
    if (!next.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Fast EMA must be shorter than slow EMA; thresholds must be ordered.')));
      return;
    }
    Haptics.selection();
    setState(() {
      _current = next;
    });
    widget.onChanged(next);
  }

  void _resetDefaults() {
    Haptics.medium();
    const defaults = StrategySettings();
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
          'Strategy Customization',
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
          Text('Closed-candle educational patterns, not automatic trade recommendations. '
              'Signals do not establish a profitable edge.',
              style: TextStyle(color: colors.mutedForeground, fontSize: 12)),
          const SizedBox(height: 16),
          // Section 1: Visual Display Options
          const _SectionLabel('Visual Overlay Display'),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Enable Labels',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                  subtitle: Text(
                    'Display strategy name pills on chart signals',
                    style: TextStyle(fontSize: 11.5, color: colors.mutedForeground),
                  ),
                  value: _current.enableLabels,
                  activeTrackColor: colors.primary,
                  onChanged: (val) => _update(_current.copyWith(enableLabels: val)),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                SwitchListTile(
                  title: Text(
                    'Enable Directional Arrows',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                  subtitle: Text(
                    'Draw buy/sell directional arrow markers',
                    style: TextStyle(fontSize: 11.5, color: colors.mutedForeground),
                  ),
                  value: _current.enableArrows,
                  activeTrackColor: colors.primary,
                  onChanged: (val) => _update(_current.copyWith(enableArrows: val)),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                _SliderTile(
                  title: 'Arrow Marker Size',
                  subtitle: '${_current.arrowSize.toInt()} px',
                  value: _current.arrowSize,
                  min: 8.0,
                  max: 24.0,
                  divisions: 16,
                  colors: colors,
                  onChanged: (val) => _update(_current.copyWith(arrowSize: val)),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                _SliderTile(
                  title: 'Label Font Size',
                  subtitle: '${_current.labelSize.toInt()} pt',
                  value: _current.labelSize,
                  min: 8.0,
                  max: 16.0,
                  divisions: 8,
                  colors: colors,
                  onChanged: (val) => _update(_current.copyWith(labelSize: val)),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                _SliderTile(
                  title: 'Signal Opacity',
                  subtitle: '${(_current.signalOpacity * 100).toInt()}%',
                  value: _current.signalOpacity,
                  min: 0.2,
                  max: 1.0,
                  divisions: 8,
                  colors: colors,
                  onChanged: (val) => _update(_current.copyWith(signalOpacity: val)),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                _SliderTile(
                  title: 'Max Visible Signals',
                  subtitle: '${_current.maxVisibleSignals} markers',
                  value: _current.maxVisibleSignals.toDouble(),
                  min: 10,
                  max: 200,
                  divisions: 19,
                  colors: colors,
                  onChanged: (val) =>
                      _update(_current.copyWith(maxVisibleSignals: val.toInt())),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Technical Parameters & Indicators
          const _SectionLabel('Technical Parameters & Thresholds'),
          GlassCard(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Strict Candle Confirmation',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                  ),
                  subtitle: Text(
                    'Require candle close directional confirmation',
                    style: TextStyle(fontSize: 11.5, color: colors.mutedForeground),
                  ),
                  value: _current.strictConfirmation,
                  activeTrackColor: colors.primary,
                  onChanged: (val) =>
                      _update(_current.copyWith(strictConfirmation: val)),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                SwitchListTile(
                  title: const Text('Require volume confirmation'),
                  subtitle: Text('${_current.volumeMultiplier}x previous 20-bar average; missing volume blocks signals'),
                  value: _current.requireVolumeConfirmation,
                  onChanged: (v) => _update(_current.copyWith(requireVolumeConfirmation: v)),
                ),
                _SliderTile(title: 'Signal cooldown',
                  subtitle: '${_current.cooldownBars} chart bars per direction',
                  value: _current.cooldownBars.toDouble(), min: 0, max: 20,
                  divisions: 20, colors: colors,
                  onChanged: (v) => _update(_current.copyWith(cooldownBars: v.round()))),
                _SliderTile(
                  title: 'Fast EMA Period',
                  subtitle: '${_current.emaFastPeriod} bars',
                  value: _current.emaFastPeriod.toDouble(),
                  min: 5,
                  max: 50,
                  divisions: 45,
                  colors: colors,
                  onChanged: (val) =>
                      _update(_current.copyWith(emaFastPeriod: val.toInt())),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                _SliderTile(
                  title: 'Slow EMA Period',
                  subtitle: '${_current.emaSlowPeriod} bars',
                  value: _current.emaSlowPeriod.toDouble(),
                  min: 20,
                  max: 200,
                  divisions: 36,
                  colors: colors,
                  onChanged: (val) =>
                      _update(_current.copyWith(emaSlowPeriod: val.toInt())),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                _SliderTile(
                  title: 'RSI Overbought Level',
                  subtitle: '${_current.rsiUpperLevel.toInt()}',
                  value: _current.rsiUpperLevel,
                  min: 60,
                  max: 90,
                  divisions: 30,
                  colors: colors,
                  onChanged: (val) =>
                      _update(_current.copyWith(rsiUpperLevel: val)),
                ),
                Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
                _SliderTile(
                  title: 'RSI Oversold Level',
                  subtitle: '${_current.rsiLowerLevel.toInt()}',
                  value: _current.rsiLowerLevel,
                  min: 10,
                  max: 40,
                  divisions: 30,
                  colors: colors,
                  onChanged: (val) =>
                      _update(_current.copyWith(rsiLowerLevel: val)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 3: Signal Engine Active Rules
          const _SectionLabel('Active Engine Rules'),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _RuleRow(
                    icon: Icons.volume_up_rounded,
                    title: 'Volume Confirmation',
                    desc: _current.requireVolumeConfirmation ? 'Enabled: ${_current.volumeMultiplier}x previous 20-bar average.' : 'Optional volume filter is disabled.',
                    colors: colors,
                  ),
                  const SizedBox(height: 10),
                  _RuleRow(
                    icon: Icons.timer_outlined,
                    title: 'Signal Cooldown',
                    desc: 'Same strategy and direction wait ${_current.cooldownBars} chart bars, on every timeframe.',
                    colors: colors,
                  ),
                  const SizedBox(height: 10),
                  _RuleRow(
                    icon: Icons.touch_app_rounded,
                    title: 'Multi-Touch Validation',
                    desc: 'Support/resistance requires two prior touches. Zones signal only their first confirmed retest.',
                    colors: colors,
                  ),
                ],
              ),
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

class _RuleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final ThemePalette colors;

  const _RuleRow({
    required this.icon,
    required this.title,
    required this.desc,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: colors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.mutedForeground,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
