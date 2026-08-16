/// Interactive chart surface.
///
/// Owns viewport state (zoom + scroll) and gesture arbitration. Data comes from
/// a [ChartDataSource] (live [ChartController] or replay [ReplayController]);
/// drawings from [DrawingController]. Painting is split into two layers so
/// overlay edits do not re-rasterise the candles.
///
/// Gesture modes are resolved on touch-down, so a single drag can only ever
/// mean one thing:
///   • two fingers                → zoom + pan
///   • drawing tool active        → place anchors
///   • grab a handle of selection → move that handle
///   • drag the body of selection → move the whole shape
///   • otherwise                  → pan
/// A long press always arms the crosshair.
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app/components/chart/chart_layout.dart';
import 'package:app/components/chart/chart_painter.dart';
import 'package:app/components/chart/chart_transform.dart';
import 'package:app/components/chart/drawing_customization_sheet.dart';
import 'package:app/components/chart/drawing_geometry.dart';
import 'package:app/components/chart/drawing_painter.dart';
import 'package:app/components/chart/floating_measurement_card.dart';
import 'package:app/components/chart/smart_candle_sheet.dart';
import 'package:app/constants/colors.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/candle_analytics.dart';
import 'package:app/engine/candle_story.dart';
import 'package:app/engine/chart_data_source.dart';
import 'package:app/engine/drawing_controller.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/engine/magnetic_snap.dart';
import 'package:app/engine/measurement_calculator.dart';
import 'package:app/engine/session_overlay.dart';
import 'package:app/models/drawing.dart';
import 'package:app/models/instrument.dart';
import 'package:app/models/user_profile.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/utils/haptics.dart';

/// Zoom bounds, in pixels per candle.
const double kMinCandleWidth = 1.5;
const double kMaxCandleWidth = 40.0;
const double kDefaultCandleWidth = 7.0;

/// Vertical padding applied to the autoscaled price range.
const double kPricePadFraction = 0.08;

enum _DragMode { none, pan, placing, moveHandle, moveShape, priceScale }

class ChartView extends StatefulWidget {
  final ChartDataSource controller;
  final DrawingController drawings;
  final ChartStyle style;

  /// Called when the crosshair moves, so a parent can show an OHLC readout.
  final ValueChanged<int?>? onCrosshairIndex;

  /// When provided, wraps exactly the candle + drawing paint layers (not the
  /// loading/OHLC chip overlays) in a [RepaintBoundary] addressed by this key,
  /// so a parent can capture a clean snapshot via
  /// `ChartSnapshot.capture(key)` for export/sharing.
  final GlobalKey? snapshotKey;

  const ChartView({
    super.key,
    required this.controller,
    required this.drawings,
    this.style = ChartStyle.candles,
    this.onCrosshairIndex,
    this.snapshotKey,
  });

  @override
  State<ChartView> createState() => _ChartViewState();
}

typedef ChartViewRefState = _ChartViewState;

class _ChartViewState extends State<ChartView> with TickerProviderStateMixin {
  double _candleWidth = kDefaultCandleWidth;
  double _scrollOffset = 0.0;
  double _priceScaleRatio = 1.0;
  double _pricePanOffset = 0.0;

  int? _crosshairIndex;
  double? _crosshairY;
  double? _crosshairPixelX;
  Offset? _lastLongPressOffset;

  /// Snap indicator location for drawing painter.
  Offset? _snapPoint;

  /// Last candle index a haptic "tick" fired for, so crosshair movement only
  /// buzzes once per candle crossed rather than continuously.
  int? _lastHapticCandleIndex;

  _DragMode _mode = _DragMode.none;
  double _scaleStartWidth = kDefaultCandleWidth;
  double _scaleStartPriceRatio = 1.0;
  Offset? _lastFocalPoint;
  Offset? _drawTouchStartPoint;
  bool _drawTouchDragged = false;
  String? _activeDrawingId;
  int? _activeHandle;

  /// Set while a history page is requested, to avoid re-triggering per frame.
  bool _historyRequested = false;

  Size _size = Size.zero;

  /// Session overlay configuration, shared with the toolbar.
  late final SessionOverlayConfig _sessionConfig;

  late final AnimationController _inertiaController;
  Animation<double>? _inertiaAnimation;
  double _lastInertiaVal = 0.0;
  AnimationController? _resetAnimController;

  @override
  void initState() {
    super.initState();
    _sessionConfig = context.read<AppState>().profile.sessionConfig;
    widget.controller.addListener(_onData);
    _inertiaController = AnimationController(vsync: this);
    _inertiaController.addListener(_onInertiaTick);
  }

