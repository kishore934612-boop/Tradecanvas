/// AnalysisToolDefinition registry organizing tools by category.
library;

import 'package:app/analysis_tools/models/analysis_type.dart';

class AnalysisToolDefinition {
  final AnalysisType type;
  final String title;
  final String description;

  const AnalysisToolDefinition({
    required this.type,
    required this.title,
    required this.description,
  });

  static Map<AnalysisCategory, List<AnalysisToolDefinition>> get categorizedTools => {
        AnalysisCategory.marketStructure: const [
          AnalysisToolDefinition(
            type: AnalysisType.bos,
            title: 'Break of Structure (BOS)',
            description: 'Identifies trend continuation key level breaks.',
          ),
          AnalysisToolDefinition(
            type: AnalysisType.choch,
            title: 'Change of Character (CHoCH)',
            description: 'Identifies trend reversal initial shift levels.',
          ),
        ],
        AnalysisCategory.liquidity: const [
          AnalysisToolDefinition(
            type: AnalysisType.bsl,
            title: 'Buy Side Liquidity (BSL)',
            description: 'Highlights buy stop liquidity pools above highs.',
          ),
          AnalysisToolDefinition(
            type: AnalysisType.ssl,
            title: 'Sell Side Liquidity (SSL)',
            description: 'Highlights sell stop liquidity pools below lows.',
          ),
          AnalysisToolDefinition(
            type: AnalysisType.liquiditySweep,
            title: 'Liquidity Sweep',
            description: 'Marks fakeouts and stop hunt liquidity sweeps.',
          ),
        ],
        AnalysisCategory.smartMoney: const [
          AnalysisToolDefinition(
            type: AnalysisType.bullishOrderBlock,
            title: 'Bullish Order Block',
            description: 'Pre-expansion institutional buy order zone.',
          ),
          AnalysisToolDefinition(
            type: AnalysisType.bearishOrderBlock,
            title: 'Bearish Order Block',
            description: 'Pre-expansion institutional sell order zone.',
          ),
          AnalysisToolDefinition(
            type: AnalysisType.bullishFvg,
            title: 'Bullish Fair Value Gap',
            description: '3-candle imbalance buy efficiency gap.',
          ),
          AnalysisToolDefinition(
            type: AnalysisType.bearishFvg,
            title: 'Bearish Fair Value Gap',
            description: '3-candle imbalance sell efficiency gap.',
          ),
        ],
        AnalysisCategory.supplyDemand: const [
          AnalysisToolDefinition(
            type: AnalysisType.supportZone,
            title: 'Support Zone',
            description: 'Key buying interest horizontal range.',
          ),
          AnalysisToolDefinition(
            type: AnalysisType.resistanceZone,
            title: 'Resistance Zone',
            description: 'Key selling interest horizontal range.',
          ),
          AnalysisToolDefinition(
            type: AnalysisType.supplyZone,
            title: 'Supply Zone',
            description: 'Institutional distribution selling zone.',
          ),
          AnalysisToolDefinition(
            type: AnalysisType.demandZone,
            title: 'Demand Zone',
            description: 'Institutional accumulation buying zone.',
          ),
        ],
        AnalysisCategory.premiumDiscount: const [
          AnalysisToolDefinition(
            type: AnalysisType.premiumZone,
            title: 'Premium Zone',
            description: 'Upper 50% price range (expensive for longs).',
          ),
          AnalysisToolDefinition(
            type: AnalysisType.discountZone,
            title: 'Discount Zone',
            description: 'Lower 50% price range (cheap for buys).',
          ),
          AnalysisToolDefinition(
            type: AnalysisType.equilibrium,
            title: 'Equilibrium',
            description: 'Midpoint 50% fair price value level.',
          ),
        ],
      };
}
