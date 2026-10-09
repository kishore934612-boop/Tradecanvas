/// AnalysisToolFactory instantiates predefined Smart Analysis objects.
library;

import 'package:flutter/material.dart';

import 'package:app/analysis_tools/models/analysis_metadata.dart';
import 'package:app/analysis_tools/models/analysis_type.dart';
import 'package:app/models/drawing.dart';

class AnalysisToolFactory {
  static int _seq = 0;

  /// Generate a unique ID for analysis objects.
  static String generateId(AnalysisType type) =>
      'analysis_${type.name}_${DateTime.now().millisecondsSinceEpoch}_${_seq++}';

  /// Create a fully configured Drawing for a given AnalysisType and initial anchors.
  static Drawing createDrawing({
    required AnalysisType type,
    required String symbol,
    required List<DrawingAnchor> anchors,
    String? customLabel,
  }) {
    final id = generateId(type);
    final now = DateTime.now().millisecondsSinceEpoch;
    final primaryColor = type.defaultColorValue;
    final opacity = type.defaultFillOpacity;
    final fillColor = type.underlyingTool == DrawingTool.rectangle
        ? Color(primaryColor).withValues(alpha: opacity).toARGB32()
        : null;

    final label = customLabel ?? type.shortLabel;

    final metadata = AnalysisMetadata(
      id: id,
      analysisType: type,
      direction: type.direction ?? 'neutral',
      createdAt: now,
      updatedAt: now,
      symbol: symbol,
      label: label,
      style: {
        'color': primaryColor,
        'fillColor': ?fillColor,
        'fillOpacity': opacity,
        'strokeWidth': 1.5,
      },
    );

    final props = <String, dynamic>{
      'analysisType': type.name,
      'analysisMetadata': metadata.toJson(),
      'labelText': label,
      'fillOpacity': opacity,
      'group': 'Analysis',
    };

    return Drawing(
      id: id,
      tool: type.underlyingTool,
      symbol: symbol,
      anchors: anchors,
      colorValue: primaryColor,
      fillColorValue: fillColor,
      strokeWidth: 1.5,
      text: label,
      isComplete: anchors.length >= type.anchorCount,
      createdAt: now,
      properties: props,
    );
  }

  /// Wrap an existing drawing with updated analysis metadata properties.
  static Drawing attachMetadata(Drawing drawing, AnalysisMetadata metadata) {
    final updatedProps = Map<String, dynamic>.from(drawing.properties ?? {});
    updatedProps['analysisType'] = metadata.analysisType.name;
    updatedProps['analysisMetadata'] = metadata.toJson();
    updatedProps['labelText'] = metadata.label;
    updatedProps['group'] = 'Analysis';

    return drawing.copyWith(
      text: metadata.label,
      colorValue: (metadata.style['color'] as num?)?.toInt() ?? drawing.colorValue,
      fillColorValue: (metadata.style['fillColor'] as num?)?.toInt() ?? drawing.fillColorValue,
      properties: updatedProps,
    );
  }
}
