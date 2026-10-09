/// Smart Analysis Tool types and categories for TradeCanvas.
library;

import 'package:flutter/material.dart';
import 'package:app/models/drawing.dart';

enum AnalysisCategory {
  marketStructure,
  liquidity,
  smartMoney,
  supplyDemand,
  premiumDiscount;

  String get displayName {
    switch (this) {
      case AnalysisCategory.marketStructure:
        return 'Market Structure';
      case AnalysisCategory.liquidity:
        return 'Liquidity';
      case AnalysisCategory.smartMoney:
        return 'Smart Money Concepts';
      case AnalysisCategory.supplyDemand:
        return 'Supply / Demand';
      case AnalysisCategory.premiumDiscount:
        return 'Premium / Discount';
    }
  }

  String get iconSymbol {
    switch (this) {
      case AnalysisCategory.marketStructure:
        return '📈';
      case AnalysisCategory.liquidity:
        return '💧';
      case AnalysisCategory.smartMoney:
        return '📦';
      case AnalysisCategory.supplyDemand:
        return '🟢';
      case AnalysisCategory.premiumDiscount:
        return '⚖️';
    }
  }
}

enum AnalysisType {
  // Market Structure
  bos,
  choch,

  // Liquidity
  bsl,
  ssl,
  liquiditySweep,

  // Smart Money Concepts
  bullishOrderBlock,
  bearishOrderBlock,
  bullishFvg,
  bearishFvg,

  // Supply / Demand
  supportZone,
  resistanceZone,
  supplyZone,
  demandZone,

  // Premium / Discount
  premiumZone,
  discountZone,
  equilibrium;

  AnalysisCategory get category {
    switch (this) {
      case AnalysisType.bos:
      case AnalysisType.choch:
        return AnalysisCategory.marketStructure;
      case AnalysisType.bsl:
      case AnalysisType.ssl:
      case AnalysisType.liquiditySweep:
        return AnalysisCategory.liquidity;
      case AnalysisType.bullishOrderBlock:
      case AnalysisType.bearishOrderBlock:
      case AnalysisType.bullishFvg:
      case AnalysisType.bearishFvg:
        return AnalysisCategory.smartMoney;
      case AnalysisType.supportZone:
      case AnalysisType.resistanceZone:
      case AnalysisType.supplyZone:
      case AnalysisType.demandZone:
        return AnalysisCategory.supplyDemand;
      case AnalysisType.premiumZone:
      case AnalysisType.discountZone:
      case AnalysisType.equilibrium:
        return AnalysisCategory.premiumDiscount;
    }
  }

  String get displayName {
    switch (this) {
      case AnalysisType.bos:
        return 'Break of Structure (BOS)';
      case AnalysisType.choch:
        return 'Change of Character (CHoCH)';
      case AnalysisType.bsl:
        return 'Buy Side Liquidity (BSL)';
      case AnalysisType.ssl:
        return 'Sell Side Liquidity (SSL)';
      case AnalysisType.liquiditySweep:
        return 'Liquidity Sweep';
      case AnalysisType.bullishOrderBlock:
        return 'Bullish Order Block';
      case AnalysisType.bearishOrderBlock:
        return 'Bearish Order Block';
      case AnalysisType.bullishFvg:
        return 'Bullish Fair Value Gap';
      case AnalysisType.bearishFvg:
        return 'Bearish Fair Value Gap';
      case AnalysisType.supportZone:
        return 'Support Zone';
      case AnalysisType.resistanceZone:
        return 'Resistance Zone';
      case AnalysisType.supplyZone:
        return 'Supply Zone';
      case AnalysisType.demandZone:
        return 'Demand Zone';
      case AnalysisType.premiumZone:
        return 'Premium Zone';
      case AnalysisType.discountZone:
        return 'Discount Zone';
      case AnalysisType.equilibrium:
        return 'Equilibrium';
    }
  }

  String get shortLabel {
    switch (this) {
      case AnalysisType.bos:
        return 'BOS';
      case AnalysisType.choch:
        return 'CHoCH';
      case AnalysisType.bsl:
        return 'BSL';
      case AnalysisType.ssl:
        return 'SSL';
      case AnalysisType.liquiditySweep:
        return 'Sweep';
      case AnalysisType.bullishOrderBlock:
        return 'OB';
      case AnalysisType.bearishOrderBlock:
        return 'OB';
      case AnalysisType.bullishFvg:
        return 'FVG';
      case AnalysisType.bearishFvg:
        return 'FVG';
      case AnalysisType.supportZone:
        return 'Support';
      case AnalysisType.resistanceZone:
        return 'Resistance';
      case AnalysisType.supplyZone:
        return 'Supply';
      case AnalysisType.demandZone:
        return 'Demand';
      case AnalysisType.premiumZone:
        return 'Premium';
      case AnalysisType.discountZone:
        return 'Discount';
      case AnalysisType.equilibrium:
        return 'EQ';
    }
  }

