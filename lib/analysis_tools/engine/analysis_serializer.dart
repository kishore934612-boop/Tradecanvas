/// Serialization logic for Smart Analysis metadata.
library;

import 'dart:convert';
import 'package:app/analysis_tools/models/analysis_metadata.dart';
import 'package:app/analysis_tools/models/analysis_object.dart';
import 'package:app/models/drawing.dart';

class AnalysisSerializer {
  /// Converts an AnalysisObject into a JSON string suitable for persistence.
  static String serialize(AnalysisObject obj) {
    return jsonEncode(obj.toJson());
  }

  /// Encodes AnalysisMetadata directly into a Drawing property map.
  static Map<String, dynamic> encodeProperties(AnalysisMetadata metadata) {
    return {
      'analysisType': metadata.analysisType.name,
      'analysisMetadata': metadata.toJson(),
      'labelText': metadata.label,
      'group': 'Analysis',
    };
  }

  /// Attempts to parse AnalysisMetadata from a Drawing model.
  static AnalysisMetadata? decodeMetadata(Drawing drawing) {
    final props = drawing.properties;
    if (props == null) return null;
    if (props.containsKey('analysisMetadata')) {
      try {
        final raw = Map<String, dynamic>.from(props['analysisMetadata'] as Map);
        return AnalysisMetadata.fromJson(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
