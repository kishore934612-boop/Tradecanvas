/// Candle chart painter.
///
/// Draws, in order: grid, axes, volume, MACD, indicator overlays, candles or
/// area, last-price line, crosshair. Only the visible index window is
/// iterated, so paint cost is bounded by viewport width rather than by how
/// much history is loaded.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:app/components/chart/chart_layout.dart';
import 'package:app/components/chart/chart_transform.dart';
import 'package:app/constants/colors.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/engine/session_overlay.dart';
import 'package:app/models/instrument.dart';
import 'package:app/models/user_profile.dart';

enum ChartStyle { candles, line, baseline, area, volumeCandles }

class ChartPaintParams {
  final ChartTransform transform;
  final ChartLayout layout;
  final ChartIndicators indicators;
  final Set<IndicatorType> enabledIndicators;
  final ChartStyle style;
  final GridVisibilityPref gridVisibility;
  final GridStylePref gridStyle;
  final GridDensityPref gridDensity;
  final Color bullishColor;
  final Color bearishColor;
  final ThemePalette colors;
  final Instrument instrument;
  final Timeframe timeframe;

  /// Candle index under the crosshair, or null when inactive.
  final int? crosshairIndex;

  /// Vertical crosshair position, used for the price tag on the axis.
  final double? crosshairY;

  /// Whether to render crosshair price and time labels.
  final bool showCrosshairLabels;

  /// Custom horizontal price line markers.
  final List<double> customPriceLines;

  /// Session overlays to render.
  final List<SessionRect> sessionRects;

  const ChartPaintParams({
    required this.transform,
    required this.layout,
    required this.indicators,
    required this.enabledIndicators,
    required this.style,
    this.gridVisibility = GridVisibilityPref.show,
    this.gridStyle = GridStylePref.dashed,
    this.gridDensity = GridDensityPref.medium,
    required this.bullishColor,
    required this.bearishColor,
    required this.colors,
    required this.instrument,
    required this.timeframe,
    this.crosshairIndex,
    this.crosshairY,
    this.showCrosshairLabels = true,
    this.customPriceLines = const [],
    this.sessionRects = const [],
  });

  List<CandleData> get candles => transform.candles;

  bool get showVolume => enabledIndicators.contains(IndicatorType.volume);
  bool get showMacd => enabledIndicators.contains(IndicatorType.macd);
  bool get showRsi => enabledIndicators.contains(IndicatorType.rsi);
  bool get showAtr => enabledIndicators.contains(IndicatorType.atr);
  bool get showStochRsi => enabledIndicators.contains(IndicatorType.stochRsi);
}

class ChartPainter extends CustomPainter {
  final ChartPaintParams p;

  ChartPainter(this.p);

  static final Paint _fill = Paint()..style = PaintingStyle.fill;