  String get iconSymbol {
    switch (this) {
      case AnalysisType.bos:
        return '📈';
      case AnalysisType.choch:
        return '📉';
      case AnalysisType.bsl:
      case AnalysisType.ssl:
      case AnalysisType.liquiditySweep:
        return '💧';
      case AnalysisType.bullishOrderBlock:
      case AnalysisType.bearishOrderBlock:
        return '📦';
      case AnalysisType.bullishFvg:
      case AnalysisType.bearishFvg:
        return '🟩';
      case AnalysisType.supportZone:
      case AnalysisType.demandZone:
        return '🟢';
      case AnalysisType.resistanceZone:
      case AnalysisType.supplyZone:
        return '🔴';
      case AnalysisType.premiumZone:
        return '🔴';
      case AnalysisType.discountZone:
        return '🟢';
      case AnalysisType.equilibrium:
        return '⚖️';
    }
  }

  DrawingTool get underlyingTool {
    switch (this) {
      case AnalysisType.bos:
      case AnalysisType.choch:
      case AnalysisType.bsl:
      case AnalysisType.ssl:
      case AnalysisType.liquiditySweep:
      case AnalysisType.equilibrium:
        return DrawingTool.horizontalLine;
      case AnalysisType.bullishOrderBlock:
      case AnalysisType.bearishOrderBlock:
      case AnalysisType.bullishFvg:
      case AnalysisType.bearishFvg:
      case AnalysisType.supportZone:
      case AnalysisType.resistanceZone:
      case AnalysisType.supplyZone:
      case AnalysisType.demandZone:
      case AnalysisType.premiumZone:
      case AnalysisType.discountZone:
        return DrawingTool.rectangle;
    }
  }

  int get anchorCount => underlyingTool.anchorCount;

  /// Default ARGB primary line / border color.
  int get defaultColorValue {
    switch (this) {
      case AnalysisType.bullishOrderBlock:
      case AnalysisType.supportZone:
      case AnalysisType.demandZone:
      case AnalysisType.discountZone:
        return 0xFF10B981; // Green
      case AnalysisType.bearishOrderBlock:
      case AnalysisType.resistanceZone:
      case AnalysisType.supplyZone:
      case AnalysisType.premiumZone:
        return 0xFFEF4444; // Red
      case AnalysisType.bullishFvg:
        return 0xFF06B6D4; // Cyan
      case AnalysisType.bearishFvg:
        return 0xFFF97316; // Orange
      case AnalysisType.bsl:
        return 0xFF3B82F6; // Blue
      case AnalysisType.ssl:
        return 0xFFA855F7; // Purple
      case AnalysisType.bos:
        return 0xFF3B82F6; // Blue
      case AnalysisType.choch:
        return 0xFFEC4899; // Pink
      case AnalysisType.liquiditySweep:
        return 0xFFEAB308; // Yellow / Gold
      case AnalysisType.equilibrium:
        return 0xFF8B5CF6; // Violet
    }
  }

  Color get defaultColor => Color(defaultColorValue);

  /// Default fill opacity for zone rectangle tools.
  double get defaultFillOpacity {
    switch (this) {
      case AnalysisType.bullishOrderBlock:
      case AnalysisType.bearishOrderBlock:
      case AnalysisType.bullishFvg:
      case AnalysisType.bearishFvg:
        return 0.25;
      case AnalysisType.supportZone:
      case AnalysisType.resistanceZone:
      case AnalysisType.supplyZone:
      case AnalysisType.demandZone:
        return 0.20;
      case AnalysisType.premiumZone:
      case AnalysisType.discountZone:
        return 0.15;
      default:
        return 0.20;
    }
  }

  String? get direction {
    switch (this) {
      case AnalysisType.bullishOrderBlock:
      case AnalysisType.bullishFvg:
      case AnalysisType.demandZone:
      case AnalysisType.discountZone:
        return 'bullish';
      case AnalysisType.bearishOrderBlock:
      case AnalysisType.bearishFvg:
      case AnalysisType.supplyZone:
      case AnalysisType.premiumZone:
        return 'bearish';
      default:
        return 'neutral';
    }
  }

  static AnalysisType fromId(String id) {
    return AnalysisType.values.firstWhere(
      (t) => t.name == id,
      orElse: () => AnalysisType.bullishOrderBlock,
    );
  }
}
