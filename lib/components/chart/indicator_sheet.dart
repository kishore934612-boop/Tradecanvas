/// Unified Indicators & Overlays Sheet with segment tab switch (Indicators, Strategies, Smart Money).
///
/// Features instant reactive selection updates and clean minimalist styling.
library;

import 'package:flutter/material.dart';

import 'package:app/constants/colors.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/models/indicator_style.dart';
import 'package:app/models/smc_type.dart';
import 'package:app/models/strategy_type.dart';
import 'package:app/screens/smc_customization_screen.dart';
import 'package:app/screens/strategy_customization_screen.dart';
import 'package:app/utils/haptics.dart';

class IndicatorSheet extends StatefulWidget {
  final Set<IndicatorType>? enabledIndicators;
  final ValueChanged<IndicatorType>? onToggleIndicator;

  /// Aliases for backward compatibility
  final Set<IndicatorType>? enabled;
  final ValueChanged<IndicatorType>? onToggle;

  final Set<StrategyType>? enabledStrategies;
  final ValueChanged<StrategyType>? onToggleStrategy;
  final StrategySettings? strategySettings;
  final ValueChanged<StrategySettings>? onStrategySettingsChanged;

  final Set<SmcType>? enabledSmc;
  final ValueChanged<SmcType>? onToggleSmc;
  final SmcSettings? smcSettings;
  final ValueChanged<SmcSettings>? onSmcSettingsChanged;

  final Map<IndicatorType, String>? indicatorTimeframes;
  final void Function(IndicatorType type, String timeframe)? onIndicatorTimeframeChanged;

  final Map<IndicatorType, IndicatorStyle>? indicatorStyles;
  final void Function(IndicatorType type, IndicatorStyle style)? onIndicatorStyleChanged;

  const IndicatorSheet({
    super.key,
    this.enabledIndicators,
    this.onToggleIndicator,
    this.enabled,
    this.onToggle,
    this.enabledStrategies,
    this.onToggleStrategy,
    this.strategySettings,
    this.onStrategySettingsChanged,
    this.enabledSmc,
    this.onToggleSmc,
    this.smcSettings,
    this.onSmcSettingsChanged,
    this.indicatorTimeframes,
    this.onIndicatorTimeframeChanged,
    this.indicatorStyles,
    this.onIndicatorStyleChanged,
  });

  @override
  State<IndicatorSheet> createState() => _IndicatorSheetState();
}

class _IndicatorSheetState extends State<IndicatorSheet> {
  int _selectedTab = 0; // 0 = Indicators, 1 = Strategies, 2 = Smart Money

  late Set<IndicatorType> _indicators;
  late Set<StrategyType> _strategies;
  late Set<SmcType> _smc;

  @override
  void initState() {
    super.initState();
    _indicators = Set.of(widget.enabledIndicators ?? widget.enabled ?? {});
    _strategies = Set.of(widget.enabledStrategies ?? {});
    _smc = Set.of(widget.enabledSmc ?? {});
  }

  @override
  void didUpdateWidget(covariant IndicatorSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _indicators = Set.of(widget.enabledIndicators ?? widget.enabled ?? {});
    _strategies = Set.of(widget.enabledStrategies ?? {});
    _smc = Set.of(widget.enabledSmc ?? {});
  }

  void _toggleIndicator(IndicatorType type) {
    Haptics.selection();
    setState(() {
      if (_indicators.contains(type)) {
        _indicators.remove(type);
      } else {
        _indicators.add(type);
      }
    });
    (widget.onToggleIndicator ?? widget.onToggle)?.call(type);
  }

  void _toggleStrategy(StrategyType type) {
    Haptics.selection();
    if (widget.onToggleStrategy == null) return;
    setState(() {
      if (_strategies.contains(type)) {
        _strategies.remove(type);
      } else {
        _strategies.add(type);
      }
    });
    widget.onToggleStrategy!(type);
  }