  @override
  void didUpdateWidget(ChartView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onData);
      widget.controller.addListener(_onData);
      _resetViewport();
    }
  }

  @override
  void dispose() {
    _inertiaController.dispose();
    _resetAnimController?.dispose();
    widget.controller.removeListener(_onData);
    super.dispose();
  }

  void _onInertiaTick() {
    if (_inertiaAnimation == null || _size == Size.zero) return;
    final delta = _inertiaAnimation!.value - _lastInertiaVal;
    _lastInertiaVal = _inertiaAnimation!.value;
    if (delta.abs() < 0.01) return;

    final layout = _layout(_size);
    final t = _transform(layout);
    setState(() {
      _scrollOffset += delta;
      _clampScroll(t);
    });
    _maybeLoadHistory(t);
  }

  void _startInertia(double velocityX) {
    _inertiaController.stop();
    _lastInertiaVal = 0.0;

    final distance = (velocityX * 0.35).clamp(-2500.0, 2500.0);
    final durationMs = (distance.abs() * 0.25).clamp(180.0, 500.0).toInt();

    _inertiaAnimation = Tween<double>(begin: 0.0, end: distance).animate(
      CurvedAnimation(parent: _inertiaController, curve: Curves.decelerate),
    );

    _inertiaController.duration = Duration(milliseconds: durationMs);
    _inertiaController.forward(from: 0.0);
  }

  void _onData() {
    if (!mounted) return;
    _historyRequested = false;
    setState(() {});
  }

  void _resetViewport() {
    _candleWidth = kDefaultCandleWidth;
    _scrollOffset = 0.0;
    _crosshairIndex = null;
    _crosshairY = null;
    widget.onCrosshairIndex?.call(null);
  }

  void resetView() {
    setState(() {
      _resetViewport();
      _pricePanOffset = 0.0;
    });
  }

  // ==========================================================
  // TRANSFORM
  // ==========================================================

  ChartLayout _layout(Size size) => ChartLayout.forPanels(
    width: size.width,
    height: size.height,
    showVolume: widget.controller.enabledIndicators.contains(
      IndicatorType.volume,
    ),
    showMacd: widget.controller.enabledIndicators.contains(IndicatorType.macd),
    showRsi: widget.controller.enabledIndicators.contains(IndicatorType.rsi),
    showAtr: widget.controller.enabledIndicators.contains(IndicatorType.atr),
    showStochRsi: widget.controller.enabledIndicators.contains(
      IndicatorType.stochRsi,
    ),
  );

  ChartTransform _transform(ChartLayout layout) {
    final c = widget.controller;
    final candles = c.candles;
    final profile = context.watch<AppState>().profile;

    if (candles.isEmpty) {
      return ChartTransform(
        candles: const [],
        candleWidth: _candleWidth,
        scrollOffset: _scrollOffset,
        chartWidth: layout.plotWidth,
        priceHeight: layout.priceHeight,
        minPrice: 0,
        maxPrice: 1,
        intervalMs: c.timeframe.durationMs,
        rightOffsetFraction: profile.rightOffsetFraction,
      );
    }

    // Build a provisional transform to learn which candles are visible, then
    // autoscale the price axis to just those.
    final probe = ChartTransform(
      candles: candles,
      candleWidth: _candleWidth,
      scrollOffset: _scrollOffset,
      chartWidth: layout.plotWidth,
      priceHeight: layout.priceHeight,
      minPrice: 0,
      maxPrice: 1,
      intervalMs: c.timeframe.durationMs,
      rightOffsetFraction: profile.rightOffsetFraction,
    );

    final range = profile.autoScale
        ? c.priceRange(probe.firstVisibleIndex, probe.lastVisibleIndex)
        : c.priceRange(0, candles.length - 1);
    final pad = (range.max - range.min) * kPricePadFraction;

    final midPrice = (range.min + range.max) / 2.0;
    final halfSpan =
        (math.max(1e-6, (range.max - range.min) / 2.0) + pad) *
        _priceScaleRatio;

    return probe.copyWith(
      minPrice: midPrice - halfSpan,
      maxPrice: midPrice + halfSpan,
      pricePanOffset: _pricePanOffset,
    );
  }

  // ==========================================================
  // VIEWPORT
  // ==========================================================

  void _clampScroll(ChartTransform t) {
    _scrollOffset = _scrollOffset.clamp(
      t.minScrollOffset,
      math.max(0.0, t.maxScrollOffset),
    );
  }

  void _maybeLoadHistory(ChartTransform t) {
    if (_historyRequested) return;
    if (!widget.controller.hasMoreHistory) return;
    if (widget.controller.isLoadingHistory) return;
    if (!t.isNearLeftEdge()) return;

    _historyRequested = true;
    // No scroll compensation needed: xForIndex positions every candle by its
    // distance from the newest one, so prepending older candles at the front
    // of the list does not move any already-visible candle. Adjusting
    // scrollOffset here would introduce a jump, not prevent one.
    widget.controller.loadMoreHistory();
  }

  // ==========================================================
  // GESTURES
  // ==========================================================

  void _onScaleStart(ScaleStartDetails d) {
    _inertiaController.stop();
    _scaleStartWidth = _candleWidth;
    _scaleStartPriceRatio = _priceScaleRatio;
    _lastFocalPoint = d.localFocalPoint;

    final layout = _layout(_size);

    // Price bar scale gesture (dragging vertically on right price axis)
    if (!widget.drawings.isDrawing &&
        d.localFocalPoint.dx >= layout.plotWidth) {
      if (context.read<AppState>().profile.chartLocked) return;
      _mode = _DragMode.priceScale;
      Haptics.selection();
      return;
    }

    final t = _transform(layout);

    // GESTURE PRIORITY #1: DRAWING MODE (Disables Chart Pan, Inertial Drag & Zoom)
    if (widget.drawings.isDrawing) {
      _mode = _DragMode.placing;
      _drawTouchStartPoint = d.localFocalPoint;
      _drawTouchDragged = false;

      final pending = widget.drawings.pending;
      if (pending == null) {
        _placeAnchor(d.localFocalPoint, t, isFirst: true);
      } else {
        widget.drawings.updatePendingLastAnchor(
          _snappedAnchor(d.localFocalPoint, t),
        );
      }
      return;
    }

    if (d.pointerCount >= 2) {
      _mode = _DragMode.pan; // zoom is handled in update
      return;
    }

    // GESTURE PRIORITY #2: DRAWING EDITING
    //
    // Hit-test every drawing (not just whichever one happens to already be
    // selected), so any drawn tool can be grabbed and dragged — by its body
    // or a handle — in a single gesture. Touching it here both selects it
    // and starts the move; a separate prior tap-to-select is no longer
    // required.
    final hit = DrawingGeometry.topmostAt(
      widget.drawings.drawings,
      t,
      d.localFocalPoint,
      chartWidth: layout.plotWidth,
    );
    if (hit != null) {
      if (widget.drawings.selectedId != hit.id) {
        widget.drawings.select(hit.id);
      }
      final handle = DrawingGeometry.handleAt(hit, t, d.localFocalPoint);
      if (handle != null) {
        _mode = _DragMode.moveHandle;
        _activeHandle = handle;
        _activeDrawingId = hit.id;
        widget.drawings.beginTransientEdit();
        Haptics.light();
        return;
      }
      _mode = _DragMode.moveShape;
      _activeDrawingId = hit.id;
      widget.drawings.beginTransientEdit();
      Haptics.light();
      return;
    }

    if (context.read<AppState>().profile.chartLocked) {
      _mode = _DragMode.none;
      return;
    }

    _mode = _DragMode.pan;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final layout = _layout(_size);
    final t = _transform(layout);

    // Pinch zoom, anchored so the candle under the fingers stays put.
    if (d.pointerCount >= 2) {
      if (widget.drawings.isDrawing ||
          context.read<AppState>().profile.chartLocked) {
        return;
      } // Disable zoom while drawing or locked
      final anchorIndex = t.indexForX(d.localFocalPoint.dx);
      final nextWidth = (_scaleStartWidth * d.scale).clamp(
        kMinCandleWidth,
        kMaxCandleWidth,
      );
      final focalX = d.localFocalPoint.dx;
      final newestIndex = widget.controller.candles.length - 1;

      setState(() {
        _candleWidth = nextWidth;
        final rightAnchor = layout.plotWidth - t.rightOffsetPx - nextWidth / 2;
        final fromNewest = newestIndex - anchorIndex;
        _scrollOffset = focalX - rightAnchor + fromNewest * nextWidth;
        _clampScroll(
          t.copyWith(candleWidth: nextWidth, scrollOffset: _scrollOffset),
        );
      });
      _maybeLoadHistory(_transform(layout));
      return;
    }

    switch (_mode) {
      case _DragMode.placing:
        if (_drawTouchStartPoint != null) {
          final dist = (d.localFocalPoint - _drawTouchStartPoint!).distance;
          if (dist > 8.0) {
            _drawTouchDragged = true;
          }
        }
        if (widget.drawings.activeTool == DrawingTool.brush) {
          widget.drawings.appendPointToPending(
            _snappedAnchor(d.localFocalPoint, t),
          );
        } else {
          // Continuous live update — preview follows finger in real-time!
          widget.drawings.updatePendingLastAnchor(
            _snappedAnchor(d.localFocalPoint, t),
          );
        }
        break;

      case _DragMode.moveHandle:
        final id = _activeDrawingId;
        final handle = _activeHandle;
        if (id != null && handle != null) {
          widget.drawings.moveAnchor(
            id,
            handle,
            _snappedAnchor(d.localFocalPoint, t),
          );
        }
        break;

      case _DragMode.moveShape:
        final id = _activeDrawingId;
        final last = _lastFocalPoint;
        if (id != null && last != null) {
          final from = _anchorAt(last, t);
          final to = _anchorAt(d.localFocalPoint, t);
          widget.drawings.translate(
            id,
            to.timestamp - from.timestamp,
            to.price - from.price,
          );
        }
        _lastFocalPoint = d.localFocalPoint;
        break;

      case _DragMode.priceScale:
        setState(() {
          if (d.scale != 1.0 && d.pointerCount >= 2) {
            _priceScaleRatio = (_scaleStartPriceRatio / d.scale).clamp(
              0.05,
              20.0,
            );
          } else if (d.focalPointDelta.dy != 0) {
            final factor = 1.0 + (d.focalPointDelta.dy / 100.0);
            _priceScaleRatio = (_priceScaleRatio * factor).clamp(0.05, 20.0);
          }
        });
        break;

      case _DragMode.pan:
      case _DragMode.none:
        if (widget.drawings.isDrawing ||
            context.read<AppState>().profile.chartLocked) {
          break;
        } // Disable pan while drawing or locked!
        setState(() {
          _scrollOffset += d.focalPointDelta.dx;
          if (d.pointerCount >= 2 || _pricePanOffset != 0.0) {
            _pricePanOffset += d.focalPointDelta.dy;
          }
          _clampScroll(t);
        });
        _maybeLoadHistory(t);
        break;
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    final layout = _layout(_size);
    final t = _transform(layout);

    if (_mode == _DragMode.placing) {
      final pending = widget.drawings.pending;
      if (pending != null && pending.anchors.isNotEmpty) {
        if (pending.tool == DrawingTool.brush) {
          widget.drawings.commitPending();
        } else if (_drawTouchDragged && _lastFocalPoint != null) {
          _confirmAnchorB(_lastFocalPoint!, t);
        }
      }
    }

    final id = _activeDrawingId;
    if (id != null &&
        (_mode == _DragMode.moveHandle || _mode == _DragMode.moveShape)) {
      widget.drawings.commitEdit(id);
    }

    final velocityX = d.velocity.pixelsPerSecond.dx;
    if (_mode == _DragMode.pan &&
        velocityX.abs() > 120 &&
        !widget.drawings.isDrawing &&
        !context.read<AppState>().profile.chartLocked) {
      _startInertia(velocityX);
    }

    _mode = _DragMode.none;
    _activeHandle = null;
    _activeDrawingId = null;
    _lastFocalPoint = null;
    _drawTouchStartPoint = null;
    _drawTouchDragged = false;
    _snapPoint = null;
  }

  Future<void> _placeAnchor(
    Offset at,
    ChartTransform t, {
    required bool isFirst,
  }) async {
    final anchor = _snappedAnchor(at, t);
    if (isFirst) {
      if (widget.drawings.activeTool == DrawingTool.text ||
          widget.drawings.activeTool == DrawingTool.callout) {
        final text = await _promptTextDialog(context);
        if (text != null && text.isNotEmpty) {
          await widget.drawings.addAnchor(anchor, text: text);
          Haptics.light();
        } else {
          widget.drawings.cancelPending();
        }
      } else {
        await widget.drawings.addAnchor(anchor);
        Haptics.light();
      }
    } else {
      widget.drawings.updatePendingLastAnchor(anchor);
    }
  }

  /// Resolve an anchor, applying magnetic snap if active.
  DrawingAnchor _snappedAnchor(Offset at, ChartTransform t) {
    final mode = widget.drawings.magneticMode;
    if (mode != MagneticMode.off) {
      final result = MagnetSnapEngine.snap(
        pixelX: at.dx,
        pixelY: at.dy,
        mode: mode,
        transform: t,
        candles: widget.controller.candles,
        existingDrawings: widget.drawings.drawings,
      );
      if (result != null) {
        Haptics.light();
        _snapPoint = Offset(result.pixelX, result.pixelY);
        return result.anchor;
      }
    }
    _snapPoint = null;
    return DrawingAnchor(
      timestamp: t.timestampForX(at.dx),
      price: t.priceForY(at.dy),
    );
  }

  void _openCustomizationSheet(Drawing drawing) {
    Haptics.light();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DrawingCustomizationSheet(
        drawing: drawing,
        controller: widget.drawings,
      ),
    );
  }

  bool _isTapOnCandleBody(Offset pos, ChartTransform t) {
    final candles = widget.controller.candles;
    if (candles.isEmpty) return false;
    final index = t.nearestIndexForX(pos.dx);
    if (index < 0 || index >= candles.length) return false;

    final c = candles[index];
    final cx = t.xForIndex(index);
    final bodyWidth = math.max(4.0, t.candleWidth * 0.9);

    if ((pos.dx - cx).abs() > bodyWidth / 2 + 5.0) return false;

    final openY = t.yForPrice(c.open);
    final closeY = t.yForPrice(c.close);
    final highY = t.yForPrice(c.high);
    final lowY = t.yForPrice(c.low);

    final minY = math.min(highY, math.min(openY, closeY)) - 8.0;
    final maxY = math.max(lowY, math.max(openY, closeY)) + 8.0;

    return pos.dy >= minY && pos.dy <= maxY;
  }

  DrawingAnchor _anchorAt(Offset at, ChartTransform t) => DrawingAnchor(
    timestamp: t.timestampForX(at.dx),
    price: t.priceForY(at.dy),
  );

  void _onTapUp(TapUpDetails d) {
    final layout = _layout(_size);
    final t = _transform(layout);

    // Placing shape by tapping.
    if (widget.drawings.isDrawing) {
      final pending = widget.drawings.pending;
      if (pending == null) {
        _placeAnchor(d.localPosition, t, isFirst: true);
      } else if (pending.anchors.isNotEmpty) {
        _confirmAnchorB(d.localPosition, t);
      }
      return;
    }

    // Select or deselect drawing if hit.
    final hit = DrawingGeometry.topmostAt(
      widget.drawings.drawings,
      t,
      d.localPosition,
      chartWidth: layout.plotWidth,
    );

    if (hit != null) {
      Haptics.selection();
      if (widget.drawings.selectedId == hit.id) {
        // Just keep selected, no customization sheet
      } else {
        widget.drawings.select(hit.id);
      }
    } else {
      if (widget.drawings.selectedId != null) Haptics.light();
      widget.drawings.select(null);
    }

    // Tap candle body directly to open Smart Candle Statistics panel!
    if (hit == null &&
        !widget.drawings.isDrawing &&
        _isTapOnCandleBody(d.localPosition, t)) {
      final index = t.nearestIndexForX(d.localPosition.dx);
      if (index >= 0 && index < widget.controller.candles.length) {
        _showCandleSheet(index);
      }
    }

    if (_crosshairIndex != null) {
      setState(() {
        _crosshairIndex = null;
        _crosshairY = null;
      });
      widget.onCrosshairIndex?.call(null);
    }
  }

  Future<void> _confirmAnchorB(Offset at, ChartTransform t) async {
    final anchor = _snappedAnchor(at, t);
    if (widget.drawings.activeTool == DrawingTool.text) {
      final text = await _promptTextDialog(context);
      if (text != null && text.isNotEmpty) {
        await widget.drawings.addAnchor(anchor, text: text);
        Haptics.light();
      } else {
        widget.drawings.cancelPending();
      }
    } else {
      await widget.drawings.addAnchor(anchor);
      Haptics.light();
    }
  }

  Future<String?> _promptTextDialog(
    BuildContext context, {
    String? initialText,
  }) async {
    final colors = AppColors.of(context);
    final controller = TextEditingController(text: initialText ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(
          initialText != null ? 'Edit Text' : 'Add Text',
          style: TextStyle(color: colors.foreground, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colors.foreground),
          decoration: InputDecoration(
            hintText: 'Enter chart note text...',
            hintStyle: TextStyle(color: colors.mutedForeground),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text('Save', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }

  void _initCrosshairCenter(ChartTransform t, ChartLayout layout) {
    if (t.isEmpty || !layout.isUsable) return;
    Haptics.medium();
    final centerX = layout.plotWidth / 2;
    final centerY = layout.priceHeight / 2;
    final index = t.nearestIndexForX(centerX);
    setState(() {
      _crosshairPixelX = centerX;
      _crosshairY = centerY;
      _crosshairIndex = index;
    });
    _lastHapticCandleIndex = index;
    widget.onCrosshairIndex?.call(index);
  }

  void _moveCrosshairRelative(
    Offset delta,
    ChartTransform t,
    ChartLayout layout,
  ) {
    if (t.isEmpty || !layout.isUsable) return;

    if (_crosshairIndex == null ||
        _crosshairPixelX == null ||
        _crosshairY == null) {
      _initCrosshairCenter(t, layout);
      return;
    }

    final newX = (_crosshairPixelX! + delta.dx).clamp(0.0, layout.plotWidth);
    final newY = (_crosshairY! + delta.dy).clamp(0.0, layout.priceHeight);
    final index = t.nearestIndexForX(newX);

    final mode = context.read<AppState>().profile.crosshairMode;

    double finalX = newX;
    double finalY = newY;

    if (index >= 0 && index < widget.controller.candles.length) {
      final candle = widget.controller.candles[index];

      if (mode == CrosshairMode.locked) {
        finalX = t.xForIndex(index);
        finalY = t.yForPrice(candle.close);
      } else if (mode == CrosshairMode.magnet) {
        final oY = t.yForPrice(candle.open);
        final hY = t.yForPrice(candle.high);
        final lY = t.yForPrice(candle.low);
        final cY = t.yForPrice(candle.close);
        final ohlc = [oY, hY, lY, cY];
        ohlc.sort((a, b) => (a - newY).abs().compareTo((b - newY).abs()));
        finalY = ohlc.first;
      }
    }

    if (index != _lastHapticCandleIndex) {
      _lastHapticCandleIndex = index;
      Haptics.selection();
    }

    setState(() {
      _crosshairPixelX = finalX;
      _crosshairY = finalY;
      _crosshairIndex = index;
    });

    widget.onCrosshairIndex?.call(index);
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final controller = widget.controller;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _size = size;
        final layout = _layout(size);
        final t = _transform(layout);

        if (controller.isLoading && !controller.hasData) {
          return Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
          );
        }

        final error = controller.error;
        if (error != null && !controller.hasData) {
          return _ErrorState(message: error, onRetry: controller.refresh);
        }

        return AnimatedBuilder(
          animation: widget.drawings,
          builder: (context, _) {
            return Listener(
              onPointerSignal: (signal) {
                if (context.read<AppState>().profile.chartLocked) return;
                if (signal is PointerScrollEvent) {
                  final layout = _layout(_size);
                  final t = _transform(layout);

                  if (signal.scrollDelta.dy != 0) {
                    final zoomFactor = signal.scrollDelta.dy < 0 ? 1.12 : 0.88;
                    final focalX = signal.localPosition.dx;
                    final anchorIndex = t.indexForX(focalX);
                    final nextWidth = (_candleWidth * zoomFactor).clamp(
                      kMinCandleWidth,
                      kMaxCandleWidth,
                    );
                    final newestIndex = widget.controller.candles.length - 1;

                    setState(() {
                      _candleWidth = nextWidth;
                      final rightAnchor =
                          layout.plotWidth - t.rightOffsetPx - nextWidth / 2;
                      final fromNewest = newestIndex - anchorIndex;
                      _scrollOffset =
                          focalX - rightAnchor + fromNewest * nextWidth;
                      _clampScroll(
                        t.copyWith(
                          candleWidth: nextWidth,
                          scrollOffset: _scrollOffset,
                        ),
                      );
                    });
                  } else if (signal.scrollDelta.dx != 0) {
                    setState(() {
                      _scrollOffset -= signal.scrollDelta.dx;
                      _clampScroll(t);
                    });
                  }
                }
              },
              onPointerHover: (e) {
                if (widget.drawings.isDrawing &&
                    widget.drawings.pending != null) {
                  widget.drawings.updatePendingLastAnchor(
                    _snappedAnchor(e.localPosition, t),
                  );
                }
              },
              onPointerMove: (e) {
                if (widget.drawings.isDrawing &&
                    widget.drawings.pending != null) {
                  widget.drawings.updatePendingLastAnchor(
                    _snappedAnchor(e.localPosition, t),
                  );
                } else if (!widget.drawings.isDrawing &&
                    _crosshairIndex != null) {
                  _moveCrosshairRelative(e.delta, t, layout);
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                onTapUp: _onTapUp,
                onDoubleTapDown: (d) {
                  if (d.localPosition.dx >= layout.plotWidth) {
                    setState(() {
                      _priceScaleRatio = 1.0;
                      _pricePanOffset = 0.0;
                    });
                    Haptics.light();
                  }
                },
                onLongPressStart: (d) {
                  if (widget.drawings.isDrawing) return;
                  _lastLongPressOffset = d.globalPosition;
                  _initCrosshairCenter(t, layout);
                },
                onLongPressMoveUpdate: (d) {
                  if (widget.drawings.isDrawing) return;
                  final prev = _lastLongPressOffset ?? d.globalPosition;
                  final delta = d.globalPosition - prev;
                  _lastLongPressOffset = d.globalPosition;
                  _moveCrosshairRelative(delta, t, layout);
                },
                onLongPressEnd: (_) {
                  setState(() {
                    _crosshairIndex = null;
                    _crosshairY = null;
                    _crosshairPixelX = null;
                    _lastLongPressOffset = null;
                  });
                  _lastHapticCandleIndex = null;
                  widget.onCrosshairIndex?.call(null);
                },
                child: Stack(
                  children: [
                    // Snapshot boundary wraps both paint layers so a parent can
                    // capture exactly the chart + drawings (not the loading
                    // chip / OHLC readout below, which are transient UI). The
                    // two inner RepaintBoundaries are kept as-is so editing a
                    // drawing still only re-rasterizes the drawing layer, not
                    // the candles — this outer one only affects capture, not
                    // repaint scheduling, since it sits above both.
                    RepaintBoundary(
                      key: widget.snapshotKey,
                      child: Container(
                        color: colors.background,
                        child: Stack(
                          children: [
                            // Candle layer
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: ChartPainter(
                                    ChartPaintParams(
                                      transform: t,
                                      layout: layout,
                                      indicators: controller.indicators,
                                      enabledIndicators:
                                          controller.enabledIndicators,
                                      style: _getChartStyle(
                                        context
                                            .watch<AppState>()
                                            .profile
                                            .chartType,
                                      ),
                                      gridVisibility: context
                                          .watch<AppState>()
                                          .profile
                                          .gridVisibility,
                                      gridStyle: context
                                          .watch<AppState>()
                                          .profile
                                          .gridStyle,
                                      gridDensity: context
                                          .watch<AppState>()
                                          .profile
                                          .gridDensity,
                                      bullishColor: Color(
                                        context
                                            .watch<AppState>()
                                            .profile
                                            .customBullishColorValue,
                                      ),
                                      bearishColor: Color(
                                        context
                                            .watch<AppState>()
                                            .profile
                                            .customBearishColorValue,
                                      ),
                                      colors: colors,
                                      instrument: controller.instrument,
                                      timeframe: controller.timeframe,
                                      crosshairIndex: _crosshairIndex,
                                      crosshairY: _crosshairY,
                                      showCrosshairLabels: context
                                          .watch<AppState>()
                                          .profile
                                          .crosshairShowLabels,
                                      customPriceLines: context
                                          .watch<AppState>()
                                          .profile
                                          .customPriceLines,
                                      sessionRects: _sessionConfig.masterEnabled
                                          ? _sessionConfig.compute(
                                              candles: controller.candles,
                                              firstVisibleIndex:
                                                  t.firstVisibleIndex,
                                              lastVisibleIndex:
                                                  t.lastVisibleIndex,
                                            )
                                          : const [],
                                    ),
                                  ),
                                  size: size,
                                ),
                              ),
                            ),

                            // Drawing layer
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: DrawingPainter(
                                    transform: t,
                                    layout: layout,
                                    drawings: widget.drawings.drawings,
                                    pending: widget.drawings.pending,
                                    selectedId: widget.drawings.selectedId,
                                    colors: colors,
                                    snapIndicator: _snapPoint,
                                    formatPrice:
                                        controller.instrument.formatPrice,
                                    instrument: controller.instrument,
                                  ),
                                  size: size,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (controller.isLoadingHistory)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _Chip(label: 'Loading history', colors: colors),
                      ),

                    if (_crosshairIndex != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _OhlcReadout(
                          candle:
                              controller.candles[_crosshairIndex!.clamp(
                                0,
                                controller.candles.length - 1,
                              )],
                          instrument: controller.instrument,
                          colors: colors,
                          onTap: () {
                            final idx = _crosshairIndex;
                            if (idx != null &&
                                idx >= 0 &&
                                idx < controller.candles.length) {
                              _showCandleSheet(idx);
                            }
                          },
                        ),
                      ),
                    // Floating measurement card.
                    if (_shouldShowMeasurementCard())
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: _buildMeasurementCard(controller),
                      ),

                    // Floating top toolbar for drawn tool customization.
                    if (widget.drawings.selected != null)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _buildTopDrawingCustomizationBar(
                          widget.drawings,
                          colors,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // MEASUREMENT & DRAWING CUSTOMIZATION CARDS
  // ==========================================================

  Widget _buildTopDrawingCustomizationBar(
    DrawingController drawings,
    ThemePalette colors,
  ) {
    final sel = drawings.selected;
    if (sel == null) return const SizedBox.shrink();

    final currentColor = drawings.colorValue > 0
        ? drawings.colorValue
        : sel.colorValue;
    final currentWidth = drawings.strokeWidth;

    const presetColors = [
      0xFFF59E0B, // Amber Gold
      0xFF38BDF8, // Sky Blue
      0xFF10B981, // Emerald Green
      0xFFEF4444, // Rose Red
      0xFFA855F7, // Purple
      0xFFFFFFFF, // White
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sel.tool.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          Container(
            height: 14,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: colors.border.withValues(alpha: 0.6),
          ),
          for (final cValue in presetColors.take(5)) ...[
            InkWell(
              onTap: () {
                Haptics.selection();
                drawings.setColor(cValue);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(cValue),
                  border: Border.all(
                    color: currentColor == cValue
                        ? colors.foreground
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
          ],
          Container(
            height: 14,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: colors.border.withValues(alpha: 0.6),
          ),
          InkWell(
            onTap: () {
              Haptics.selection();
              final nextWidth = currentWidth == 1.0
                  ? 2.0
                  : (currentWidth == 2.0 ? 3.5 : 1.0);
              drawings.setStrokeWidth(nextWidth);
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: colors.border.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${currentWidth.toStringAsFixed(1)}px',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
            ),
          ),
          Container(
            height: 14,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: colors.border.withValues(alpha: 0.6),
          ),
          InkWell(
            onTap: () {
              Haptics.medium();
              drawings.deleteSelected();
            },
            borderRadius: BorderRadius.circular(6),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: colors.destructive,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () {
              Haptics.selection();
              drawings.select(null);
            },
            borderRadius: BorderRadius.circular(6),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: colors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowMeasurementCard() {
    final sel = widget.drawings.selected;
    if (sel != null &&
        sel.tool == DrawingTool.measurement &&
        sel.anchors.length >= 2) {
      return true;
    }
    final pending = widget.drawings.pending;
    if (pending != null &&
        pending.tool == DrawingTool.measurement &&
        pending.anchors.length >= 2) {
      return true;
    }
    return false;
  }

  Widget _buildMeasurementCard(ChartDataSource controller) {
    final Drawing d;
    final sel = widget.drawings.selected;
    final pending = widget.drawings.pending;
    if (pending != null &&
        pending.tool == DrawingTool.measurement &&
        pending.anchors.length >= 2) {
      d = pending;
    } else if (sel != null &&
        sel.tool == DrawingTool.measurement &&
        sel.anchors.length >= 2) {
      d = sel;
    } else {
      return const SizedBox.shrink();
    }

    final stats = MeasurementCalculator.compute(
      startTimestamp: d.anchors[0].timestamp,
      endTimestamp: d.anchors[1].timestamp,
      startPrice: d.anchors[0].price,
      endPrice: d.anchors[1].price,
      candles: controller.candles,
    );

    return FloatingMeasurementCard(
      stats: stats,
      formatPrice: controller.instrument.formatPrice,
    );
  }

  // ==========================================================
  // SMART CANDLE SHEET
  // ==========================================================

  void _showCandleSheet(int index) {
    final candles = widget.controller.candles;
    if (index < 0 || index >= candles.length) return;

    final analytics = CandleAnalytics.compute(candles, index);
    final story = CandleStoryGenerator.generate(analytics, candles, index);
    Haptics.medium();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, scrollController) => SmartCandleSheet(
          analytics: analytics,
          story: story,
          formatPrice: widget.controller.instrument.formatPrice,
        ),
      ),
    );
  }

  /// Expose session config for the toolbar to toggle.
  SessionOverlayConfig get sessionConfig => _sessionConfig;

  /// Toggle session overlay master switch.
  void toggleSessions() {
    setState(() {
      _sessionConfig.masterEnabled = !_sessionConfig.masterEnabled;
    });
    context.read<AppState>().setSessionConfig(_sessionConfig);
  }

  ChartStyle _getChartStyle(ChartTypePref pref) {
    switch (pref) {
      case ChartTypePref.candles:
        return ChartStyle.candles;
      case ChartTypePref.line:
        return ChartStyle.line;
      case ChartTypePref.baseline:
        return ChartStyle.baseline;
      case ChartTypePref.area:
        return ChartStyle.area;
      case ChartTypePref.volumeCandles:
        return ChartStyle.volumeCandles;
    }
  }
}

// ============================================================
// SMALL UI PIECES
// ============================================================

class _OhlcReadout extends StatelessWidget {
  final CandleData candle;
  final Instrument instrument;
  final ThemePalette colors;
  final VoidCallback? onTap;

  const _OhlcReadout({
    required this.candle,
    required this.instrument,
    required this.colors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor = candle.isBullish ? colors.positive : colors.negative;

    Widget cell(String label, double value) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                color: colors.mutedForeground,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: instrument.formatPrice(value),
              style: TextStyle(
                color: valueColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            cell('O', candle.open),
            cell('H', candle.high),
            cell('L', candle.low),
            cell('C', candle.close),
            const SizedBox(width: 4),
            Icon(Icons.analytics_outlined, size: 13, color: colors.primary),
            const SizedBox(width: 2),
            Text(
              'Stats',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final ThemePalette colors;

  const _Chip({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.mutedForeground,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart_rounded,
              color: colors.mutedForeground,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.mutedForeground, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
