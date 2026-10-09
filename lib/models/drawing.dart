/// Drawing tool models.
///
/// Anchors are stored in **data space** (timestamp + price), never in pixels.
/// This is what lets a drawing survive zoom, pan, timeframe switches and
/// window resizes: the painter projects anchors through the same transform
/// as the candles on every frame.
library;

import 'dart:ui' show Color;

enum DrawingTool {
  trendline,
  arrow,
  horizontalLine,
  verticalLine,
  rectangle,
  fibRetracement,
  text,
  measurement,
  flatTopBottom,
  triangle,
  parallelChannel,
  fibExtension,
  callout,
  htfOverlay,
  longPosition,
  shortPosition;

  /// Number of anchors the user must place to complete the shape.
  int get anchorCount {
    switch (this) {
      case DrawingTool.horizontalLine:
      case DrawingTool.verticalLine:
      case DrawingTool.text:
      case DrawingTool.htfOverlay:
        return 1;
      case DrawingTool.trendline:
      case DrawingTool.arrow:
      case DrawingTool.rectangle:
      case DrawingTool.fibRetracement:
      case DrawingTool.measurement:
      case DrawingTool.flatTopBottom:
      case DrawingTool.callout:
        return 2;
      case DrawingTool.triangle:
      case DrawingTool.parallelChannel:
      case DrawingTool.fibExtension:
      case DrawingTool.longPosition:
      case DrawingTool.shortPosition:
        return 3;
    }
  }

  String get label {
    switch (this) {
      case DrawingTool.trendline:
        return 'Trend Line';
      case DrawingTool.arrow:
        return 'Arrow';
      case DrawingTool.horizontalLine:
        return 'Horizontal Line';
      case DrawingTool.verticalLine:
        return 'Vertical Line';
      case DrawingTool.rectangle:
        return 'Rectangle';
      case DrawingTool.fibRetracement:
        return 'Fib Retracement';
      case DrawingTool.text:
        return 'Text';
      case DrawingTool.measurement:
        return 'Measurement';
      case DrawingTool.flatTopBottom:
        return 'Flat Top/Bottom';
      case DrawingTool.triangle:
        return 'Triangle';
      case DrawingTool.parallelChannel:
        return 'Parallel Channel';
      case DrawingTool.fibExtension:
        return 'Fib Extension';
      case DrawingTool.callout:
        return 'Callout Box';
      case DrawingTool.htfOverlay:
        return 'HTF Level Overlay';
      case DrawingTool.longPosition:
        return 'Long Position';
      case DrawingTool.shortPosition:
        return 'Short Position';
    }
  }

  /// Abbreviated short label displayed in option bars when tool name exceeds 10 characters.
  String get shortLabel {
    if (label.length <= 10) return label;
    switch (this) {
      case DrawingTool.parallelChannel:
        return 'Parallel Ch.';
      case DrawingTool.horizontalLine:
        return 'Horiz. Line';
      case DrawingTool.verticalLine:
        return 'Vert. Line';
      case DrawingTool.fibRetracement:
        return 'Fib Retr.';
      case DrawingTool.fibExtension:
        return 'Fib Ext.';
      case DrawingTool.callout:
        return 'Callout';
      case DrawingTool.htfOverlay:
        return 'HTF Level';
      case DrawingTool.measurement:
        return 'Measure';
      case DrawingTool.flatTopBottom:
        return 'Flat Top/Bot';
      case DrawingTool.longPosition:
        return 'Long Pos.';
      case DrawingTool.shortPosition:
        return 'Short Pos.';
      default:
        return label.substring(0, 10);
    }
  }

  static DrawingTool fromId(String id) => DrawingTool.values.firstWhere(
        (t) => t.name == id,
        orElse: () => DrawingTool.trendline,
      );
}

/// A single point in chart data space.
class DrawingAnchor {
  /// Milliseconds since epoch on the time axis.
  final int timestamp;

  /// Price on the value axis.
  final double price;

  const DrawingAnchor({required this.timestamp, required this.price});

  DrawingAnchor copyWith({int? timestamp, double? price}) => DrawingAnchor(
        timestamp: timestamp ?? this.timestamp,
        price: price ?? this.price,
      );

  Map<String, dynamic> toJson() => {'t': timestamp, 'p': price};

  factory DrawingAnchor.fromJson(Map<String, dynamic> j) => DrawingAnchor(
        timestamp: (j['t'] as num).toInt(),
        price: (j['p'] as num).toDouble(),
      );
}

/// Standard Fibonacci retracement levels.
const List<double> kFibLevels = [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0];

/// Standard Trend-Based Fibonacci Extension levels.
const List<double> kFibExtensionLevels = [
  0.0,
  0.236,
  0.382,
  0.5,
  0.618,
  0.786,
  1.0,
  1.272,
  1.618,
  2.618,
];

class Drawing {
  final String id;
  final DrawingTool tool;

  /// Symbol this drawing belongs to. Drawings are per-instrument.
  final String symbol;

  final List<DrawingAnchor> anchors;

  /// ARGB value. Stored as int so it round-trips through JSON cleanly.
  final int colorValue;

  final double strokeWidth;

  /// Optional text content for text annotations.
  final String? text;

  /// Optional fill color for rectangles and shapes.
  final int? fillColorValue;

  /// Whether trendline extends infinitely in both directions.
  final bool isInfinite;

  /// Whether trendline is a ray (extends infinitely forward).
  final bool isRay;

  /// Font size for text tool.
  final double fontSize;

  /// Background card for text tool.
  final bool showBackground;

  /// Border for text tool.
  final bool showBorder;

