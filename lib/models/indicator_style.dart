import 'dart:ui' show Color;
import 'package:app/engine/indicators.dart';

/// Style properties (color and line boldness/stroke width) for an indicator.
class IndicatorStyle {
  final int colorValue;
  final double strokeWidth;

  const IndicatorStyle({
    required this.colorValue,
    this.strokeWidth = 1.8,
  });

  Color get color => Color(colorValue);

  IndicatorStyle copyWith({
    int? colorValue,
    double? strokeWidth,
  }) {
    return IndicatorStyle(
      colorValue: colorValue ?? this.colorValue,
      strokeWidth: strokeWidth ?? this.strokeWidth,
    );
  }

  Map<String, dynamic> toJson() => {
        'colorValue': colorValue,
        'strokeWidth': strokeWidth,
      };

  factory IndicatorStyle.fromJson(Map<String, dynamic> json, IndicatorType type) {
    return IndicatorStyle(
      colorValue: (json['colorValue'] as num?)?.toInt() ?? type.colorValue,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 1.8,
    );
  }

  static IndicatorStyle defaultStyle(IndicatorType type) {
    return IndicatorStyle(
      colorValue: type.colorValue,
      strokeWidth: type == IndicatorType.volume ? 1.0 : 1.8,
    );
  }
}
