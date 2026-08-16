/// Chart Snapshot & Share — captures the chart (candles + drawings) as a PNG,
/// composites a branded header/watermark on top, and hands it to the platform
/// share sheet.
///
/// Capture uses `RenderRepaintBoundary.toImage()` on the boundary
/// [ChartView] exposes via `snapshotKey`, so the exported image is pixel-for-
/// pixel what the user sees, including active indicators (painted as part of
/// the candle layer) and every annotation (the drawing layer).
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:app/constants/colors.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/models/instrument.dart';

/// Render scale for the captured chart layer. 2x keeps it crisp on
/// high-density screens without producing an unreasonably large PNG.
const double kSnapshotPixelRatio = 2.5;

class ChartSnapshotService {
  ChartSnapshotService._();

  /// Capture the chart at [key], brand it, and open the platform share sheet.
  ///
  /// Returns true on success. Failures are logged and surfaced to the caller
  /// as false rather than thrown, since a failed share should not crash the
  /// chart screen the user is actively looking at.
  static Future<bool> captureAndShare({
    required GlobalKey key,
    required Instrument instrument,
    required Timeframe timeframe,
    required double lastPrice,
    required double changePercent,
    required ThemePalette colors,
  }) async {
    try {
      final branded = await captureOnly(
        key: key,
        instrument: instrument,
        timeframe: timeframe,
        lastPrice: lastPrice,
        changePercent: changePercent,
        colors: colors,
      );
      if (branded == null) return false;

      final file = await _writeTempFile(branded, instrument.symbol);

      final result = await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: '${instrument.displayName} · ${timeframe.label} · '
            '${instrument.formatPrice(lastPrice)} '
            '(${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%) '
            '— via Charty',
        subject: '${instrument.displayName} chart',
      ));

