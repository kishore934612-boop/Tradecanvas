import 'package:flutter_test/flutter_test.dart';
import 'package:app/analysis/position_tool/position_tool.dart';

void main() {
  group('PositionTool Persistence & Serialization Tests', () {
    const tool = PositionTool(
      id: 'pt_123',
      symbol: 'ETHUSDT',
      mode: PositionToolMode.longPosition,
      entryPrice: 3000.0,
      stopLossPrice: 2900.0,
      takeProfitPrice: 3300.0,
      entryTimestamp: 1600000000000,
      targetTimestamp: 1600003600000,
      accountSize: 20000.0,
      riskPercent: 1.5,
      leverage: 20.0,
      feePercent: 0.04,
      slippagePercent: 0.02,
      createdAt: 1600000000000,
    );

    test('PositionTool serializes to and from JSON cleanly', () {
      final json = tool.toJson();
      final restored = PositionTool.fromJson(json);

      expect(restored.id, equals(tool.id));
      expect(restored.symbol, equals(tool.symbol));
      expect(restored.mode, equals(tool.mode));
      expect(restored.entryPrice, equals(tool.entryPrice));
      expect(restored.stopLossPrice, equals(tool.stopLossPrice));
      expect(restored.takeProfitPrice, equals(tool.takeProfitPrice));
      expect(restored.accountSize, equals(tool.accountSize));
      expect(restored.riskPercent, equals(tool.riskPercent));
      expect(restored.leverage, equals(tool.leverage));
    });

    test('PositionTool converts to and from Drawing model for SQLite persistence', () {
      final drawing = tool.toDrawing();
      expect(drawing.id, equals(tool.id));
      expect(drawing.symbol, equals(tool.symbol));
      expect(drawing.anchors.length, equals(3));
      expect(drawing.anchors[0].price, equals(3000.0));
      expect(drawing.anchors[1].price, equals(3300.0));
      expect(drawing.anchors[2].price, equals(2900.0));

      final restoredTool = PositionTool.fromDrawing(drawing);
      expect(restoredTool.id, equals(tool.id));
      expect(restoredTool.entryPrice, equals(tool.entryPrice));
      expect(restoredTool.takeProfitPrice, equals(tool.takeProfitPrice));
      expect(restoredTool.stopLossPrice, equals(tool.stopLossPrice));
      expect(restoredTool.mode, equals(tool.mode));
    });
  });
}
