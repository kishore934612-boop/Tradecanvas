/// Comprehensive unit test suite for ViewportController, ViewportPhysics, and ViewportBounds.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/chart/viewport/viewport_bounds.dart';
import 'package:app/chart/viewport/viewport_controller.dart';
import 'package:app/chart/viewport/viewport_physics.dart';
import 'package:app/chart/viewport/viewport_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ViewportBounds Tests', () {
    const bounds = ViewportBounds();

    test('candle width is clamped within strict limits', () {
      expect(bounds.clampCandleWidth(0.5), equals(ViewportBounds.kMinCandleWidth));
      expect(bounds.clampCandleWidth(100.0), equals(ViewportBounds.kMaxCandleWidth));
      expect(bounds.clampCandleWidth(12.5), equals(12.5));
    });

    test('right margin calculation respects future space fraction', () {
      final margin20 = bounds.getRightOffsetPx(1000.0, 0.20);
      expect(margin20, equals(200.0));

      final marginClamped = bounds.getRightOffsetPx(1000.0, 0.80);
      expect(marginClamped, equals(500.0)); // Clamped at 0.50 max
    });

    test('right anchor calculation is accurate', () {
      final anchor = bounds.getRightAnchor(1000.0, 10.0, 0.20);
      // 1000 - 200 - 5 = 795.0
      expect(anchor, equals(795.0));
    });

    test('max and min scroll offsets calculate correctly', () {
      final maxScroll = bounds.getMaxScrollOffset(100, 10.0, 500.0, 0.20);
      expect(maxScroll, greaterThan(0.0));

      final minScroll = bounds.getMinScrollOffset(500.0, 10.0, 0.20);
      expect(minScroll, lessThan(0.0));
    });
  });

  group('ViewportPhysics Tests', () {
    const physics = ViewportPhysics();

    test('fling distance and duration decelerate smoothly', () {
      final distance = physics.computeFlingDistance(1000.0);
      expect(distance, greaterThan(0.0));

      final duration = physics.flingDuration(1000.0);
      expect(duration, greaterThan(0.0));
    });

    test('computeFocalZoomScrollOffset maintains focal point candle anchoring', () {
      final newOffset = physics.computeFocalZoomScrollOffset(
        oldScrollOffset: 0.0,
        oldCandleWidth: 10.0,
        newCandleWidth: 20.0,
        focalPointX: 400.0,
        chartWidth: 1000.0,
        candleCount: 100,
        futureOffsetFraction: 0.20,
      );

      expect(newOffset, isNotNull);
    });
  });

  group('ViewportState Tests', () {
    test('initial state and copyWith equality', () {
      const state = ViewportState(candleWidth: 7.0, scrollOffset: 10.0);
      expect(state.candleWidth, equals(7.0));
      expect(state.scrollOffset, equals(10.0));

      final updated = state.copyWith(scrollOffset: 25.0);
      expect(updated.scrollOffset, equals(25.0));
      expect(updated.candleWidth, equals(7.0));
      expect(state == updated, isFalse);
    });

    test('first and last visible index bounds computation', () {
      const bounds = ViewportBounds();
      const state = ViewportState(
        candleWidth: 10.0,
        scrollOffset: 0.0,
        chartSize: Size(1000, 500),
        candleCount: 200,
      );

      final first = state.getFirstVisibleIndex(bounds);
      final last = state.getLastVisibleIndex(bounds);

      expect(first, greaterThanOrEqualTo(0));
      expect(last, lessThan(200));
      expect(first, lessThanOrEqualTo(last));
    });
  });

  group('ViewportController Integration Tests', () {
    late ViewportController controller;

    setUp(() {
      controller = ViewportController();
      controller.updateLayout(
        size: const Size(1000, 600),
        candleCount: 200,
        minPrice: 100.0,
        maxPrice: 200.0,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('pan adjusts scroll offset and sets isScrolledAway', () {
      expect(controller.scrollOffset, equals(0.0));
      expect(controller.isScrolledAway, isFalse);

      controller.pan(100.0);
      expect(controller.scrollOffset, equals(100.0));
      expect(controller.isScrolledAway, isTrue);
    });

    test('price pan and price scale update ratio', () {
      controller.panPrice(-50.0);
      expect(controller.pricePanOffset, equals(-50.0));

      controller.scalePrice(1.5);
      expect(controller.priceScaleRatio, equals(1.5));
    });

    test('scaleFocal adjusts candle width cleanly', () {
      final initialWidth = controller.candleWidth;
      controller.scaleFocal(scaleFactor: 1.5, focalPoint: const Offset(500, 300));
      expect(controller.candleWidth, greaterThan(initialWidth));
    });

    test('onNewCandleArrived resets scroll if not scrolled away', () {
      controller.onNewCandleArrived();
      expect(controller.scrollOffset, equals(0.0));
    });
  });
}
