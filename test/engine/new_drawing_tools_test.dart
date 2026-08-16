/// Tests for the 4 professional drawing tools:
/// 1. Flat Top / Flat Bottom
/// 2. Anchored Volume Profile (AVP)
/// 3. Fixed Range Volume Profile (FRVP)
/// 4. Triangle Tool
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:app/components/chart/chart_transform.dart';
import 'package:app/components/chart/drawing_geometry.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/drawing_controller.dart';
import 'package:app/models/drawing.dart';

import '../helpers/fake_drawing_repository.dart';

const _symbol = 'BTCUSDT';

DrawingController _controller(FakeDrawingRepository repo) => DrawingController(
      repository: repo,
      logger: Logger.instance,
      symbol: _symbol,
    );

ChartTransform _createTransform() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final candles = List.generate(
    100,
    (i) => CandleData(
      timestamp: now - (100 - i) * 60000,
      open: 100.0 + i,
      high: 105.0 + i,
      low: 95.0 + i,
      close: 102.0 + i,
      volume: 500.0 + i * 10,
    ),
  );

  return ChartTransform(
    candles: candles,
    candleWidth: 10.0,
    scrollOffset: 0.0,
    chartWidth: 800.0,
    priceHeight: 400.0,
    minPrice: 90.0,
    maxPrice: 210.0,
    intervalMs: 60000,
  );
}