      return result.status != ShareResultStatus.dismissed;
    } catch (e) {
      Logger.instance.error('Chart snapshot/share failed: $e');
      return false;
    }
  }

  /// Capture and brand only, for a "Save to device" flow without the share
  /// sheet. Returns the branded PNG bytes, or null on failure.
  static Future<Uint8List?> captureOnly({
    required GlobalKey key,
    required Instrument instrument,
    required Timeframe timeframe,
    required double lastPrice,
    required double changePercent,
    required ThemePalette colors,
  }) async {
    try {
      final chartBytes = await _captureBoundary(key);
      if (chartBytes == null) return null;
      return _compose(
        chartPng: chartBytes,
        instrument: instrument,
        timeframe: timeframe,
        lastPrice: lastPrice,
        changePercent: changePercent,
        colors: colors,
      );
    } catch (e) {
      Logger.instance.error('Chart snapshot capture failed: $e');
      return null;
    }
  }

  // ==========================================================
  // CAPTURE
  // ==========================================================

  static Future<Uint8List?> _captureBoundary(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return null;

    final boundary = context.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return null;

    // A boundary mid-layout has no committed pixels yet; give it one frame.
    if (boundary.debugNeedsPaint) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    final image = await boundary.toImage(pixelRatio: kSnapshotPixelRatio);
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  // ==========================================================
  // COMPOSITION (header + watermark)
  // ==========================================================

  static Future<Uint8List> _compose({
    required Uint8List chartPng,
    required Instrument instrument,
    required Timeframe timeframe,
    required double lastPrice,
    required double changePercent,
    required ThemePalette colors,
  }) async {
    final chartImage = await _decode(chartPng);

    const headerHeight = 110.0;
    const footerHeight = 56.0;
    const scale = kSnapshotPixelRatio;

    final canvasWidth = chartImage.width.toDouble();
    final canvasHeight =
        chartImage.height + headerHeight * scale + footerHeight * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
    );

    // Background matches the app theme so light/dark exports look native.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
      Paint()..color = colors.background,
    );

    _paintHeader(
      canvas,
      width: canvasWidth,
      height: headerHeight * scale,
      instrument: instrument,
      timeframe: timeframe,
      lastPrice: lastPrice,
      changePercent: changePercent,
      colors: colors,
      scale: scale,
    );

    final imagePaint = Paint();
    canvas.drawImage(
      chartImage,
      const Offset(0, headerHeight * scale),
      imagePaint,
    );

    _paintWatermark(
      canvas,
      width: canvasWidth,
      top: headerHeight * scale + chartImage.height,
      height: footerHeight * scale,
      colors: colors,
      scale: scale,
    );

    final picture = recorder.endRecording();
    final composed = await picture.toImage(
      canvasWidth.round(),
      canvasHeight.round(),
    );

    try {
      final byteData =
          await composed.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } finally {
      picture.dispose();
      composed.dispose();
      chartImage.dispose();
    }
  }

  static void _paintHeader(
    Canvas canvas, {
    required double width,
    required double height,
    required Instrument instrument,
    required Timeframe timeframe,
    required double lastPrice,
    required double changePercent,
    required ThemePalette colors,
    required double scale,
  }) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = colors.card,
    );
    canvas.drawLine(
      Offset(0, height),
      Offset(width, height),
      Paint()
        ..color = colors.border
        ..strokeWidth = scale,
    );

    final up = changePercent >= 0;
    final accent = up ? colors.positive : colors.negative;
    final pad = 20.0 * scale;

    _text(
      canvas,
      instrument.displayName,
      Offset(pad, 16 * scale),
      color: colors.foreground,
      fontSize: 26 * scale,
      bold: true,
    );

    _text(
      canvas,
      timeframe.label,
      Offset(width - pad - 70 * scale, 20 * scale),
      color: colors.mutedForeground,
      fontSize: 18 * scale,
      bold: true,
      align: TextAlign.right,
      maxWidth: 70 * scale,
    );

    _text(
      canvas,
      instrument.formatPrice(lastPrice),
      Offset(pad, 56 * scale),
      color: colors.foreground,
      fontSize: 20 * scale,
      bold: true,
    );

    _text(
      canvas,
      '${up ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
      Offset(pad + 170 * scale, 58 * scale),
      color: accent,
      fontSize: 16 * scale,
      bold: true,
    );
  }

  static void _paintWatermark(
    Canvas canvas, {
    required double width,
    required double top,
    required double height,
    required ThemePalette colors,
    required double scale,
  }) {
    canvas.drawRect(
      Rect.fromLTWH(0, top, width, height),
      Paint()..color = colors.card,
    );
    canvas.drawLine(
      Offset(0, top),
      Offset(width, top),
      Paint()
        ..color = colors.border
        ..strokeWidth = scale,
    );

    final pad = 20.0 * scale;

    _text(
      canvas,
      'Charty',
      Offset(pad, top + 16 * scale),
      color: colors.primary,
      fontSize: 20 * scale,
      bold: true,
    );

    _text(
      canvas,
      'Market data by Binance · charty.app',
      Offset(width - pad - 280 * scale, top + 19 * scale),
      color: colors.mutedForeground,
      fontSize: 13 * scale,
      align: TextAlign.right,
      maxWidth: 280 * scale,
    );
  }

  static void _text(
    Canvas canvas,
    String text,
    Offset at, {
    required Color color,
    required double fontSize,
    bool bold = false,
    TextAlign align = TextAlign.left,
    double? maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth ?? double.infinity);

    painter.paint(canvas, at);
  }

  static Future<ui.Image> _decode(Uint8List bytes) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, completer.complete);
    return completer.future;
  }

  // ==========================================================
  // FILE I/O
  // ==========================================================

  static Future<File> _writeTempFile(Uint8List bytes, String symbol) async {
    final dir = await getTemporaryDirectory();
    final safeSymbol = symbol.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final path =
        '${dir.path}/charty_${safeSymbol}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(path);
    await file.writeAsBytes(bytes);
    return file;
  }
}
