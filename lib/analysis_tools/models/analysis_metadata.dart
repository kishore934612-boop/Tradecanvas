/// Analysis Metadata model for storing rich Smart Analysis Tool state.
library;

import 'package:app/analysis_tools/models/analysis_type.dart';

class AnalysisMetadata {
  final String id;
  final AnalysisType analysisType;
  final String direction; // 'bullish', 'bearish', 'neutral'
  final int createdAt;
  final int updatedAt;
  final String symbol;
  final String timeframe;
  final String label;
  final String? notes;
  final bool visible;
  final bool locked;
  final bool selected;
  final int zIndex;
  final Map<String, dynamic> style;
  final bool userCreated;

  // Optional domain properties
  final double? strength;
  final bool mitigated;
  final bool invalidated;
  final bool touched;
  final bool confirmed;

  const AnalysisMetadata({
    required this.id,
    required this.analysisType,
    required this.direction,
    required this.createdAt,
    required this.updatedAt,
    required this.symbol,
    this.timeframe = '1h',
    required this.label,
    this.notes,
    this.visible = true,
    this.locked = false,
    this.selected = false,
    this.zIndex = 0,
    this.style = const {},
    this.userCreated = true,
    this.strength,
    this.mitigated = false,
    this.invalidated = false,
    this.touched = false,
    this.confirmed = false,
  });

  AnalysisMetadata copyWith({
    String? id,
    AnalysisType? analysisType,
    String? direction,
    int? createdAt,
    int? updatedAt,
    String? symbol,
    String? timeframe,
    String? label,
    String? notes,
    bool? visible,
    bool? locked,
    bool? selected,
    int? zIndex,
    Map<String, dynamic>? style,
    bool? userCreated,
    double? strength,
    bool? mitigated,
    bool? invalidated,
    bool? touched,
    bool? confirmed,
  }) {
    return AnalysisMetadata(
      id: id ?? this.id,
      analysisType: analysisType ?? this.analysisType,
      direction: direction ?? this.direction,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      symbol: symbol ?? this.symbol,
      timeframe: timeframe ?? this.timeframe,
      label: label ?? this.label,
      notes: notes ?? this.notes,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      selected: selected ?? this.selected,
      zIndex: zIndex ?? this.zIndex,
      style: style ?? this.style,
      userCreated: userCreated ?? this.userCreated,
      strength: strength ?? this.strength,
      mitigated: mitigated ?? this.mitigated,
      invalidated: invalidated ?? this.invalidated,
      touched: touched ?? this.touched,
      confirmed: confirmed ?? this.confirmed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'analysisType': analysisType.name,
        'direction': direction,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'symbol': symbol,
        'timeframe': timeframe,
        'label': label,
        if (notes != null) 'notes': notes,
        'visible': visible,
        'locked': locked,
        'selected': selected,
        'zIndex': zIndex,
        'style': style,
        'userCreated': userCreated,
        if (strength != null) 'strength': strength,
        'mitigated': mitigated,
        'invalidated': invalidated,
        'touched': touched,
        'confirmed': confirmed,
      };

  factory AnalysisMetadata.fromJson(Map<String, dynamic> j) {
    final typeStr = j['analysisType'] as String? ?? 'bullishOrderBlock';
    final type = AnalysisType.fromId(typeStr);
    return AnalysisMetadata(
      id: j['id'] as String? ?? '',
      analysisType: type,
      direction: j['direction'] as String? ?? type.direction ?? 'neutral',
      createdAt: (j['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: (j['updatedAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      symbol: j['symbol'] as String? ?? '',
      timeframe: j['timeframe'] as String? ?? '1h',
      label: j['label'] as String? ?? type.shortLabel,
      notes: j['notes'] as String?,
      visible: j['visible'] as bool? ?? true,
      locked: j['locked'] as bool? ?? false,
      selected: j['selected'] as bool? ?? false,
      zIndex: (j['zIndex'] as num?)?.toInt() ?? 0,
      style: j['style'] != null ? Map<String, dynamic>.from(j['style'] as Map) : {},
      userCreated: j['userCreated'] as bool? ?? true,
      strength: (j['strength'] as num?)?.toDouble(),
      mitigated: j['mitigated'] as bool? ?? false,
      invalidated: j['invalidated'] as bool? ?? false,
      touched: j['touched'] as bool? ?? false,
      confirmed: j['confirmed'] as bool? ?? false,
    );
  }
}