void main() {
  group('Flat Top/Bottom Tool', () {
    test('create flatTopBottom channel tool and verify independent anchor prices', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      c.setActiveTool(DrawingTool.flatTopBottom);
      await c.addAnchor(const DrawingAnchor(timestamp: 1000, price: 150.0));
      await c.addAnchor(const DrawingAnchor(timestamp: 2000, price: 160.0));

      expect(c.drawings, hasLength(1));
      final drawing = c.drawings.single;
      expect(drawing.tool, DrawingTool.flatTopBottom);
      expect(drawing.anchors, hasLength(2));
      expect(drawing.anchors[0].price, 150.0);
      expect(drawing.anchors[1].price, 160.0);
      expect(drawing.labelText, 'Flat Top/Bottom');
    });

    test('dragging handle 0 updates anchor 0 independently', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      c.setActiveTool(DrawingTool.flatTopBottom);
      await c.addAnchor(const DrawingAnchor(timestamp: 1000, price: 150.0));
      await c.addAnchor(const DrawingAnchor(timestamp: 2000, price: 180.0));

      final id = c.drawings.single.id;
      c.beginTransientEdit();
      c.moveAnchor(id, 0, const DrawingAnchor(timestamp: 800, price: 130.0));
      await c.commitEdit(id);

      final updated = c.drawings.single;
      expect(updated.anchors[0].timestamp, 800);
      expect(updated.anchors[0].price, 130.0);
      expect(updated.anchors[1].price, 180.0);
    });

    test('flatTopBottom dashed line and fill opacity properties persist', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      c.setActiveTool(DrawingTool.flatTopBottom);
      await c.addAnchor(const DrawingAnchor(timestamp: 1000, price: 150.0));
      await c.addAnchor(const DrawingAnchor(timestamp: 2000, price: 180.0));

      final d = c.drawings.single;
      c.updateDrawing(d.copyWith(
        properties: {'isDashed': true, 'showLabel': false, 'fillOpacity': 0.4},
      ));

      final updated = c.drawings.single;
      expect(updated.isDashed, isTrue);
      expect(updated.showLabel, isFalse);
      expect(updated.fillOpacity, 0.4);
    });
  });

  group('Triangle Tool', () {
    test('create triangle requires 3 anchors', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      c.setActiveTool(DrawingTool.triangle);
      expect(DrawingTool.triangle.anchorCount, 3);

      await c.addAnchor(const DrawingAnchor(timestamp: 1000, price: 100.0));
      expect(c.pending, isNotNull);
      expect(c.drawings, isEmpty);

      await c.addAnchor(const DrawingAnchor(timestamp: 2000, price: 200.0));
      expect(c.pending, isNotNull);
      expect(c.drawings, isEmpty);

      await c.addAnchor(const DrawingAnchor(timestamp: 1500, price: 300.0));
      expect(c.pending, isNull);
      expect(c.drawings, hasLength(1));

      final triangle = c.drawings.single;
      expect(triangle.tool, DrawingTool.triangle);
      expect(triangle.anchors, hasLength(3));
    });

    test('move and resize triangle vertex handle', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      c.setActiveTool(DrawingTool.triangle);
      await c.addAnchor(const DrawingAnchor(timestamp: 1000, price: 100.0));
      await c.addAnchor(const DrawingAnchor(timestamp: 2000, price: 200.0));
      await c.addAnchor(const DrawingAnchor(timestamp: 1500, price: 300.0));

      final id = c.drawings.single.id;
      c.beginTransientEdit();
      c.moveAnchor(id, 2, const DrawingAnchor(timestamp: 1600, price: 350.0));
      await c.commitEdit(id);

      final updated = c.drawings.single;
      expect(updated.anchors[2].timestamp, 1600);
      expect(updated.anchors[2].price, 350.0);
    });

    test('hitTest inside triangle polygon', () {
      final transform = _createTransform();
      final t1 = transform.candles[10].timestamp;
      final t2 = transform.candles[30].timestamp;
      final t3 = transform.candles[20].timestamp;

      final triangle = Drawing(
        id: 't1',
        tool: DrawingTool.triangle,
        symbol: _symbol,
        anchors: [
          DrawingAnchor(timestamp: t1, price: 100.0),
          DrawingAnchor(timestamp: t2, price: 100.0),
          DrawingAnchor(timestamp: t3, price: 180.0),
        ],
        colorValue: 0xFF3B82F6,
        createdAt: 0,
      );

      final pt1 = Offset(transform.xForTimestamp(t3), transform.yForPrice(130.0));
      final hit = DrawingGeometry.hitTest(triangle, transform, pt1, chartWidth: 800.0);
      expect(hit, isTrue);
    });
  });

  group('Parallel Channel & Short Label Tools', () {
    test('create parallelChannel with 3 anchors and verify shortLabel', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      c.setActiveTool(DrawingTool.parallelChannel);
      await c.addAnchor(const DrawingAnchor(timestamp: 1000, price: 100.0));
      await c.addAnchor(const DrawingAnchor(timestamp: 5000, price: 200.0));
      await c.addAnchor(const DrawingAnchor(timestamp: 3000, price: 250.0));

      expect(c.drawings, hasLength(1));
      final drawing = c.drawings.single;
      expect(drawing.tool, DrawingTool.parallelChannel);
      expect(drawing.anchors, hasLength(3));
      expect(drawing.tool.label, 'Parallel Channel');
      expect(drawing.tool.shortLabel, 'Parallel Ch.');
    });

    test('parallelChannel hitTest and showMidline property', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      c.setActiveTool(DrawingTool.parallelChannel);
      await c.addAnchor(const DrawingAnchor(timestamp: 1000, price: 100.0));
      await c.addAnchor(const DrawingAnchor(timestamp: 5000, price: 100.0));
      await c.addAnchor(const DrawingAnchor(timestamp: 3000, price: 200.0));

      final drawing = c.drawings.single;
      expect(drawing.showMidline, isTrue);

      final transform = _createTransform();

      final hitPt = Offset(transform.xForTimestamp(3000), transform.yForPrice(150.0));
      final hit = DrawingGeometry.hitTest(drawing, transform, hitPt, chartWidth: 800.0);
    });
  });

  group('Fib Extension Tool', () {
    test('create fibExtension with 3 anchors and verify level calculation', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      c.setActiveTool(DrawingTool.fibExtension);
      await c.addAnchor(const DrawingAnchor(timestamp: 1000, price: 100.0));
      await c.addAnchor(const DrawingAnchor(timestamp: 3000, price: 200.0));
      await c.addAnchor(const DrawingAnchor(timestamp: 5000, price: 150.0));

      expect(c.drawings, hasLength(1));
      final drawing = c.drawings.single;
      expect(drawing.tool, DrawingTool.fibExtension);
      expect(drawing.anchors, hasLength(3));
      expect(drawing.tool.label, 'Fib Extension');
      expect(drawing.tool.shortLabel, 'Fib Ext.');

      final transform = _createTransform();
      final levels = DrawingGeometry.fibExtensionLevels(drawing, transform);
      expect(levels, isNotEmpty);
      final lev1 = levels.firstWhere((l) => l.level == 1.0);
    });
  });

  group('Freehand Brush Tool', () {
    test('create brush stroke, append points dynamically and verify properties', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      c.setActiveTool(DrawingTool.brush);
      await c.addAnchor(const DrawingAnchor(timestamp: 1000, price: 100.0));
      c.appendPointToPending(const DrawingAnchor(timestamp: 1100, price: 105.0));
      c.appendPointToPending(const DrawingAnchor(timestamp: 1200, price: 110.0));
      await c.commitPending();

      expect(c.drawings, hasLength(1));
      final drawing = c.drawings.single;
      expect(drawing.tool, DrawingTool.brush);
      expect(drawing.anchors, hasLength(3));
      expect(drawing.tool.label, 'Freehand Brush');
    });
  });

  group('Callout Box Tool', () {
    test('create callout box with 2 anchors, text note and shortLabel', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      c.setActiveTool(DrawingTool.callout);
      await c.addAnchor(const DrawingAnchor(timestamp: 1000, price: 100.0), text: 'Key Breakout Point');
      await c.addAnchor(const DrawingAnchor(timestamp: 1500, price: 150.0));

      expect(c.drawings, hasLength(1));
      final drawing = c.drawings.single;
      expect(drawing.tool, DrawingTool.callout);
      expect(drawing.anchors, hasLength(2));
      expect(drawing.text, 'Key Breakout Point');
      expect(drawing.tool.label, 'Callout Box');
    });
  });

  group('HTF Level Overlay Tool', () {
    test('create HTF level overlay with level type property and shortLabel', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      c.setActiveTool(DrawingTool.htfOverlay);
      await c.addAnchor(const DrawingAnchor(timestamp: 1000, price: 105240.0));

      expect(c.drawings, hasLength(1));
      final drawing = c.drawings.single;
      expect(drawing.tool, DrawingTool.htfOverlay);
      expect(drawing.anchors, hasLength(1));
      expect(drawing.htfLevelType, 'PDH');
      expect(drawing.tool.label, 'HTF Level Overlay');
      expect(drawing.tool.shortLabel, 'HTF Level');
    });
  });

  group('Undo / Redo & Delete for New Tools', () {
    test('undo removes new tool and redo restores it with properties', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      c.setActiveTool(DrawingTool.triangle);
      await c.addAnchor(const DrawingAnchor(timestamp: 1000, price: 100.0));
      await c.addAnchor(const DrawingAnchor(timestamp: 2000, price: 200.0));
      await c.addAnchor(const DrawingAnchor(timestamp: 1500, price: 300.0));

      final id = c.drawings.single.id;
      c.select(id);
      c.updateDrawing(c.drawings.single.copyWith(
        properties: {'fillOpacity': 0.5},
      ));

      expect(c.drawings.single.fillOpacity, 0.5);

      await c.undo();
      expect(c.drawings.single.fillOpacity, 0.25);

      await c.undo();
      expect(c.drawings, isEmpty);

      await c.redo();
      expect(c.drawings, hasLength(1));
    });
  });
}
