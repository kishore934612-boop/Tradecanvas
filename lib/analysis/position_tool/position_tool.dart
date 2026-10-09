/// Unified Position Tool model supporting Long Position, Short Position, and Risk Reward tools.
library;

import 'package:app/models/drawing.dart';

enum PositionToolMode { longPosition, shortPosition, riskReward }

class PositionTool {
  final String id;
  final String symbol;
  final PositionToolMode mode;
  final double entryPrice;
  final double stopLossPrice;
  final double takeProfitPrice;
  final int entryTimestamp;
  final int targetTimestamp;
  final double accountSize;
  final double riskPercent;
  final double leverage;
  final double feePercent;
  final double slippagePercent;
  final bool visible;
  final bool locked;
  final int createdAt;

  const PositionTool({
    required this.id,
    required this.symbol,
    required this.mode,
    required this.entryPrice,
    required this.stopLossPrice,
    required this.takeProfitPrice,
    required this.entryTimestamp,
    required this.targetTimestamp,
    this.accountSize = 10000.0,
    this.riskPercent = 1.0,
    this.leverage = 1.0,
    this.feePercent = 0.075, // 0.075% maker/taker fee default
    this.slippagePercent = 0.05,
    this.visible = true,
    this.locked = false,
    required this.createdAt,
  });

  PositionTool copyWith({
    String? id,
    String? symbol,
    PositionToolMode? mode,
    double? entryPrice,
    double? stopLossPrice,
    double? takeProfitPrice,
    int? entryTimestamp,
    int? targetTimestamp,
    double? accountSize,
    double? riskPercent,
    double? leverage,
    double? feePercent,
    double? slippagePercent,
    bool? visible,
    bool? locked,
    int? createdAt,
  }) {
    return PositionTool(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      mode: mode ?? this.mode,
      entryPrice: entryPrice ?? this.entryPrice,
      stopLossPrice: stopLossPrice ?? this.stopLossPrice,
      takeProfitPrice: takeProfitPrice ?? this.takeProfitPrice,
      entryTimestamp: entryTimestamp ?? this.entryTimestamp,
      targetTimestamp: targetTimestamp ?? this.targetTimestamp,
      accountSize: accountSize ?? this.accountSize,
      riskPercent: riskPercent ?? this.riskPercent,
      leverage: leverage ?? this.leverage,
      feePercent: feePercent ?? this.feePercent,
      slippagePercent: slippagePercent ?? this.slippagePercent,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert PositionTool to a Drawing model for unified rendering/persistence
  Drawing toDrawing() {
    final tool = mode == PositionToolMode.longPosition
        ? DrawingTool.longPosition
        : mode == PositionToolMode.shortPosition
            ? DrawingTool.shortPosition
            : DrawingTool.measurement;

    return Drawing(
      id: id,
      tool: tool,
      symbol: symbol,
      anchors: [
        DrawingAnchor(timestamp: entryTimestamp, price: entryPrice),
        DrawingAnchor(timestamp: targetTimestamp, price: takeProfitPrice),
        DrawingAnchor(timestamp: entryTimestamp, price: stopLossPrice),
      ],
      colorValue: mode == PositionToolMode.riskReward ? 0xFF3B82F6 : 0xFF10B981,
      createdAt: createdAt,
      properties: {
        'positionMode': mode.name,
        'accountSize': accountSize,
        'riskPercent': riskPercent,
        'leverage': leverage,
        'feePercent': feePercent,
        'slippagePercent': slippagePercent,
        'visible': visible,
        'locked': locked,
      },
    );
  }

  /// Convert a Drawing model to PositionTool
  factory PositionTool.fromDrawing(Drawing drawing) {
    final anchors = drawing.anchors;
    final entry = anchors.isNotEmpty ? anchors[0] : const DrawingAnchor(timestamp: 0, price: 0);
    final target = anchors.length > 1 ? anchors[1] : entry;
    final stop = anchors.length > 2 ? anchors[2] : entry;

    PositionToolMode mode = PositionToolMode.longPosition;
    final modeStr = drawing.properties?['positionMode'] as String?;
    if (modeStr != null) {
      mode = PositionToolMode.values.firstWhere((e) => e.name == modeStr, orElse: () => PositionToolMode.longPosition);
    } else {
      if (drawing.tool == DrawingTool.shortPosition) {
        mode = PositionToolMode.shortPosition;
      } else if (drawing.tool == DrawingTool.measurement) {
        mode = PositionToolMode.riskReward;
      }
    }

    return PositionTool(
      id: drawing.id,
      symbol: drawing.symbol,
      mode: mode,
      entryPrice: entry.price,
      takeProfitPrice: target.price,
      stopLossPrice: stop.price,
      entryTimestamp: entry.timestamp,
      targetTimestamp: target.timestamp,
      accountSize: (drawing.properties?['accountSize'] as num?)?.toDouble() ?? 10000.0,
      riskPercent: (drawing.properties?['riskPercent'] as num?)?.toDouble() ?? 1.0,
      leverage: (drawing.properties?['leverage'] as num?)?.toDouble() ?? 1.0,
      feePercent: (drawing.properties?['feePercent'] as num?)?.toDouble() ?? 0.075,
      slippagePercent: (drawing.properties?['slippagePercent'] as num?)?.toDouble() ?? 0.05,
      visible: drawing.properties?['visible'] as bool? ?? true,
      locked: drawing.properties?['locked'] as bool? ?? false,
      createdAt: drawing.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'mode': mode.name,
        'entryPrice': entryPrice,
        'stopLossPrice': stopLossPrice,
        'takeProfitPrice': takeProfitPrice,
        'entryTimestamp': entryTimestamp,
        'targetTimestamp': targetTimestamp,
        'accountSize': accountSize,
        'riskPercent': riskPercent,
        'leverage': leverage,
        'feePercent': feePercent,
        'slippagePercent': slippagePercent,
        'visible': visible,
        'locked': locked,
        'createdAt': createdAt,
      };

  factory PositionTool.fromJson(Map<String, dynamic> json) => PositionTool(
        id: json['id'] as String,
        symbol: json['symbol'] as String,
        mode: PositionToolMode.values.firstWhere(
          (e) => e.name == json['mode'],
          orElse: () => PositionToolMode.longPosition,
        ),
        entryPrice: (json['entryPrice'] as num).toDouble(),
        stopLossPrice: (json['stopLossPrice'] as num).toDouble(),
        takeProfitPrice: (json['takeProfitPrice'] as num).toDouble(),
        entryTimestamp: (json['entryTimestamp'] as num).toInt(),
        targetTimestamp: (json['targetTimestamp'] as num).toInt(),
        accountSize: (json['accountSize'] as num?)?.toDouble() ?? 10000.0,
        riskPercent: (json['riskPercent'] as num?)?.toDouble() ?? 1.0,
        leverage: (json['leverage'] as num?)?.toDouble() ?? 1.0,
        feePercent: (json['feePercent'] as num?)?.toDouble() ?? 0.075,
        slippagePercent: (json['slippagePercent'] as num?)?.toDouble() ?? 0.05,
        visible: json['visible'] as bool? ?? true,
        locked: json['locked'] as bool? ?? false,
        createdAt: (json['createdAt'] as num).toInt(),
      );
}
