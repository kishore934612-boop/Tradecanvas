/// Multi-Timeframe SMC Dashboard — collapsible HUD overlay showing higher
/// timeframe market structure context at a glance.
///
/// Displays HTF trend direction, nearest FVG, Order Block, and liquidity
/// targets without requiring the user to switch timeframes.
library;

import 'package:flutter/material.dart';

import 'package:app/constants/colors.dart';
import 'package:app/models/smc_type.dart';
import 'package:app/utils/haptics.dart';

class MtfSmcDashboard extends StatefulWidget {
  final SmcTrend? htfTrend;
  final String htfLabel; // e.g. "4H", "1D"
  final String ltfLabel; // e.g. "15m", "1H"
  final double currentPrice;

  const MtfSmcDashboard({
    super.key,
    required this.htfTrend,
    required this.htfLabel,
    required this.ltfLabel,
    required this.currentPrice,
  });

  @override
  State<MtfSmcDashboard> createState() => _MtfSmcDashboardState();
}

class _MtfSmcDashboardState extends State<MtfSmcDashboard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final trend = widget.htfTrend;

    if (trend == null) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topRight,
      child: GestureDetector(
        onTap: () {
          Haptics.selection();
          setState(() => _expanded = !_expanded);
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: _expanded ? 200 : 120,
          ),
          padding: EdgeInsets.all(_expanded ? 10 : 6),
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _trendColor(trend.direction, colors).withValues(alpha: 0.4),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact header — always visible.
              _buildHeader(trend, colors),
              if (_expanded) ...[
                const SizedBox(height: 8),
                _buildDivider(colors),
                const SizedBox(height: 6),
                _buildStructureList(trend, colors),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(SmcTrend trend, ThemePalette colors) {
    final trendColor = _trendColor(trend.direction, colors);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: trendColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            widget.htfLabel,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: trendColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          trend.direction.icon,
          style: TextStyle(fontSize: 10, color: trendColor),
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            trend.direction.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: trendColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          size: 14,
          color: colors.mutedForeground,
        ),
      ],
    );
  }

  Widget _buildDivider(ThemePalette colors) {
    return Container(
      height: 0.5,
      color: colors.border.withValues(alpha: 0.4),
    );
  }

  Widget _buildStructureList(SmcTrend trend, ThemePalette colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nearest FVG.
        if (trend.nearestFvg != null)
          _buildStructureRow(
            label: 'FVG',
            value:
                '${_fmt(trend.nearestFvg!.secondaryPrice)} – ${_fmt(trend.nearestFvg!.price)}',
            isBullish: trend.nearestFvg!.isBullish,
            mitigated: trend.nearestFvg!.isMitigated,
            colors: colors,
          ),

        // Nearest OB.
        if (trend.nearestOb != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: _buildStructureRow(
              label: 'OB',
              value:
                  '${_fmt(trend.nearestOb!.secondaryPrice)} – ${_fmt(trend.nearestOb!.price)}',
              isBullish: trend.nearestOb!.isBullish,
              mitigated: trend.nearestOb!.isMitigated,
              colors: colors,
            ),
          ),

        // Liquidity targets.
        if (trend.buyLiquidityTarget != null ||
            trend.sellLiquidityTarget != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIQUIDITY TARGETS',
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                if (trend.buyLiquidityTarget != null)
                  _buildLiquidityRow(
                    label: 'BSL ▲',
                    price: trend.buyLiquidityTarget!,
                    isAbove: true,
                    colors: colors,
                  ),
                if (trend.sellLiquidityTarget != null)
                  _buildLiquidityRow(
                    label: 'SSL ▼',
                    price: trend.sellLiquidityTarget!,
                    isAbove: false,
                    colors: colors,
                  ),
              ],
            ),
          ),

        // Last BOS / CHoCH.
        if (trend.lastBos != null || trend.lastChoch != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LAST STRUCTURE',
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                if (trend.lastBos != null)
                  _buildSmallLabel(
                    'BOS ${trend.lastBos!.isBullish ? "▲" : "▼"} @ ${_fmt(trend.lastBos!.price)}',
                    trend.lastBos!.isBullish ? colors.positive : colors.negative,
                  ),
                if (trend.lastChoch != null)
                  _buildSmallLabel(
                    'CHoCH ${trend.lastChoch!.isBullish ? "▲" : "▼"} @ ${_fmt(trend.lastChoch!.price)}',
                    trend.lastChoch!.isBullish ? colors.positive : colors.negative,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStructureRow({
    required String label,
    required String value,
    required bool isBullish,
    required bool mitigated,
    required ThemePalette colors,
  }) {
    final color = isBullish ? colors.positive : colors.negative;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 8.5,
              color: colors.foreground,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (mitigated) ...[
          const SizedBox(width: 3),
          Text(
            '✓',
            style: TextStyle(fontSize: 8, color: colors.mutedForeground),
          ),
        ],
      ],
    );
  }

  Widget _buildLiquidityRow({
    required String label,
    required double price,
    required bool isAbove,
    required ThemePalette colors,
  }) {
    final distPct = widget.currentPrice > 0
        ? ((price - widget.currentPrice) / widget.currentPrice * 100).abs()
        : 0.0;
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: isAbove ? colors.negative : colors.positive,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${_fmt(price)} (${distPct.toStringAsFixed(1)}%)',
            style: TextStyle(fontSize: 8, color: colors.foreground),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Text(
        text,
        style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Color _trendColor(SmcTrendDirection dir, ThemePalette colors) {
    switch (dir) {
      case SmcTrendDirection.bullish:
        return colors.positive;
      case SmcTrendDirection.bearish:
        return colors.negative;
      case SmcTrendDirection.ranging:
        return colors.mutedForeground;
    }
  }

  String _fmt(double price) {
    if (price >= 1000) return price.toStringAsFixed(0);
    if (price >= 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(4);
  }
}
