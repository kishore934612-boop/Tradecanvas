/// Tests for the per-symbol undo/redo stack.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:app/engine/drawing_history.dart';
import 'package:app/models/drawing.dart';

Drawing _line(String id, {int price = 100}) => Drawing(
      id: id,
      tool: DrawingTool.horizontalLine,
      symbol: 'BTCUSDT',
      anchors: [DrawingAnchor(timestamp: 0, price: price.toDouble())],
      colorValue: 0xFF000000,
      createdAt: 0,
    );

void main() {
  group('DrawingHistory', () {
    test('starts with nothing to undo or redo', () {
      final h = DrawingHistory();
      expect(h.canUndo, isFalse);
      expect(h.canRedo, isFalse);
    });

    test('push makes an edit undoable', () {
      final h = DrawingHistory();
      h.push(DrawingEdit(
        symbol: 'BTCUSDT',
        before: [],
        after: [_line('a')],
        description: 'Add line',
      ));
      expect(h.canUndo, isTrue);
      expect(h.canRedo, isFalse);
      expect(h.nextUndoDescription, 'Add line');
    });

    test('undo moves the edit to the redo stack and returns it', () {
      final h = DrawingHistory();
      final edit = DrawingEdit(
        symbol: 'BTCUSDT',
        before: [],
        after: [_line('a')],
        description: 'Add line',
      );
      h.push(edit);

      final undone = h.undo();
      expect(undone, same(edit));
      expect(h.canUndo, isFalse);
      expect(h.canRedo, isTrue);
    });

    test('redo replays an undone edit', () {
      final h = DrawingHistory();
      final edit = DrawingEdit(
        symbol: 'BTCUSDT',
        before: [],
        after: [_line('a')],
        description: 'Add line',
      );
      h.push(edit);
      h.undo();

      final redone = h.redo();
      expect(redone, same(edit));
      expect(h.canUndo, isTrue);
      expect(h.canRedo, isFalse);
    });

    test('multiple edits undo in reverse order (LIFO)', () {
      final h = DrawingHistory();
      final e1 = DrawingEdit(symbol: 'BTCUSDT', before: [], after: [_line('a')], description: 'Add a');
      final e2 = DrawingEdit(symbol: 'BTCUSDT', before: [_line('a')], after: [_line('a'), _line('b')], description: 'Add b');
      final e3 = DrawingEdit(symbol: 'BTCUSDT', before: [_line('a'), _line('b')], after: [_line('a'), _line('b'), _line('c')], description: 'Add c');

      h.push(e1);
      h.push(e2);
      h.push(e3);

      expect(h.undo(), same(e3));
      expect(h.undo(), same(e2));
      expect(h.undo(), same(e1));
      expect(h.canUndo, isFalse);
    });

    test('redo replays in the original forward order', () {
      final h = DrawingHistory();
      final e1 = DrawingEdit(symbol: 'BTCUSDT', before: [], after: [_line('a')], description: 'Add a');
      final e2 = DrawingEdit(symbol: 'BTCUSDT', before: [_line('a')], after: [_line('a'), _line('b')], description: 'Add b');

      h.push(e1);
      h.push(e2);
      h.undo();
      h.undo();

      expect(h.redo(), same(e1));
      expect(h.redo(), same(e2));
      expect(h.canRedo, isFalse);
    });

    test('a new edit after undo discards the redo branch', () {
      final h = DrawingHistory();
      final e1 = DrawingEdit(symbol: 'BTCUSDT', before: [], after: [_line('a')], description: 'Add a');
      final e2 = DrawingEdit(symbol: 'BTCUSDT', before: [_line('a')], after: [_line('a'), _line('b')], description: 'Add b');

      h.push(e1);
      h.undo();
      expect(h.canRedo, isTrue);

      h.push(e2);
      expect(h.canRedo, isFalse, reason: 'redo branch is unreachable after a new edit');
    });

    test('undo/redo on an empty stack returns null without throwing', () {
      final h = DrawingHistory();
      expect(h.undo(), isNull);
      expect(h.redo(), isNull);
    });

    test('descriptions reflect the next edit to be applied', () {
      final h = DrawingHistory();
      h.push(DrawingEdit(symbol: 'BTCUSDT', before: [], after: [_line('a')], description: 'Add a'));
      h.push(DrawingEdit(symbol: 'BTCUSDT', before: [_line('a')], after: [], description: 'Delete a'));

      expect(h.nextUndoDescription, 'Delete a');
      h.undo();
      expect(h.nextRedoDescription, 'Delete a');
      expect(h.nextUndoDescription, 'Add a');
    });

    test('clear wipes both stacks', () {
      final h = DrawingHistory();
      h.push(DrawingEdit(symbol: 'BTCUSDT', before: [], after: [_line('a')], description: 'Add a'));
      h.undo();
      expect(h.canRedo, isTrue);

      h.clear();
      expect(h.canUndo, isFalse);
      expect(h.canRedo, isFalse);
    });

    test('depth is capped so a long session cannot grow it unboundedly', () {
      final h = DrawingHistory();
      for (var i = 0; i < DrawingHistory.maxDepth + 20; i++) {
        h.push(DrawingEdit(
          symbol: 'BTCUSDT',
          before: [],
          after: [_line('d$i')],
          description: 'Edit $i',
        ));
      }

      var count = 0;
      while (h.canUndo) {
        h.undo();
        count++;
      }
      expect(count, DrawingHistory.maxDepth);
    });
  });
}
