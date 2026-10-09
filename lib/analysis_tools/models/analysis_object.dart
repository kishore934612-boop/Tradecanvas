/// AnalysisObject bridges underlying Drawing geometry with rich Smart Analysis metadata.
library;

import 'package:app/analysis_tools/models/analysis_metadata.dart';
import 'package:app/analysis_tools/models/analysis_type.dart';
import 'package:app/models/drawing.dart';

class AnalysisObject {
  final Drawing drawing;
  final AnalysisMetadata metadata;

  const AnalysisObject({
    required this.drawing,
    required this.metadata,
  });

  String get id => drawing.id;
  AnalysisType get type => metadata.analysisType;
  String get symbol => drawing.symbol;
  List<DrawingAnchor> get anchors => drawing.anchors;
  bool get visible => metadata.visible;
  bool get locked => metadata.locked;

  AnalysisObject copyWith({
    Drawing? drawing,
    AnalysisMetadata? metadata,
  }) {
    return AnalysisObject(
      drawing: drawing ?? this.drawing,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Create a Drawing representation containing analysis metadata inside properties.
  Drawing toDrawing() {
    final updatedProps = Map<String, dynamic>.from(drawing.properties ?? {});
    updatedProps['analysisMetadata'] = metadata.toJson();
    updatedProps['locked'] = metadata.locked;
    updatedProps['visible'] = metadata.visible;
    updatedProps['labelText'] = metadata.label;

    return drawing.copyWith(
      text: metadata.label,
      colorValue: (metadata.style['color'] as num?)?.toInt() ?? drawing.colorValue,
      fillColorValue: (metadata.style['fillColor'] as num?)?.toInt() ?? drawing.fillColorValue,
      properties: updatedProps,
    );
  }

  /// Extract or create an AnalysisObject from a Drawing.
  factory AnalysisObject.fromDrawing(Drawing drawing) {
    final props = drawing.properties;
    if (props != null && props.containsKey('analysisMetadata')) {
      final rawMeta = Map<String, dynamic>.from(props['analysisMetadata'] as Map);
      final metadata = AnalysisMetadata.fromJson(rawMeta);
      return AnalysisObject(drawing: drawing, metadata: metadata);
    }

    // Fallback heuristic if drawing has an analysisType property or title match
    final typeId = props?['analysisType'] as String?;
    final type = typeId != null
        ? AnalysisType.fromId(typeId)
        : _inferTypeFromDrawing(drawing);

    final metadata = AnalysisMetadata(
      id: drawing.id,
      analysisType: type,
      direction: type.direction ?? 'neutral',
      createdAt: drawing.createdAt,
      updatedAt: (props?['updatedAt'] as num?)?.toInt() ?? drawing.createdAt,
      symbol: drawing.symbol,
      label: drawing.text?.isNotEmpty == true ? drawing.text! : type.shortLabel,
      visible: props?['visible'] as bool? ?? true,
      locked: props?['locked'] as bool? ?? false,
      style: {
        'color': drawing.colorValue,
        'fillColor': drawing.fillColorValue,
        'strokeWidth': drawing.strokeWidth,
      },
    );

    return AnalysisObject(drawing: drawing, metadata: metadata);
  }

  static AnalysisType _inferTypeFromDrawing(Drawing drawing) {
    final text = drawing.text?.toLowerCase() ?? '';
    if (text.contains('ob') || text.contains('order block')) {
      return drawing.colorValue == 0xFFEF4444
          ? AnalysisType.bearishOrderBlock
          : AnalysisType.bullishOrderBlock;
    }
    if (text.contains('fvg')) {
      return drawing.colorValue == 0xFFF97316
          ? AnalysisType.bearishFvg
          : AnalysisType.bullishFvg;
    }
    if (text.contains('bsl')) return AnalysisType.bsl;
    if (text.contains('ssl')) return AnalysisType.ssl;
    if (text.contains('bos')) return AnalysisType.bos;
    if (text.contains('choch')) return AnalysisType.choch;
    if (text.contains('support')) return AnalysisType.supportZone;
    if (text.contains('resistance')) return AnalysisType.resistanceZone;

    return AnalysisType.bullishOrderBlock;
  }

  Map<String, dynamic> toJson() => {
        'drawing': drawing.toJson(),
        'metadata': metadata.toJson(),
      };
}
