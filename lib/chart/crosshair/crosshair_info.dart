/// Crosshair Info model and data calculator for real-time cursor statistics.
library;

import 'dart:math' as math;
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/models/smc_type.dart';

class CrosshairFieldConfig {
  final bool showDateTime;
  final bool showOhlcv;
  final bool showChangePercent;
  final bool showBodyPercent;
  final bool showWickPercent;
  final bool showAtr;
  final bool showRsi;
  final bool showMacd;
  final bool showSpread;
  final bool showVwap;
  final bool showBarIndex;
  final bool showSmcLevels;

  const CrosshairFieldConfig({
    this.showDateTime = true,
    this.showOhlcv = true,
    this.showChangePercent = true,
    this.showBodyPercent = true,
    this.showWickPercent = true,
    this.showAtr = true,
    this.showRsi = true,
    this.showMacd = true,
    this.showSpread = true,
    this.showVwap = true,
    this.showBarIndex = true,
    this.showSmcLevels = true,
  });
}

class CrosshairInfoData {
  final int candleIndex;
  final String dateStr;
  final String timeStr;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double changePercent;
  final double bodyPercent;
  final double upperWickPercent;
  final double lowerWickPercent;
  final double spread;
  final double? atr;
  final double? rsi;
  final double? macdHist;
  final double? macdSignal;
  final double? vwap;

  // Optional SMC metrics
  final double? nearestSupport;
  final double? nearestResistance;
  final String? nearestOrderBlock;
  final String? nearestFvg;
  final String? nearestBos;
  final String? nearestChoch;

  const CrosshairInfoData({
    required this.candleIndex,
    required this.dateStr,
    required this.timeStr,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.changePercent,
    required this.bodyPercent,
    required this.upperWickPercent,
    required this.lowerWickPercent,
    required this.spread,
    this.atr,
    this.rsi,
    this.macdHist,
    this.macdSignal,
    this.vwap,
    this.nearestSupport,
    this.nearestResistance,
    this.nearestOrderBlock,
    this.nearestFvg,
    this.nearestBos,
    this.nearestChoch,
  });

  static CrosshairInfoData fromCandle({
    required int index,
    required CandleData candle,
    ChartIndicators? indicators,
    List<SmcStructure>? smcStructures,
  }) {
    final date = DateTime.fromMillisecondsSinceEpoch(candle.timestamp);
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    final open = candle.open;
    final high = candle.high;
    final low = candle.low;
    final close = candle.close;
    final volume = candle.volume;

    final changePercent = open != 0 ? ((close - open) / open) * 100 : 0.0;
    final range = high - low;
    final bodyPercent = range > 0 ? ((close - open).abs() / range) * 100 : 0.0;
    final maxBody = math.max(open, close);
    final minBody = math.min(open, close);
    final upperWickPercent = range > 0 ? ((high - maxBody) / range) * 100 : 0.0;
    final lowerWickPercent = range > 0 ? ((minBody - low) / range) * 100 : 0.0;
    final spread = range;

    double? atr;
    double? rsi;
    double? macdHist;
    double? macdSignal;
    double? vwap;

    if (indicators != null) {
      if (index >= 0 && index < indicators.atr.length) atr = indicators.atr[index];
      if (index >= 0 && index < indicators.rsi.length) rsi = indicators.rsi[index];
      if (index >= 0 && index < indicators.macdHist.length) macdHist = indicators.macdHist[index];
      if (index >= 0 && index < indicators.macdSignal.length) macdSignal = indicators.macdSignal[index];
      if (index >= 0 && index < indicators.vwap.length) vwap = indicators.vwap[index];
    }

    double? nSupport;
    double? nResistance;
    String? nOb;
    String? nFvg;
    String? nBos;
    String? nChoch;

    if (smcStructures != null && smcStructures.isNotEmpty) {
      for (final smc in smcStructures) {
        if (smc.type == SmcType.orderBlock) {
          nOb = '${smc.price.toStringAsFixed(2)} - ${smc.secondaryPrice.toStringAsFixed(2)}';
        } else if (smc.type == SmcType.fvg) {
          nFvg = '${smc.price.toStringAsFixed(2)} - ${smc.secondaryPrice.toStringAsFixed(2)}';
        } else if (smc.type == SmcType.bos) {
          nBos = '${smc.price.toStringAsFixed(2)} (${smc.isBullish ? "Bullish" : "Bearish"})';
        } else if (smc.type == SmcType.choch) {
          nChoch = '${smc.price.toStringAsFixed(2)} (${smc.isBullish ? "Bullish" : "Bearish"})';
        }
        if (smc.isBullish) {
          if (nSupport == null || smc.price > nSupport) nSupport = smc.price;
        } else {
          if (nResistance == null || smc.price < nResistance) nResistance = smc.price;
        }
      }
    }

    return CrosshairInfoData(
      candleIndex: index,
      dateStr: dateStr,
      timeStr: timeStr,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
      changePercent: changePercent,
      bodyPercent: bodyPercent,
      upperWickPercent: upperWickPercent,
      lowerWickPercent: lowerWickPercent,
      spread: spread,
      atr: atr,
      rsi: rsi,
      macdHist: macdHist,
      macdSignal: macdSignal,
      vwap: vwap,
      nearestSupport: nSupport,
      nearestResistance: nResistance,
      nearestOrderBlock: nOb,
      nearestFvg: nFvg,
      nearestBos: nBos,
      nearestChoch: nChoch,
    );
  }
}
