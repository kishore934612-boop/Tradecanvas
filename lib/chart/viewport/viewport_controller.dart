/// Central Viewport Controller — owns navigation, gesture arbitration, momentum fling, and auto-follow.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app/chart/viewport/viewport_animation.dart';
import 'package:app/chart/viewport/viewport_bounds.dart';
import 'package:app/chart/viewport/viewport_physics.dart';
import 'package:app/chart/viewport/viewport_state.dart';

class ViewportController extends ChangeNotifier {
  final ViewportBounds bounds;
  final ViewportPhysics physics;

  ViewportState _state;
  AnimationController? _animController;
  AnimationController? _flingController;

  /// Scrolled away threshold in pixels from live edge.
  static const double kScrolledAwayThresholdPx = 15.0;

  ViewportController({
    this.bounds = const ViewportBounds(),
    this.physics = const ViewportPhysics(),
    ViewportState initialState = const ViewportState(),
  }) : _state = initialState;

  ViewportState get state => _state;
  double get candleWidth => _state.candleWidth;
  double get scrollOffset => _state.scrollOffset;
  double get priceScaleRatio => _state.priceScaleRatio;
  double get pricePanOffset => _state.pricePanOffset;
  double get rightOffsetFraction => _state.rightOffsetFraction;
  bool get isScrolledAway => _state.isScrolledAway;
  bool get isAnimating => _state.isAnimating;

  @override
  void dispose() {
    _animController?.dispose();
    _flingController?.dispose();
    super.dispose();
  }

  // ==========================================================
  // LAYOUT & DATA UPDATES
  // ==========================================================

  void updateLayout({
    required Size size,
    required int candleCount,
    required double minPrice,
    required double maxPrice,
  }) {
    if (size == _state.chartSize &&
        candleCount == _state.candleCount &&
        minPrice == _state.minPrice &&
        maxPrice == _state.maxPrice) {
      return;
    }

    _state = _state.copyWith(
      chartSize: size,
      candleCount: candleCount,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
    notifyListeners();
  }

  void setFutureOffsetFraction(double fraction) {
    final clamped = fraction.clamp(0.0, 0.50);
    if (_state.rightOffsetFraction == clamped) return;
    _state = _state.copyWith(rightOffsetFraction: clamped);
    notifyListeners();
  }

  // ==========================================================
  // PAN GESTURES & MOMENTUM
  // ==========================================================

  void pan(double deltaX) {
    _stopAnimations();
    final newOffset = _state.scrollOffset + deltaX;

    final minScroll = bounds.getMinScrollOffset(_state.chartSize.width, _state.candleWidth, _state.rightOffsetFraction);
    final maxScroll = bounds.getMaxScrollOffset(_state.candleCount, _state.candleWidth, _state.chartSize.width, _state.rightOffsetFraction);

    final elasticOffset = bounds.applyScrollElasticity(
      scrollOffset: newOffset,
      minScroll: minScroll,
      maxScroll: maxScroll,
    );

    _updateScrollOffset(elasticOffset);
  }

  void panPrice(double deltaY) {
    _stopAnimations();
    final newPan = _state.pricePanOffset + deltaY;
    _state = _state.copyWith(pricePanOffset: newPan);
    notifyListeners();
  }

  void scalePrice(double scaleDelta) {
    _stopAnimations();
    final newScale = (_state.priceScaleRatio * scaleDelta).clamp(0.2, 5.0);
    _state = _state.copyWith(priceScaleRatio: newScale);
    notifyListeners();
  }

  void startFling(double velocityX, TickerProvider vsync) {
    _stopAnimations();
    final clampedV = physics.clampVelocity(velocityX);
    if (clampedV.abs() < ViewportPhysics.kStopVelocityThreshold) {
      _snapToBounds();
      return;
    }

    final distance = physics.computeFlingDistance(clampedV);
    final durationSec = physics.flingDuration(clampedV);

    final startOffset = _state.scrollOffset;
    final targetOffset = startOffset + distance;

    final minScroll = bounds.getMinScrollOffset(_state.chartSize.width, _state.candleWidth, _state.rightOffsetFraction);
    final maxScroll = bounds.getMaxScrollOffset(_state.candleCount, _state.candleWidth, _state.chartSize.width, _state.rightOffsetFraction);

    final clampedTarget = bounds.clampScrollOffset(
      scrollOffset: targetOffset,
      minScroll: minScroll,
      maxScroll: maxScroll,
    );

    final durationMs = (durationSec * 1000).clamp(180, 800).toInt();

    _flingController = AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: durationMs),
    );

