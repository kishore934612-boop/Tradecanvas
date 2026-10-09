/// Floating overlay widget displaying crosshair info card.
library;

import 'package:flutter/material.dart';

import 'package:app/chart/crosshair/crosshair_info.dart';
import 'package:app/constants/colors.dart';

class CrosshairOverlay extends StatefulWidget {
  final CrosshairInfoData? infoData;
  final CrosshairFieldConfig fieldConfig;
  final bool initialCompactMode;
  final VoidCallback? onClose;

  const CrosshairOverlay({
    super.key,
    required this.infoData,
    this.fieldConfig = const CrosshairFieldConfig(),
    this.initialCompactMode = false,
    this.onClose,
  });

  @override
  State<CrosshairOverlay> createState() => _CrosshairOverlayState();
}

class _CrosshairOverlayState extends State<CrosshairOverlay> {
  late bool _isCompact;

  @override
  void initState() {
    super.initState();
    _isCompact = widget.initialCompactMode;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.infoData;
    if (data == null) return const SizedBox.shrink();

    final colors = AppColors.of(context);
    final isUp = data.close >= data.open;
    final pnlColor = isUp ? colors.positive : colors.negative;

    return Positioned(
      top: 12,
      left: 12,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          constraints: BoxConstraints(maxWidth: _isCompact ? 220 : 320),
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border.withValues(alpha: 0.8), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header line: Date/Time + Bar Index + Mode toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.fieldConfig.showDateTime)
                    Text(
                      '${data.dateStr} ${data.timeStr}',
                      style: TextStyle(
                        color: colors.foreground,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Row(
                    children: [
                      if (widget.fieldConfig.showBarIndex)
                        Text(
                          '#${data.candleIndex}',
                          style: TextStyle(
                            color: colors.mutedForeground,
                            fontSize: 10,
                          ),
                        ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => setState(() => _isCompact = !_isCompact),
                        child: Icon(
                          _isCompact ? Icons.unfold_more : Icons.unfold_less,
                          size: 14,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Divider(height: 8, color: colors.border.withValues(alpha: 0.6)),

              // OHLC row
              if (widget.fieldConfig.showOhlcv) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _cell('O', data.open.toStringAsFixed(2), colors.foreground, colors),
                    _cell('H', data.high.toStringAsFixed(2), colors.foreground, colors),
                    _cell('L', data.low.toStringAsFixed(2), colors.foreground, colors),
                    _cell('C', data.close.toStringAsFixed(2), pnlColor, colors),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Change % and Vol
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.fieldConfig.showChangePercent)
                    Text(
                      'Chg: ${data.changePercent >= 0 ? "+" : ""}${data.changePercent.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: pnlColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (widget.fieldConfig.showOhlcv)
                    Text(
                      'Vol: ${_formatNum(data.volume)}',
                      style: TextStyle(
                        color: colors.mutedForeground,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),

              // Detailed Mode Extra Info
              if (!_isCompact) ...[
                const SizedBox(height: 6),
                Divider(height: 6, color: colors.border.withValues(alpha: 0.6)),
                if (widget.fieldConfig.showBodyPercent || widget.fieldConfig.showWickPercent)
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      if (widget.fieldConfig.showBodyPercent)
                        _badge('Body', '${data.bodyPercent.toStringAsFixed(1)}%', colors),
                      if (widget.fieldConfig.showWickPercent) ...[
                        _badge('UWick', '${data.upperWickPercent.toStringAsFixed(1)}%', colors),
                        _badge('LWick', '${data.lowerWickPercent.toStringAsFixed(1)}%', colors),
                      ],
                      if (widget.fieldConfig.showSpread)
                        _badge('Spread', data.spread.toStringAsFixed(2), colors),
                    ],
                  ),
                const SizedBox(height: 4),

                // Indicator readings
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    if (widget.fieldConfig.showAtr && data.atr != null)
                      _badge('ATR', data.atr!.toStringAsFixed(2), colors),
                    if (widget.fieldConfig.showRsi && data.rsi != null)
                      _badge('RSI', data.rsi!.toStringAsFixed(1), colors),
                    if (widget.fieldConfig.showVwap && data.vwap != null)
                      _badge('VWAP', data.vwap!.toStringAsFixed(2), colors),
                    if (widget.fieldConfig.showMacd && data.macdHist != null)
                      _badge('MACD H', data.macdHist!.toStringAsFixed(2), colors),
                  ],
                ),

                // SMC details
                if (widget.fieldConfig.showSmcLevels &&
                    (data.nearestSupport != null ||
                        data.nearestResistance != null ||
                        data.nearestOrderBlock != null ||
                        data.nearestFvg != null)) ...[
                  const SizedBox(height: 4),
                  if (data.nearestOrderBlock != null)
                    _smcText('OB: ${data.nearestOrderBlock}', colors),
                  if (data.nearestFvg != null)
                    _smcText('FVG: ${data.nearestFvg}', colors),
                  if (data.nearestBos != null)
                    _smcText('BOS: ${data.nearestBos}', colors),
                  if (data.nearestChoch != null)
                    _smcText('CHOCH: ${data.nearestChoch}', colors),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(String label, String val, Color valColor, ThemePalette colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colors.mutedForeground, fontSize: 9)),
        Text(
          val,
          style: TextStyle(
            color: valColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _badge(String label, String val, ThemePalette colors) {
    return Text(
      '$label: $val',
      style: TextStyle(color: colors.mutedForeground, fontSize: 10),
    );
  }

  Widget _smcText(String text, ThemePalette colors) {
    return Text(
      text,
      style: TextStyle(color: colors.primary, fontSize: 10, fontWeight: FontWeight.w500),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatNum(double num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}K';
    return num.toStringAsFixed(1);
  }
}
