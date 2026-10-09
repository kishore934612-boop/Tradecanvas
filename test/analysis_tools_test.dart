import 'package:flutter_test/flutter_test.dart';
import 'package:app/analysis_tools/models/analysis_type.dart';
import 'package:app/analysis_tools/models/analysis_object.dart';
import 'package:app/analysis_tools/engine/analysis_tool_factory.dart';
import 'package:app/analysis_tools/engine/analysis_serializer.dart';
import 'package:app/models/drawing.dart';

void main() {
  group('Smart Analysis Tools Framework Tests', () {
    test('AnalysisType properties match requirements', () {
      expect(AnalysisType.bullishOrderBlock.category, equals(AnalysisCategory.smartMoney));
      expect(AnalysisType.bullishOrderBlock.shortLabel, equals('OB'));
      expect(AnalysisType.bullishOrderBlock.direction, equals('bullish'));

      expect(AnalysisType.bearishFvg.category, equals(AnalysisCategory.smartMoney));
      expect(AnalysisType.bearishFvg.shortLabel, equals('FVG'));
      expect(AnalysisType.bearishFvg.direction, equals('bearish'));

      expect(AnalysisType.bsl.shortLabel, equals('BSL'));
      expect(AnalysisType.ssl.shortLabel, equals('SSL'));
      expect(AnalysisType.bos.shortLabel, equals('BOS'));
      expect(AnalysisType.choch.shortLabel, equals('CHoCH'));
      expect(AnalysisType.liquiditySweep.shortLabel, equals('Sweep'));
    });

    test('AnalysisToolFactory generates correctly configured drawing', () {
      const anchor1 = DrawingAnchor(timestamp: 1600000000000, price: 100.0);
      const anchor2 = DrawingAnchor(timestamp: 1600036000000, price: 105.0);

      final obDrawing = AnalysisToolFactory.createDrawing(
        type: AnalysisType.bullishOrderBlock,
        symbol: 'BTCUSDT',
        anchors: [anchor1, anchor2],
      );

      expect(obDrawing.tool, equals(DrawingTool.rectangle));
      expect(obDrawing.text, equals('OB'));
      expect(obDrawing.isAnalysisObject, isTrue);
      expect(obDrawing.analysisTypeId, equals('bullishOrderBlock'));

      final meta = AnalysisSerializer.decodeMetadata(obDrawing);
      expect(meta, isNotNull);
      expect(meta!.analysisType, equals(AnalysisType.bullishOrderBlock));
      expect(meta.direction, equals('bullish'));
    });

    test('AnalysisObject bridging and serialization round-trip', () {
      const anchor1 = DrawingAnchor(timestamp: 1600000000000, price: 100.0);
      const anchor2 = DrawingAnchor(timestamp: 1600036000000, price: 105.0);

      final drawing = AnalysisToolFactory.createDrawing(
        type: AnalysisType.bullishFvg,
        symbol: 'ETHUSDT',
        anchors: [anchor1, anchor2],
      );

      final analysisObj = AnalysisObject.fromDrawing(drawing);
      expect(analysisObj.type, equals(AnalysisType.bullishFvg));
      expect(analysisObj.symbol, equals('ETHUSDT'));

      final reserializedDrawing = analysisObj.toDrawing();
      expect(reserializedDrawing.isAnalysisObject, isTrue);
      expect(reserializedDrawing.text, equals('FVG'));

      final jsonStr = AnalysisSerializer.serialize(analysisObj);
      expect(jsonStr.contains('bullishFvg'), isTrue);
    });
  });
}