    final animation = Tween<double>(begin: startOffset, end: clampedTarget).animate(
      CurvedAnimation(parent: _flingController!, curve: Curves.decelerate),
    );

    _flingController!.addListener(() {
      _updateScrollOffset(animation.value);
    });

    _flingController!.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _snapToBounds();
      }
    });

    _flingController!.forward(from: 0.0);
  }

  // ==========================================================
  // PINCH ZOOM & FOCAL POINT
  // ==========================================================

  void scaleFocal({
    required double scaleFactor,
    required Offset focalPoint,
  }) {
    _stopAnimations();
    if (scaleFactor <= 0 || _state.chartSize.width <= 0) return;

    final newCandleWidth = bounds.clampCandleWidth(_state.candleWidth * scaleFactor);
    if (newCandleWidth == _state.candleWidth) return;

    final newScrollOffset = physics.computeFocalZoomScrollOffset(
      oldScrollOffset: _state.scrollOffset,
      oldCandleWidth: _state.candleWidth,
      newCandleWidth: newCandleWidth,
      focalPointX: focalPoint.dx,
      chartWidth: _state.chartSize.width,
      candleCount: _state.candleCount,
      futureOffsetFraction: _state.rightOffsetFraction,
    );

    final minScroll = bounds.getMinScrollOffset(_state.chartSize.width, newCandleWidth, _state.rightOffsetFraction);
    final maxScroll = bounds.getMaxScrollOffset(_state.candleCount, newCandleWidth, _state.chartSize.width, _state.rightOffsetFraction);

    final clampedScroll = bounds.clampScrollOffset(
      scrollOffset: newScrollOffset,
      minScroll: minScroll,
      maxScroll: maxScroll,
    );

    _state = _state.copyWith(
      candleWidth: newCandleWidth,
      scrollOffset: clampedScroll,
    );
    _checkScrolledAway();
    notifyListeners();
  }

  // ==========================================================
  // DOUBLE-TAP ZOOM & RETURN TO LIVE
  // ==========================================================

  void doubleTapZoom(Offset tapPosition, TickerProvider vsync) {
    _stopAnimations();

    final isZoomedIn = _state.candleWidth > ViewportBounds.kDefaultCandleWidth * 1.5;
    final targetWidth = isZoomedIn
        ? ViewportBounds.kDefaultCandleWidth
        : (ViewportBounds.kDefaultCandleWidth * 2.2).clamp(bounds.minCandleWidth, bounds.maxCandleWidth);

    final targetScrollOffset = physics.computeFocalZoomScrollOffset(
      oldScrollOffset: _state.scrollOffset,
      oldCandleWidth: _state.candleWidth,
      newCandleWidth: targetWidth,
      focalPointX: tapPosition.dx,
      chartWidth: _state.chartSize.width,
      candleCount: _state.candleCount,
      futureOffsetFraction: _state.rightOffsetFraction,
    );

    final minScroll = bounds.getMinScrollOffset(_state.chartSize.width, targetWidth, _state.rightOffsetFraction);
    final maxScroll = bounds.getMaxScrollOffset(_state.candleCount, targetWidth, _state.chartSize.width, _state.rightOffsetFraction);

    final clampedScroll = bounds.clampScrollOffset(
      scrollOffset: targetScrollOffset,
      minScroll: minScroll,
      maxScroll: maxScroll,
    );

    _animateTo(
      target: ViewportAnimationTarget(
        candleWidth: targetWidth,
        scrollOffset: clampedScroll,
        priceScaleRatio: 1.0,
        pricePanOffset: 0.0,
      ),
      vsync: vsync,
    );
  }

  void goToLive(TickerProvider vsync) {
    _stopAnimations();
    _animateTo(
      target: ViewportAnimationTarget(
        candleWidth: _state.candleWidth,
        scrollOffset: 0.0,
        priceScaleRatio: 1.0,
        pricePanOffset: 0.0,
      ),
      vsync: vsync,
    );
  }

  void resetViewport(TickerProvider vsync) {
    _stopAnimations();
    _animateTo(
      target: const ViewportAnimationTarget(
        candleWidth: ViewportBounds.kDefaultCandleWidth,
        scrollOffset: 0.0,
        priceScaleRatio: 1.0,
        pricePanOffset: 0.0,
      ),
      vsync: vsync,
    );
  }

  // ==========================================================
  // MOUSE & TRACKPAD SCROLL SUPPORT
  // ==========================================================

  void handlePointerScroll(PointerScrollEvent event, Offset localPosition) {
    _stopAnimations();

    // Ctrl + Scroll Wheel or Pinch gesture on trackpad -> Zoom
    if (HardwareKeyboard.instance.isControlPressed) {
      final zoomFactor = event.scrollDelta.dy < 0 ? 1.10 : 0.90;
      scaleFocal(scaleFactor: zoomFactor, focalPoint: localPosition);
      return;
    }

    // Shift + Scroll Wheel -> Horizontal Pan
    if (HardwareKeyboard.instance.isShiftPressed) {
      pan(-event.scrollDelta.dy);
      return;
    }

    // Normal Scroll Wheel / Trackpad Pan
    if (event.scrollDelta.dx != 0) {
      pan(-event.scrollDelta.dx);
    }
    if (event.scrollDelta.dy != 0) {
      pan(-event.scrollDelta.dy);
    }
  }

  // ==========================================================
  // LIVE DATA AUTO-SCROLL
  // ==========================================================

  void onNewCandleArrived() {
    if (!_state.isScrolledAway) {
      _updateScrollOffset(0.0);
    }
  }

  // ==========================================================
  // PRIVATE HELPERS
  // ==========================================================

  void _updateScrollOffset(double offset) {
    _state = _state.copyWith(scrollOffset: offset);
    _checkScrolledAway();
    notifyListeners();
  }

  void _checkScrolledAway() {
    final away = _state.scrollOffset.abs() > kScrolledAwayThresholdPx;
    if (away != _state.isScrolledAway) {
      _state = _state.copyWith(isScrolledAway: away);
    }
  }

  void _snapToBounds() {
    final minScroll = bounds.getMinScrollOffset(_state.chartSize.width, _state.candleWidth, _state.rightOffsetFraction);
    final maxScroll = bounds.getMaxScrollOffset(_state.candleCount, _state.candleWidth, _state.chartSize.width, _state.rightOffsetFraction);
    final clamped = bounds.clampScrollOffset(
      scrollOffset: _state.scrollOffset,
      minScroll: minScroll,
      maxScroll: maxScroll,
    );
    if (clamped != _state.scrollOffset) {
      _updateScrollOffset(clamped);
    }
  }

  void _stopAnimations() {
    _animController?.stop();
    _flingController?.stop();
    if (_state.isAnimating) {
      _state = _state.copyWith(isAnimating: false);
    }
  }

  void _animateTo({
    required ViewportAnimationTarget target,
    required TickerProvider vsync,
    Duration duration = ViewportAnimation.kDefaultDuration,
    Curve curve = ViewportAnimation.kDefaultCurve,
  }) {
    _stopAnimations();

    final startTarget = ViewportAnimationTarget(
      candleWidth: _state.candleWidth,
      scrollOffset: _state.scrollOffset,
      priceScaleRatio: _state.priceScaleRatio,
      pricePanOffset: _state.pricePanOffset,
    );

    _animController = AnimationController(vsync: vsync, duration: duration);
    _state = _state.copyWith(isAnimating: true);

    final animation = CurvedAnimation(parent: _animController!, curve: curve);
    animation.addListener(() {
      final current = ViewportAnimation.interpolate(
        start: startTarget,
        target: target,
        t: animation.value,
      );
      _state = _state.copyWith(
        candleWidth: current.candleWidth,
        scrollOffset: current.scrollOffset,
        priceScaleRatio: current.priceScaleRatio,
        pricePanOffset: current.pricePanOffset,
      );
      _checkScrolledAway();
      notifyListeners();
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _state = _state.copyWith(isAnimating: false);
        _snapToBounds();
        notifyListeners();
      }
    });

    _animController!.forward(from: 0.0);
  }
}