  /// Arrowhead size for arrow tool.
  final double arrowHeadSize;

  /// True while the user is still placing anchors.
  final bool isComplete;

  final int createdAt;

  /// Arbitrary tool-specific properties (persisted as JSON).
  final Map<String, dynamic>? properties;

  /// Level label type for HTF Level Overlay tool ('PDH', 'PDL', 'PWH', 'PWL', 'DOpen').
  String get htfLevelType => properties?['htfLevelType'] as String? ?? 'PDH';

  /// Whether this drawing represents a Smart Analysis tool object.
  bool get isAnalysisObject =>
      properties != null &&
      (properties!.containsKey('analysisType') || properties!.containsKey('analysisMetadata'));

  /// Analysis type name string if this is a Smart Analysis tool.
  String? get analysisTypeId => properties?['analysisType'] as String?;

  const Drawing({
    required this.id,
    required this.tool,
    required this.symbol,
    required this.anchors,
    required this.colorValue,
    this.strokeWidth = 1.5,
    this.text,
    this.fillColorValue,
    this.isInfinite = false,
    this.isRay = false,
    this.fontSize = 12.0,
    this.showBackground = true,
    this.showBorder = true,
    this.arrowHeadSize = 12.0,
    this.isComplete = true,
    required this.createdAt,
    this.properties,
  });

  Color get color => Color(colorValue);
  Color? get fillColor => fillColorValue != null ? Color(fillColorValue!) : null;

  // Tool-specific property getters
  bool get isDashed => properties?['isDashed'] as bool? ?? false;
  bool get showLabel => properties?['showLabel'] as bool? ?? true;
  String get labelText =>
      properties?['labelText'] as String? ??
      (tool == DrawingTool.flatTopBottom ? 'Flat Top/Bottom' : '');
  double get fillOpacity =>
      (properties?['fillOpacity'] as num?)?.toDouble() ??
      (tool == DrawingTool.triangle ? 0.25 : 0.35);

  bool get showHandles => properties?['showHandles'] as bool? ?? true;
  bool get showMidline => properties?['showMidline'] as bool? ?? true;

  Drawing copyWith({
    List<DrawingAnchor>? anchors,
    int? colorValue,
    double? strokeWidth,
    String? text,
    int? fillColorValue,
    bool? isInfinite,
    bool? isRay,
    double? fontSize,
    bool? showBackground,
    bool? showBorder,
    double? arrowHeadSize,
    bool? isComplete,
    Map<String, dynamic>? properties,
  }) =>
      Drawing(
        id: id,
        tool: tool,
        symbol: symbol,
        anchors: anchors ?? this.anchors,
        colorValue: colorValue ?? this.colorValue,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        text: text ?? this.text,
        fillColorValue: fillColorValue ?? this.fillColorValue,
        isInfinite: isInfinite ?? this.isInfinite,
        isRay: isRay ?? this.isRay,
        fontSize: fontSize ?? this.fontSize,
        showBackground: showBackground ?? this.showBackground,
        showBorder: showBorder ?? this.showBorder,
        arrowHeadSize: arrowHeadSize ?? this.arrowHeadSize,
        isComplete: isComplete ?? this.isComplete,
        createdAt: createdAt,
        properties: properties ?? this.properties,
      );

  /// Replace the anchor at [index]. Used while dragging a handle.
  Drawing withAnchorAt(int index, DrawingAnchor anchor) {
    if (index < 0 || index >= anchors.length) return this;
    final next = List<DrawingAnchor>.from(anchors);
    next[index] = anchor;
    return copyWith(anchors: next);
  }

  /// Shift every anchor by a time and price delta. Used when dragging
  /// the whole shape rather than one handle.
  Drawing translated(int dtMs, double dPrice) => copyWith(
        anchors: anchors
            .map((a) => DrawingAnchor(
                  timestamp: a.timestamp + dtMs,
                  price: a.price + dPrice,
                ))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'tool': tool.name,
        'symbol': symbol,
        'anchors': anchors.map((a) => a.toJson()).toList(),
        'color': colorValue,
        'width': strokeWidth,
        'text': text,
        'fillColor': fillColorValue,
        'isInfinite': isInfinite,
        'isRay': isRay,
        'fontSize': fontSize,
        'showBackground': showBackground,
        'showBorder': showBorder,
        'arrowHeadSize': arrowHeadSize,
        'createdAt': createdAt,
        if (properties != null) 'properties': properties,
      };

  factory Drawing.fromJson(Map<String, dynamic> j) => Drawing(
        id: j['id'] as String,
        tool: DrawingTool.fromId(j['tool'] as String),
        symbol: j['symbol'] as String,
        anchors: (j['anchors'] as List)
            .map((e) => DrawingAnchor.fromJson(e as Map<String, dynamic>))
            .toList(),
        colorValue: (j['color'] as num).toInt(),
        strokeWidth: (j['width'] as num?)?.toDouble() ?? 1.5,
        text: j['text'] as String?,
        fillColorValue: (j['fillColor'] as num?)?.toInt(),
        isInfinite: j['isInfinite'] as bool? ?? false,
        isRay: j['isRay'] as bool? ?? false,
        fontSize: (j['fontSize'] as num?)?.toDouble() ?? 12.0,
        showBackground: j['showBackground'] as bool? ?? true,
        showBorder: j['showBorder'] as bool? ?? true,
        arrowHeadSize: (j['arrowHeadSize'] as num?)?.toDouble() ?? 12.0,
        createdAt: (j['createdAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        properties: j['properties'] != null
            ? Map<String, dynamic>.from(j['properties'] as Map)
            : null,
      );
}