  void _toggleSmc(SmcType type) {
    Haptics.selection();
    if (widget.onToggleSmc == null) return;
    setState(() {
      if (_smc.contains(type)) {
        _smc.remove(type);
      } else {
        _smc.add(type);
      }
    });
    widget.onToggleSmc!(type);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasStrategies = widget.enabledStrategies != null;
    final hasSmc = widget.enabledSmc != null;

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
          // Header Row: Title & Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Indicators & Overlays',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              Row(
                children: [
                  if (_selectedTab == 1 && widget.strategySettings != null)
                    IconButton(
                      icon: Icon(Icons.tune_rounded, color: colors.primary, size: 20),
                      tooltip: 'Strategy Settings',
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StrategyCustomizationScreen(
                              settings: widget.strategySettings!,
                              onChanged: widget.onStrategySettingsChanged ?? (_) {},
                            ),
                          ),
                        );
                      },
                    ),
                  if (_selectedTab == 2 && widget.smcSettings != null)
                    IconButton(
                      icon: Icon(Icons.tune_rounded, color: colors.primary, size: 20),
                      tooltip: 'SMC Settings',
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SmcCustomizationScreen(
                              settings: widget.smcSettings!,
                              onChanged: widget.onSmcSettingsChanged ?? (_) {},
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

          // Segment Tab Switcher: [ Indicators | Strategies | Smart Money | Sessions ]
          if (hasStrategies || hasSmc || true) ...[
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: colors.background.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  _tabButton(
                    index: 0,
                    label: 'Indicators',
                    count: _indicators.length,
                    colors: colors,
                  ),
                  if (hasStrategies)
                    _tabButton(
                      index: 1,
                      label: 'Strategies',
                      count: _strategies.length,
                      colors: colors,
                    ),
                  if (hasSmc)
                    _tabButton(
                      index: 2,
                      label: 'Smart Money',
                      count: _smc.length,
                      colors: colors,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: _selectedTab == 0
                ? _buildIndicatorsList(colors)
                : (_selectedTab == 1
                    ? _buildStrategiesList(colors)
                    : _buildSmcList(colors)),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required int index,
    required String label,
    required int count,
    required ThemePalette colors,
  }) {
    final active = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Haptics.selection();
          setState(() {
            _selectedTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? colors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  color: active ? colors.primary : colors.mutedForeground,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: active
                        ? colors.primary.withValues(alpha: 0.2)
                        : colors.mutedForeground.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: active ? colors.primary : colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 1. Indicators Tab List (Clean Classic Styling)
  Widget _buildIndicatorsList(ThemePalette colors) {
    return ListView.separated(
      itemCount: IndicatorType.values.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final type = IndicatorType.values[index];
        final active = _indicators.contains(type);

        return InkWell(
          onTap: () => _toggleIndicator(type),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: active
                  ? colors.primary.withValues(alpha: 0.10)
                  : colors.card.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active
                    ? colors.primary.withValues(alpha: 0.5)
                    : colors.border.withValues(alpha: 0.4),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                // Label
                Expanded(
                  child: Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      color: colors.foreground,
                    ),
                  ),
                ),

                // Type Badge (Overlay vs Sub-Panel)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    type.isSubPanel ? 'Sub-Panel' : 'Overlay',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Selection Checkmark
                Icon(
                  active ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                  size: 20,
                  color: active ? colors.primary : colors.mutedForeground.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 2. Strategies Tab List
  Widget _buildStrategiesList(ThemePalette colors) {
    return ListView.separated(
      itemCount: StrategyType.values.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final type = StrategyType.values[index];
        final active = _strategies.contains(type);

        return InkWell(
          onTap: () => _toggleStrategy(type),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: active
                  ? colors.primary.withValues(alpha: 0.10)
                  : colors.card.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active
                    ? colors.primary.withValues(alpha: 0.5)
                    : colors.border.withValues(alpha: 0.4),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: active ? FontWeight.bold : FontWeight.w500,
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        type.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.mutedForeground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  active ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                  size: 20,
                  color: active ? colors.primary : colors.mutedForeground.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. Smart Money Concepts Tab List
  Widget _buildSmcList(ThemePalette colors) {
    return ListView.separated(
      itemCount: SmcType.values.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final type = SmcType.values[index];
        final active = _smc.contains(type);

        return InkWell(
          onTap: () => _toggleSmc(type),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: active
                  ? colors.primary.withValues(alpha: 0.10)
                  : colors.card.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active
                    ? colors.primary.withValues(alpha: 0.5)
                    : colors.border.withValues(alpha: 0.4),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: active ? FontWeight.bold : FontWeight.w500,
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        type.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.mutedForeground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  active ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                  size: 20,
                  color: active ? colors.primary : colors.mutedForeground.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
