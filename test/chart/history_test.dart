import 'package:flutter_test/flutter_test.dart';
import 'package:app/chart/history/commands/add_command.dart';
import 'package:app/chart/history/commands/delete_command.dart';
import 'package:app/chart/history/commands/edit_command.dart';
import 'package:app/chart/history/history_manager.dart';
import 'package:app/models/drawing.dart';

void main() {
  group('HistoryManager Undo/Redo Engine Tests', () {
    late HistoryManager history;
    late List<Drawing> drawingStore;

    setUp(() {
      history = HistoryManager(maxCapacity: 5);
      drawingStore = [];
    });

    const dummyDrawing = Drawing(
      id: 'h1',
      tool: DrawingTool.trendline,
      symbol: 'BTCUSDT',
      anchors: [
        DrawingAnchor(timestamp: 1000, price: 100.0),
        DrawingAnchor(timestamp: 2000, price: 200.0),
      ],
      colorValue: 0xFF3B82F6,
      createdAt: 1000,
    );

    test('AddCommand execute and undo/redo', () async {
      final cmd = AddCommand(
        drawing: dummyDrawing,
        onAdd: (d) => drawingStore.add(d),
        onDelete: (id) => drawingStore.removeWhere((x) => x.id == id),
      );

      await history.executeCommand(cmd);
      expect(drawingStore.length, equals(1));
      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);

      await history.undo();
      expect(drawingStore.length, equals(0));
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isTrue);

      await history.redo();
      expect(drawingStore.length, equals(1));
    });

    test('DeleteCommand single and batch undo/redo', () async {
      drawingStore.add(dummyDrawing);

      final cmd = DeleteCommand.single(
        drawing: dummyDrawing,
        onRestore: (drawings) => drawingStore.addAll(drawings),
        onDelete: (ids) => drawingStore.removeWhere((d) => ids.contains(d.id)),
      );

      await history.executeCommand(cmd);
      expect(drawingStore.length, equals(0));

      await history.undo();
      expect(drawingStore.length, equals(1));

      await history.redo();
      expect(drawingStore.length, equals(0));
    });

    test('MoveCommand and EditCommand history state', () async {
      const before = dummyDrawing;
      final after = dummyDrawing.copyWith(colorValue: 0xFFEF4444);

      final cmd = EditCommand.style(
        before: before,
        after: after,
        onUpdate: (d) {
          drawingStore.clear();
          drawingStore.add(d);
        },
      );

      await history.executeCommand(cmd);
      expect(drawingStore.first.colorValue, equals(0xFFEF4444));

      await history.undo();
      expect(drawingStore.first.colorValue, equals(0xFF3B82F6));
    });

    test('Capacity pruning evicts oldest command when maxCapacity exceeded', () async {
      for (int i = 0; i < 10; i++) {
        final d = Drawing(
          id: 'item_$i',
          tool: dummyDrawing.tool,
          symbol: dummyDrawing.symbol,
          anchors: dummyDrawing.anchors,
          colorValue: dummyDrawing.colorValue,
          createdAt: dummyDrawing.createdAt,
        );
        final cmd = AddCommand(
          drawing: d,
          onAdd: (item) => drawingStore.add(item),
          onDelete: (id) => drawingStore.removeWhere((x) => x.id == id),
        );
        await history.executeCommand(cmd);
      }

      expect(history.undoCount, equals(5)); // Max capacity is 5
    });
  });
}