  /// Minimum vertical gap, in pixels, between two price axis labels. Used to
  /// derive how many labels fit — denser than the previous fixed count of 6,
  /// so the price bar shows more reference prices, while still adapting down
  /// on short embedded charts (e.g. the Dashboard panel) so labels never
  /// overlap.
  static const double _priceLabelMinGap = 34.0;
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (p.transform.isEmpty || !p.layout.isUsable) return;    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(0, 0, p.layout.plotWidth, p.layout.priceHeight));

    _drawSessions(canvas);
    _drawOverlayIndicators(canvas);

    switch (p.style) {
      case ChartStyle.candles:
        _drawCandles(canvas);
        break;
      case ChartStyle.line:
        _drawLine(canvas);
        break;
      case ChartStyle.baseline:
        _drawBaseline(canvas);
        break;
      case ChartStyle.area:
        _drawArea(canvas);
        break;
      case ChartStyle.volumeCandles:
        _drawVolumeCandles(canvas);
        break;
    }

    _drawLastPriceLine(canvas);
    _drawCustomPriceLines(canvas);
    if (p.crosshairIndex != null) _drawCrosshairGuides(canvas);

    canvas.restore();

    // Draw active sub-panels
    if (p.showVolume) _drawVolumePanel(canvas);
    if (p.showMacd) _drawMacdPanel(canvas);
    if (p.showRsi) _drawRsiPanel(canvas);
    if (p.showAtr) _drawAtrPanel(canvas);
    if (p.showStochRsi) _drawStochRsiPanel(canvas);

    // Axes — and the last-price / crosshair price badges that live in the
    // same right-hand gutter — are drawn outside the plot clip, since the
    // gutter starts at x = plotWidth and would otherwise be clipped away.
    _drawPriceAxis(canvas);
    _drawTimeAxis(canvas);
    _drawLastPriceBadge(canvas);
    _drawCustomPriceBadges(canvas);
    if (p.crosshairIndex != null && p.showCrosshairLabels) {
      _drawCrosshairBadges(canvas);
    }
  }



  // ==========================================================
  // SESSION OVERLAYS
  // ==========================================================

  void _drawSessions(Canvas canvas) {
    final rects = p.sessionRects;
    if (rects.isEmpty) return;

    final t = p.transform;

    for (final sr in rects) {
      final x1 = t.xForTimestamp(sr.startMs);
      final x2 = t.xForTimestamp(sr.endMs);
      final left = math.min(x1, x2);
      final right = math.max(x1, x2);

      // Skip if entirely off-screen.
      if (right < 0 || left > p.layout.plotWidth) continue;

      final clampedLeft = left.clamp(0.0, p.layout.plotWidth);
      final clampedRight = right.clamp(0.0, p.layout.plotWidth);

      // Session background rectangle (full price height).
      canvas.drawRect(
        Rect.fromLTRB(clampedLeft, 0, clampedRight, p.layout.priceHeight),
        Paint()..color = sr.type.color.withValues(alpha: 0.06),
      );

      // Session name label at top.
      if (clampedRight - clampedLeft > 30) {
        _label(
          canvas,
          sr.type.label,
          Offset(clampedLeft + 4, 3),
          sr.type.color.withValues(alpha: 0.5),
          8.0,
        );
      }

      // Session high/low guide lines.
      if (sr.high > sr.low) {
        final hy = t.yForPrice(sr.high);
        final ly = t.yForPrice(sr.low);
        final guidePaint = Paint()
          ..color = sr.type.color.withValues(alpha: 0.3)
          ..strokeWidth = 0.6;
        _dashedLine(canvas, Offset(clampedLeft, hy),
            Offset(clampedRight, hy), guidePaint);
        _dashedLine(canvas, Offset(clampedLeft, ly),
            Offset(clampedRight, ly), guidePaint);
      }
    }
  }

  // ==========================================================
  // CANDLES & CHART STYLES
  // ==========================================================

  void _drawCandles(Canvas canvas) {
    final t = p.transform;
    final first = t.firstVisibleIndex;
    final last = t.lastVisibleIndex;
    if (last < first) return;

    final plotWidth = p.layout.plotWidth;
    final priceHeight = p.layout.priceHeight;
    final minPrice = t.minPrice;
    final priceSpan = t.priceSpan;
    final pricePanOffset = t.pricePanOffset;

    final rightOffsetPx = t.rightOffsetPx;
    final candleWidth = t.candleWidth;
    final scrollOffset = t.scrollOffset;
    final newestIndex = t.candles.length - 1;
    final rightAnchor = plotWidth - rightOffsetPx - candleWidth / 2;

    double toX(int index) =>
        rightAnchor - (newestIndex - index) * candleWidth + scrollOffset;
    double toY(double price) =>
        priceHeight - ((price - minPrice) / priceSpan) * priceHeight + pricePanOffset;

    final isLowDetail = candleWidth < 3.0;

    if (isLowDetail) {
      // Phase 7: Zoomed far out LOD — batch simple line primitives
      _stroke.strokeWidth = math.max(0.7, candleWidth * 0.85);
      for (int i = first; i <= last; i++) {
        final c = t.candles[i];
        final x = toX(i);
        final highY = toY(c.high);
        final lowY = toY(c.low);
        _stroke.color = c.isBullish ? p.bullishColor : p.bearishColor;
        canvas.drawLine(Offset(x, highY), Offset(x, lowY), _stroke);
      }
      return;
    }

    final bodyWidth = math.max(1.0, candleWidth * 0.72);
    final wickWidth = math.max(0.6, math.min(1.4, candleWidth * 0.12));

    final canvasBg = p.colors.background;
    final bgLum = canvasBg.computeLuminance();
    final bullColor = p.bullishColor;
    final bearColor = p.bearishColor;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = first; i <= last; i++) {
      final c = t.candles[i];
      final x = toX(i);
      final color = c.isBullish ? bullColor : bearColor;

      final highY = toY(c.high);
      final lowY = toY(c.low);
      final openY = toY(c.open);
      final closeY = toY(c.close);

      // Wick
      _fill.color = color;
      final wickRect =
          Rect.fromLTRB(x - wickWidth / 2, highY, x + wickWidth / 2, lowY);
      canvas.drawRect(wickRect, _fill);

      // Body
      final top = math.min(openY, closeY);
      final bottom = math.max(openY, closeY);
      final bodyHeight = math.max(1.0, bottom - top);
      final bodyRect =
          Rect.fromLTWH(x - bodyWidth / 2, top, bodyWidth, bodyHeight);
      canvas.drawRect(bodyRect, _fill);

      // Contrast outline for low contrast templates
      final colorLum = color.computeLuminance();
      if ((colorLum - bgLum).abs() < 0.18) {
        strokePaint.color = bgLum > 0.5
            ? Colors.black.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.7);
        canvas.drawRect(bodyRect, strokePaint);
      }
    }
  }

  void _drawLine(Canvas canvas) {
    final t = p.transform;
    final first = t.firstVisibleIndex;
    final last = t.lastVisibleIndex;
    if (last <= first) return;

    final path = Path();
    for (int i = first; i <= last; i++) {
      final x = t.xForIndex(i);
      final y = t.yForPrice(t.candles[i].close);
      if (i == first) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final isUp = t.candles[last].close >= t.candles[first].open;
    final lineColor = isUp ? p.bullishColor : p.bearishColor;

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawBaseline(Canvas canvas) {
    final t = p.transform;
    final first = t.firstVisibleIndex;
    final last = t.lastVisibleIndex;
    if (last <= first) return;

    final baselinePrice = t.minPrice + (t.maxPrice - t.minPrice) * 0.5;
    final baselineY = t.yForPrice(baselinePrice);

    // Draw baseline guide line
    final baseLinePaint = Paint()
      ..color = p.colors.mutedForeground.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    _dashedLine(canvas, Offset(0, baselineY), Offset(p.layout.plotWidth, baselineY), baseLinePaint);

    final pathAbove = Path();
    final pathBelow = Path();

    for (int i = first; i <= last; i++) {
      final x = t.xForIndex(i);
      final y = t.yForPrice(t.candles[i].close);
      if (i == first) {
        pathAbove.moveTo(x, y);
        pathBelow.moveTo(x, y);
      } else {
        pathAbove.lineTo(x, y);
        pathBelow.lineTo(x, y);
      }
    }

    canvas.drawPath(
      pathAbove,
      Paint()
        ..color = p.bullishColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  void _drawArea(Canvas canvas) {
    final t = p.transform;
    final first = t.firstVisibleIndex;
    final last = t.lastVisibleIndex;
    if (last <= first) return;

    final path = Path();
    final fillPath = Path();

    for (int i = first; i <= last; i++) {
      final x = t.xForIndex(i);
      final y = t.yForPrice(t.candles[i].close);
      if (i == first) {
        path.moveTo(x, y);
        fillPath.moveTo(x, p.layout.priceHeight);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(t.xForIndex(last), p.layout.priceHeight);
    fillPath.close();

    final up = t.candles[last].close >= t.candles[first].open;
    final lineColor = up ? p.bullishColor : p.bearishColor;

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, p.layout.priceHeight),
          [
            lineColor.withValues(alpha: 0.28),
            lineColor.withValues(alpha: 0.0),
          ],
        ),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawVolumeCandles(Canvas canvas) {
    final t = p.transform;
    final first = t.firstVisibleIndex;
    final last = t.lastVisibleIndex;

    var maxVol = 1.0;
    for (int i = first; i <= last; i++) {
      if (t.candles[i].volume > maxVol) maxVol = t.candles[i].volume;
    }

    final maxBodyWidth = math.max(3.0, t.candleWidth * 1.1);
    final wickWidth = math.max(0.6, math.min(1.4, t.candleWidth * 0.12));

    for (int i = first; i <= last; i++) {
      final c = t.candles[i];
      final x = t.xForIndex(i);
      final color = c.isBullish ? p.bullishColor : p.bearishColor;

      final highY = t.yForPrice(c.high);
      final lowY = t.yForPrice(c.low);
      final openY = t.yForPrice(c.open);
      final closeY = t.yForPrice(c.close);

      final volRatio = (c.volume / maxVol).clamp(0.25, 1.0);
      final bodyWidth = maxBodyWidth * volRatio;

      _fill.color = color;
      canvas.drawRect(
        Rect.fromLTRB(x - wickWidth / 2, highY, x + wickWidth / 2, lowY),
        _fill,
      );

      final top = math.min(openY, closeY);
      final bottom = math.max(openY, closeY);
      final bodyHeight = math.max(1.0, bottom - top);
      canvas.drawRect(
        Rect.fromLTWH(x - bodyWidth / 2, top, bodyWidth, bodyHeight),
        _fill,
      );
    }
  }


  // ==========================================================
  // LAST PRICE
  // ==========================================================

  /// Dashed horizontal line at the current (last close) price. Runs inside
  /// the clipped candle region only — the price badge for this line lives in
  /// the right-hand gutter and is drawn separately by [_drawLastPriceBadge],
  /// outside the clip, since the gutter starts at x = plotWidth.
  void _drawLastPriceLine(Canvas canvas) {
    final candles = p.candles;
    if (candles.isEmpty) return;

    final last = candles.last;
    final y = _clampedY(last.close);
    if (y == null) return;

    final isBull = last.close >= last.open;
    final color = isBull ? p.colors.positive : p.colors.negative;

    _stroke
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 1.0;
    _dashedLine(canvas, Offset(0, y), Offset(p.layout.plotWidth, y), _stroke);
  }

  /// Current-price badge in the right-hand price gutter: shows the live last
  /// price, colored green for an up (bullish) candle and red for a down
  /// (bearish) one, plus a countdown to the next candle close.
  void _drawLastPriceBadge(Canvas canvas) {
    final candles = p.candles;
    if (candles.isEmpty) return;

    final last = candles.last;
    final y = _clampedY(last.close);
    if (y == null) return;

    final isBull = last.close >= last.open;
    final color = isBull ? p.colors.positive : p.colors.negative;

    final priceText = p.instrument.formatPrice(last.close);
    final countdownText = _formatCandleCountdown(last.timestamp, p.timeframe);

    final tpPrice = _textPainter(priceText, color: Colors.white, size: 9.5, bold: true);
    final tpCount = _textPainter(countdownText, color: Colors.white.withValues(alpha: 0.9), size: 8.0, bold: true);

    final badgeWidth = math.min(
      p.layout.priceAxisWidth - 2,
      math.max(tpPrice.width, tpCount.width) + 10,
    );
    final badgeHeight = tpPrice.height + tpCount.height + 6;
    final clampedY = (y - badgeHeight / 2).clamp(2.0, p.layout.priceHeight - badgeHeight - 2);

    final rect = Rect.fromLTWH(
      p.layout.plotWidth + 2,
      clampedY,
      badgeWidth,
      badgeHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = color,
    );
    tpPrice.paint(canvas, Offset(rect.left + (badgeWidth - tpPrice.width) / 2, rect.top + 3));
    tpCount.paint(canvas, Offset(rect.left + (badgeWidth - tpCount.width) / 2, rect.top + tpPrice.height + 3));
  }

  String _formatCandleCountdown(int startMs, Timeframe tf) {
    final endMs = startMs + tf.duration.inMilliseconds;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final remainingSec = math.max(0, (endMs - nowMs) ~/ 1000);
    final h = remainingSec ~/ 3600;
    final m = (remainingSec % 3600) ~/ 60;
    final s = remainingSec % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (h > 0) return '${two(h)}:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }

  /// Y for a price, or null when it falls well outside the panel.
  double? _clampedY(double price) {
    final y = p.transform.yForPrice(price);
    if (y < -20 || y > p.layout.priceHeight + 20) return null;
    return y.clamp(0.0, p.layout.priceHeight);
  }

  void _drawCustomPriceLines(Canvas canvas) {
    if (p.customPriceLines.isEmpty) return;

    for (final price in p.customPriceLines) {
      final y = _clampedY(price);
      if (y == null) continue;

      _stroke
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.85)
        ..strokeWidth = 1.0;
      _dashedLine(canvas, Offset(0, y), Offset(p.layout.plotWidth, y), _stroke);
    }
  }

  void _drawCustomPriceBadges(Canvas canvas) {
    if (p.customPriceLines.isEmpty) return;

    const badgeColor = Color(0xFFF59E0B);
    for (final price in p.customPriceLines) {
      final y = _clampedY(price);
      if (y == null) continue;

      final priceText = p.instrument.formatPrice(price);
      final tpPrice = _textPainter(priceText, color: Colors.black, size: 9.0, bold: true);

      final badgeWidth = math.min(
        p.layout.priceAxisWidth - 2,
        tpPrice.width + 8,
      );
      final badgeHeight = tpPrice.height + 4;
      final clampedY = (y - badgeHeight / 2).clamp(2.0, p.layout.priceHeight - badgeHeight - 2);

      final rect = Rect.fromLTWH(
        p.layout.plotWidth + 2,
        clampedY,
        badgeWidth,
        badgeHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = badgeColor,
      );
      tpPrice.paint(canvas, Offset(rect.left + (badgeWidth - tpPrice.width) / 2, rect.top + 2));
    }
  }



  // ==========================================================
  // CROSSHAIR & POINTER
  // ==========================================================

  /// Dashed guide lines + center dot for the crosshair. Drawn inside the
  /// clipped candle region. The price/time badges are drawn separately by
  /// [_drawCrosshairBadges] outside the clip (see [_drawLastPriceBadge] for
  /// why: the price badge sits in the right-hand gutter at x = plotWidth,
  /// which this method's clip region does not include).
  void _drawCrosshairGuides(Canvas canvas) {
    final index = p.crosshairIndex!;
    final candles = p.candles;
    if (index < 0 || index >= candles.length) return;

    final t = p.transform;
    final x = t.xForIndex(index);
    final rawY = p.crosshairY ?? t.yForPrice(candles[index].close);
    final y = rawY.clamp(0.0, p.layout.priceHeight);

    _stroke
      ..color = p.colors.mutedForeground.withValues(alpha: 0.7)
      ..strokeWidth = 0.8;

    _dashedLine(canvas, Offset(x, 0), Offset(x, p.layout.timeAxisTop), _stroke);
    _dashedLine(canvas, Offset(0, y), Offset(p.layout.plotWidth, y), _stroke);

    final center = Offset(x, y);
    canvas.drawCircle(
      center,
      7.0,
      Paint()
        ..color = p.colors.primary.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      center,
      3.0,
      Paint()..color = p.colors.primary,
    );
  }

  /// Price badge (right gutter) + time badge (bottom axis) for the
  /// crosshair. The price badge is colored to match the touched candle's
  /// direction: green/bullish color for an up candle, red/bearish color for
  /// a down candle.
  void _drawCrosshairBadges(Canvas canvas) {
    final index = p.crosshairIndex!;
    final candles = p.candles;
    if (index < 0 || index >= candles.length) return;

    final t = p.transform;
    final x = t.xForIndex(index);
    final rawY = p.crosshairY ?? t.yForPrice(candles[index].close);
    final y = rawY.clamp(0.0, p.layout.priceHeight);

    // Price label on right Y-axis (attached, follows finger, rounded corners, bounded).
    final priceAtY = t.priceForY(y);
    final priceText = p.instrument.formatPrice(priceAtY);
    final priceTp = _textPainter(
      priceText,
      color: Colors.white,
      size: 9.5,
      bold: true,
    );

    final priceBadgeHeight = priceTp.height + 6;
    final priceBadgeWidth =
        math.min(p.layout.priceAxisWidth - 4, priceTp.width + 10);
    final clampedPriceY = (y - priceBadgeHeight / 2)
        .clamp(2.0, p.layout.priceHeight - priceBadgeHeight - 2);

    final priceRect = Rect.fromLTWH(
      p.layout.plotWidth + 2,
      clampedPriceY,
      priceBadgeWidth,
      priceBadgeHeight,
    );

    // Colored by the touched candle's direction: green for bullish, red for
    // bearish — matches the candle colors used everywhere else in the chart.
    final touchedCandle = candles[index];
    final isBull = touchedCandle.close >= touchedCandle.open;
    final crosshairColor = isBull ? p.colors.positive : p.colors.negative;

    canvas.drawRRect(
      RRect.fromRectAndRadius(priceRect, const Radius.circular(4)),
      Paint()..color = crosshairColor,
    );
    priceTp.paint(
      canvas,
      Offset(
        priceRect.left + (priceBadgeWidth - priceTp.width) / 2,
        priceRect.top + 3,
      ),
    );

    // Time label on bottom X-axis (attached, rounded corners, bounded).
    final timeText = _formatTime(candles[index].timestamp);
    final timeTp = _textPainter(
      timeText,
      color: Colors.white,
      size: 9.5,
      bold: true,
    );

    final timeBadgeHeight = timeTp.height + 5;
    final timeBadgeWidth = timeTp.width + 10;
    final clampedTimeX = (x - timeBadgeWidth / 2)
        .clamp(2.0, p.layout.plotWidth - timeBadgeWidth - 2);

    final timeRect = Rect.fromLTWH(
      clampedTimeX,
      p.layout.timeAxisTop + 2,
      timeBadgeWidth,
      timeBadgeHeight,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(timeRect, const Radius.circular(4)),
      Paint()..color = p.colors.foreground,
    );
    timeTp.paint(
      canvas,
      Offset(timeRect.left + 5, timeRect.top + 2.5),
    );
  }

  // ==========================================================
  // AXES
  // ==========================================================

  void _drawPriceAxis(Canvas canvas) {
    final t = p.transform;
    final lines = math.max(
      2,
      (p.layout.priceHeight / _priceLabelMinGap).floor(),
    );
    for (int i = 0; i <= lines; i++) {
      final y = (p.layout.priceHeight / lines) * i;
      final price = t.priceForY(y);
      final tp = _textPainter(
        p.instrument.formatPrice(price),
        color: p.colors.mutedForeground,
        size: 9,
      );
      tp.paint(canvas, Offset(p.layout.plotWidth + 5, y - tp.height / 2));
    }
  }

  void _drawTimeAxis(Canvas canvas) {
    final t = p.transform;
    final first = t.firstVisibleIndex;
    final last = t.lastVisibleIndex;
    final y = p.layout.timeAxisTop + 4;

    // Space labels out so they never overlap.
    const minGap = 62.0;
    var lastX = -1e9;

    for (int i = first; i <= last; i++) {
      final x = t.xForIndex(i);
      if (x - lastX < minGap) continue;
      if (x < 0 || x > p.layout.plotWidth) continue;
      lastX = x;

      final tp = _textPainter(
        _formatTime(t.candles[i].timestamp),
        color: p.colors.mutedForeground,
        size: 9,
      );
      tp.paint(canvas, Offset(x - tp.width / 2, y));
    }
  }

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    String two(int v) => v.toString().padLeft(2, '0');

    switch (p.timeframe) {
      case Timeframe.m1:
      case Timeframe.m5:
      case Timeframe.m15:
      case Timeframe.m30:
      case Timeframe.h1:
        return '${two(dt.hour)}:${two(dt.minute)}';
      case Timeframe.h4:
        return '${two(dt.day)}/${two(dt.month)} ${two(dt.hour)}h';
      case Timeframe.d1:
      case Timeframe.w1:
        return '${two(dt.day)}/${two(dt.month)}/${dt.year % 100}';
    }
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  TextPainter _textPainter(
    String text, {
    required Color color,
    required double size,
    bool bold = false,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _label(
      Canvas canvas, String text, Offset at, Color color, double size) {
    _textPainter(text, color: color, size: size).paint(canvas, at);
  }

  // ==========================================================
  // INDICATOR DRAWING METHODS
  // ==========================================================

  void _drawOverlayIndicators(Canvas canvas) {
    for (final type in p.enabledIndicators) {
      if (!type.isPriceOverlay) continue;
      final color = Color(type.colorValue);

      if (type == IndicatorType.bollingerBands) {
        _drawSeries(canvas, p.indicators.bbMiddle, color);
        _drawSeries(canvas, p.indicators.bbUpper, color.withValues(alpha: 0.7));
        _drawSeries(canvas, p.indicators.bbLower, color.withValues(alpha: 0.7));
      } else if (type == IndicatorType.superTrend) {
        _drawSuperTrend(canvas);
      } else {
        final series = p.indicators.seriesFor(type);
        if (series != null) {
          _drawSeries(canvas, series, color);
        }
      }
    }
  }

  void _drawSuperTrend(Canvas canvas) {
    final t = p.transform;
    final first = t.firstVisibleIndex;
    final last = t.lastVisibleIndex;
    final line = p.indicators.superTrend;
    final isBull = p.indicators.superTrendBullish;

    for (int i = first; i < last && i < line.length - 1; i++) {
      final y1 = line[i], y2 = line[i + 1];
      final b1 = isBull[i];
      if (y1 == null || y2 == null || b1 == null) continue;

      final x1 = t.xForIndex(i);
      final x2 = t.xForIndex(i + 1);
      final py1 = t.yForPrice(y1);
      final py2 = t.yForPrice(y2);

      final color = b1 ? const Color(0xFF10B981) : const Color(0xFFEF4444);
      canvas.drawLine(
        Offset(x1, py1),
        Offset(x2, py2),
        Paint()
          ..color = color
          ..strokeWidth = 1.8,
      );
    }
  }

  void _drawSeries(Canvas canvas, List<double?> series, Color color) {
    final t = p.transform;
    final first = t.firstVisibleIndex;
    final last = t.lastVisibleIndex;
    if (last < first || series.isEmpty) return;

    final plotWidth = p.layout.plotWidth;
    final priceHeight = p.layout.priceHeight;
    final minPrice = t.minPrice;
    final priceSpan = t.priceSpan;
    final pricePanOffset = t.pricePanOffset;

    final rightOffsetPx = t.rightOffsetPx;
    final candleWidth = t.candleWidth;
    final scrollOffset = t.scrollOffset;
    final newestIndex = t.candles.length - 1;
    final rightAnchor = plotWidth - rightOffsetPx - candleWidth / 2;

    double toX(int index) =>
        rightAnchor - (newestIndex - index) * candleWidth + scrollOffset;
    double toY(double price) =>
        priceHeight - ((price - minPrice) / priceSpan) * priceHeight + pricePanOffset;

    final path = Path();
    var started = false;

    final maxIdx = math.min(last, series.length - 1);
    for (int i = first; i <= maxIdx; i++) {
      final v = series[i];
      if (v == null) {
        started = false;
        continue;
      }
      final x = toX(i);
      final y = toY(v);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    _stroke
      ..color = color
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, _stroke);
  }

  void _drawVolumePanel(Canvas canvas) {
    final t = p.transform;
    final first = t.firstVisibleIndex;
    final last = t.lastVisibleIndex;
    if (last < first) return;

    final plotWidth = p.layout.plotWidth;
    final rightOffsetPx = t.rightOffsetPx;
    final candleWidth = t.candleWidth;
    final scrollOffset = t.scrollOffset;
    final newestIndex = t.candles.length - 1;
    final rightAnchor = plotWidth - rightOffsetPx - candleWidth / 2;

    double toX(int index) =>
        rightAnchor - (newestIndex - index) * candleWidth + scrollOffset;

    var maxVol = 0.0;
    for (int i = first; i <= last; i++) {
      final v = t.candles[i].volume;
      if (v > maxVol) maxVol = v;
    }
    if (maxVol <= 0) return;

    final baseY = p.layout.volumeTop + p.layout.volumeHeight;
    final barWidth = math.max(1.0, candleWidth * 0.72);
    final volHeightFactor = (p.layout.volumeHeight - 2) / maxVol;

    final posColor = p.colors.positive.withValues(alpha: 0.45);
    final negColor = p.colors.negative.withValues(alpha: 0.45);

    for (int i = first; i <= last; i++) {
      final c = t.candles[i];
      final h = c.volume * volHeightFactor;
      final x = toX(i);
      _fill.color = c.isBullish ? posColor : negColor;
      canvas.drawRect(
        Rect.fromLTWH(x - barWidth / 2, baseY - h, barWidth, h),
        _fill,
      );
    }
    _label(canvas, 'Volume', Offset(4, p.layout.volumeTop + 2),
        p.colors.mutedForeground, 8.5);
  }

  void _drawMacdPanel(Canvas canvas) {
    final t = p.transform;
    final first = t.firstVisibleIndex;
    final last = t.lastVisibleIndex;
    final top = p.layout.macdTop;
    final h = p.layout.macdHeight;
    if (h <= 0) return;

    final line = p.indicators.macdLine;
    final signal = p.indicators.macdSignal;
    final hist = p.indicators.macdHist;

    var maxAbs = 0.0;
    for (int i = first; i <= last; i++) {
      for (final s in [line, signal, hist]) {
        if (i < s.length && s[i] != null) {
          maxAbs = math.max(maxAbs, s[i]!.abs());
        }
      }
    }
    if (maxAbs <= 0) return;

    final centre = top + h / 2;
    final halfSpan = h / 2 - 4;
    double toY(double v) => centre - (v / maxAbs) * halfSpan;

    final linePaint = Paint()
      ..color = p.colors.border.withValues(alpha: 0.4)
      ..strokeWidth = 0.8;
    canvas.drawLine(
        Offset(0, centre), Offset(p.layout.plotWidth, centre), linePaint);

    final barWidth = math.max(1.0, t.candleWidth * 0.6);
    for (int i = first; i <= last && i < hist.length; i++) {
      final v = hist[i];
      if (v == null) continue;
      final x = t.xForIndex(i);
      final y = toY(v);
      _fill.color = (v >= 0 ? p.colors.positive : p.colors.negative)
          .withValues(alpha: 0.5);
      canvas.drawRect(
        Rect.fromLTRB(x - barWidth / 2, math.min(y, centre), x + barWidth / 2,
            math.max(y, centre)),
        _fill,
      );
    }

    _drawPanelLine(canvas, line, const Color(0xFF60A5FA), first, last, toY);
    _drawPanelLine(canvas, signal, const Color(0xFFF59E0B), first, last, toY);
    _label(canvas, 'MACD 12 26 9', Offset(4, top + 2),
        p.colors.mutedForeground, 8.5);
  }

  void _drawRsiPanel(Canvas canvas) {
    final t = p.transform;
    final first = t.firstVisibleIndex;
    final last = t.lastVisibleIndex;
    final top = p.layout.rsiTop;
    final h = p.layout.rsiHeight;
    if (h <= 0) return;

    final rsi = p.indicators.rsi;
    double toY(double v) => top + h - (v / 100.0) * (h - 4);

    final linePaint = Paint()
      ..color = p.colors.border.withValues(alpha: 0.4)
      ..strokeWidth = 0.8;

    _dashedLine(canvas, Offset(0, toY(70)), Offset(p.layout.plotWidth, toY(70)), linePaint);
    _dashedLine(canvas, Offset(0, toY(30)), Offset(p.layout.plotWidth, toY(30)), linePaint);

    _drawPanelLine(canvas, rsi, const Color(0xFFA78BFA), first, last, toY);
    _label(canvas, 'RSI (14)', Offset(4, top + 2), p.colors.mutedForeground, 8.5);
  }

  void _drawAtrPanel(Canvas canvas) {
    final t = p.transform;
    final first = t.firstVisibleIndex;
    final last = t.lastVisibleIndex;
    final top = p.layout.atrTop;
    final h = p.layout.atrHeight;
    if (h <= 0) return;

    final atr = p.indicators.atr;
    var maxVal = 0.0;
    for (int i = first; i <= last && i < atr.length; i++) {
      if (atr[i] != null) maxVal = math.max(maxVal, atr[i]!);
    }
    if (maxVal <= 0) return;

    double toY(double v) => top + h - (v / maxVal) * (h - 6);

    _drawPanelLine(canvas, atr, const Color(0xFFFF7096), first, last, toY);
    _label(canvas, 'ATR (14)', Offset(4, top + 2), p.colors.mutedForeground, 8.5);
  }

  void _drawStochRsiPanel(Canvas canvas) {
    final t = p.transform;
    final first = t.firstVisibleIndex;
    final last = t.lastVisibleIndex;
    final top = p.layout.stochRsiTop;
    final h = p.layout.stochRsiHeight;
    if (h <= 0) return;

    final k = p.indicators.stochK;
    final d = p.indicators.stochD;
    double toY(double v) => top + h - (v / 100.0) * (h - 4);

    final linePaint = Paint()
      ..color = p.colors.border.withValues(alpha: 0.4)
      ..strokeWidth = 0.8;

    _dashedLine(canvas, Offset(0, toY(80)), Offset(p.layout.plotWidth, toY(80)), linePaint);
    _dashedLine(canvas, Offset(0, toY(20)), Offset(p.layout.plotWidth, toY(20)), linePaint);

    _drawPanelLine(canvas, k, const Color(0xFFC77DFF), first, last, toY);
    _drawPanelLine(canvas, d, const Color(0xFF38BDF8), first, last, toY);
    _label(canvas, 'Stoch RSI', Offset(4, top + 2), p.colors.mutedForeground, 8.5);
  }

  void _drawPanelLine(
    Canvas canvas,
    List<double?> series,
    Color color,
    int first,
    int last,
    double Function(double) toY,
  ) {
    final t = p.transform;
    final path = Path();
    var started = false;

    for (int i = first; i <= last && i < series.length; i++) {
      final v = series[i];
      if (v == null) {
        started = false;
        continue;
      }
      final x = t.xForIndex(i);
      final y = toY(v);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    _stroke
      ..color = color
      ..strokeWidth = 1.1;
    canvas.drawPath(path, _stroke);
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 4.0;
    const gap = 3.0;
    final total = (to - from).distance;
    if (total <= 0) return;
    final dir = (to - from) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final segment = math.min(dash, total - drawn);
      canvas.drawLine(
        from + dir * drawn,
        from + dir * (drawn + segment),
        paint,
      );
      drawn += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant ChartPainter old) {
    final a = old.p, b = p;
    return a.transform.scrollOffset != b.transform.scrollOffset ||
        a.transform.candleWidth != b.transform.candleWidth ||
        a.transform.minPrice != b.transform.minPrice ||
        a.transform.maxPrice != b.transform.maxPrice ||
        a.transform.chartWidth != b.transform.chartWidth ||
        a.transform.priceHeight != b.transform.priceHeight ||
        a.transform.candles.length != b.transform.candles.length ||
        !identical(a.transform.candles, b.transform.candles) ||
        a.crosshairIndex != b.crosshairIndex ||
        a.crosshairY != b.crosshairY ||
        a.showCrosshairLabels != b.showCrosshairLabels ||
        a.customPriceLines != b.customPriceLines ||
        a.style != b.style ||
        a.colors != b.colors ||
        a.enabledIndicators.length != b.enabledIndicators.length ||
        !identical(a.indicators, b.indicators);
  }
}
