/// Tests for [DrawingController]'s undo/redo integration.
///
/// These exercise the full mutation path — add, move, restyle, delete, clear
/// — through the public API and assert both the in-memory drawing list and
/// the (fake) repository end up consistent after undo/redo.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/logging/logger.dart';
import 'package:app/engine/drawing_controller.dart';
import 'package:app/models/drawing.dart';

import '../helpers/fake_drawing_repository.dart';

const _symbol = 'BTCUSDT';

DrawingController _controller(FakeDrawingRepository repo) => DrawingController(
      repository: repo,
      logger: Logger.instance,
      symbol: _symbol,
    );

Future<void> _addHorizontalLine(DrawingController c, double price) async {
  c.setActiveTool(DrawingTool.horizontalLine);
  await c.addAnchor(DrawingAnchor(timestamp: 0, price: price));
}

void main() {
  group('add + undo + redo', () {
    test('undo after adding removes the drawing', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      await _addHorizontalLine(c, 100);
      expect(c.drawings, hasLength(1));
      expect(c.canUndo, isTrue);

      await c.undo();
      expect(c.drawings, isEmpty);
      expect(c.canRedo, isTrue);
    });

    test('redo after undoing an add restores the drawing', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      await _addHorizontalLine(c, 100);
      final id = c.drawings.single.id;

      await c.undo();
      await c.redo();

      expect(c.drawings, hasLength(1));
      expect(c.drawings.single.id, id);
    });

    test('multiple adds undo in reverse (LIFO) order', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      await _addHorizontalLine(c, 100);
      await _addHorizontalLine(c, 200);
      await _addHorizontalLine(c, 300);
      expect(c.drawings, hasLength(3));

      await c.undo();
      expect(c.drawings, hasLength(2));
      expect(c.drawings.map((d) => d.anchors.first.price), [100.0, 200.0]);

      await c.undo();
      expect(c.drawings, hasLength(1));

      await c.undo();
      expect(c.drawings, isEmpty);
      expect(c.canUndo, isFalse);
    });

    test('a new add after undo discards the redo branch', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      await _addHorizontalLine(c, 100);
      await c.undo();
      expect(c.canRedo, isTrue);

      await _addHorizontalLine(c, 200);
      expect(c.canRedo, isFalse);
      expect(c.drawings.single.anchors.first.price, 200.0);
    });
  });

  group('delete + undo', () {
    test('undo after deleting restores the drawing', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      await _addHorizontalLine(c, 100);
      final id = c.drawings.single.id;

      await c.delete(id);
      expect(c.drawings, isEmpty);

      await c.undo();
      expect(c.drawings, hasLength(1));
      expect(c.drawings.single.id, id);
    });

    test('deleting the selected drawing clears the selection', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      await _addHorizontalLine(c, 100);
      final id = c.drawings.single.id;
      c.select(id);

      await c.deleteSelected();
      expect(c.selected, isNull);
    });
  });

  group('style edits (color / stroke width)', () {
    test('undo after a color change reverts it', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      await _addHorizontalLine(c, 100);
      final id = c.drawings.single.id;
      c.select(id);
      final originalColor = c.selected!.colorValue;

      c.setColor(0xFFFF0000);
      expect(c.selected!.colorValue, 0xFFFF0000);

      await c.undo();
      expect(c.drawings.firstWhere((d) => d.id == id).colorValue, originalColor);
    });

    test('undo after a stroke width change reverts it', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      await _addHorizontalLine(c, 100);
      c.select(c.drawings.single.id);

      c.setStrokeWidth(3.0);
      expect(c.selected!.strokeWidth, 3.0);

      await c.undo();
      expect(c.drawings.single.strokeWidth, isNot(3.0));
    });
  });

  group('transient move edits (drag gestures)', () {
    test('a full drag (begin -> moveAnchor* -> commit) is a single undo step', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      await _addHorizontalLine(c, 100);
      final id = c.drawings.single.id;

      c.beginTransientEdit();
      // Simulate several per-frame updates during one drag gesture.
      c.moveAnchor(id, 0, const DrawingAnchor(timestamp: 0, price: 150));
      c.moveAnchor(id, 0, const DrawingAnchor(timestamp: 0, price: 175));
      c.moveAnchor(id, 0, const DrawingAnchor(timestamp: 0, price: 200));
      await c.commitEdit(id);

      expect(c.drawings.single.anchors.first.price, 200.0);

      // One undo should return all the way to the pre-drag position, not
      // just undo the last per-frame update.
      await c.undo();
      expect(c.drawings.single.anchors.first.price, 100.0);
    });

    test('translate during a transient edit also collapses to one undo step', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      await _addHorizontalLine(c, 100);
      final id = c.drawings.single.id;

      c.beginTransientEdit();
      c.translate(id, 0, 10);
      c.translate(id, 0, 10);
      await c.commitEdit(id);

      expect(c.drawings.single.anchors.first.price, 120.0);

      await c.undo();
      expect(c.drawings.single.anchors.first.price, 100.0);
    });
  });

  group('clear + undo', () {
    test('undo after clearing restores every drawing', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      await _addHorizontalLine(c, 100);
      await _addHorizontalLine(c, 200);
      expect(c.drawings, hasLength(2));

      await c.clearSymbol();
      expect(c.drawings, isEmpty);

      await c.undo();
      expect(c.drawings, hasLength(2));
    });
  });

  group('repository consistency', () {
    test('undoing an add also removes it from the repository', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      await _addHorizontalLine(c, 100);
      expect(repo.all, hasLength(1));

      await c.undo();
      expect(repo.all, isEmpty);
    });

    test('redoing a delete removes it from the repository again', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      await _addHorizontalLine(c, 100);
      final id = c.drawings.single.id;
      await c.delete(id);
      expect(repo.all, isEmpty);

      await c.undo(); // restore the delete
      expect(repo.all, hasLength(1));

      await c.redo(); // redo the delete
      expect(repo.all, isEmpty);
    });
  });

  group('per-symbol isolation', () {
    test('each symbol has its own undo stack', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      await _addHorizontalLine(c, 100);
      expect(c.canUndo, isTrue);

      await c.setSymbol('ETHUSDT');
      expect(c.canUndo, isFalse, reason: 'ETHUSDT has no history yet');

      await c.setSymbol(_symbol);
      expect(c.canUndo, isTrue, reason: 'BTCUSDT history is preserved');
    });
  });

  group('continuous drawing mode', () {
    test('tool resets to null after commit when continuous mode is false', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      c.setActiveTool(DrawingTool.trendline);
      await c.addAnchor(const DrawingAnchor(timestamp: 0, price: 100));
      await c.addAnchor(const DrawingAnchor(timestamp: 10, price: 110));

      expect(c.drawings, hasLength(1));
      expect(c.activeTool, isNull);
    });

    test('tool stays active after commit when continuous mode is true', () async {
      final repo = FakeDrawingRepository();
      final c = _controller(repo);

      c.setContinuousDrawing(true);
      expect(c.isContinuousDrawing, isTrue);

      c.setActiveTool(DrawingTool.trendline);
      await c.addAnchor(const DrawingAnchor(timestamp: 0, price: 100));
      await c.addAnchor(const DrawingAnchor(timestamp: 10, price: 110));

      expect(c.drawings, hasLength(1));
      expect(c.activeTool, DrawingTool.trendline);

      // Add a second line immediately without reselecting the tool
      await c.addAnchor(const DrawingAnchor(timestamp: 20, price: 120));
      await c.addAnchor(const DrawingAnchor(timestamp: 30, price: 130));

      expect(c.drawings, hasLength(2));
      expect(c.activeTool, DrawingTool.trendline);
    });
  });
}
