/// Deterministic OHLC execution policy, independent of UI and account state.
/// No tick path is inferred: stops win ambiguous bars; a pending intrabar entry
/// cannot claim a target touched before entry. This is a paper simulation only.
library;

import 'dart:math' as math;
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/models/replay_order.dart';

class ReplayExecution {
  final double feePercent;
  final double slippagePercent;

  const ReplayExecution({this.feePercent = 0.075, this.slippagePercent = 0.05});

  bool get isValid => feePercent.isFinite && feePercent >= 0 && feePercent <= 5 &&
      slippagePercent.isFinite && slippagePercent >= 0 && slippagePercent <= 5;

  double marketFill(double price, OrderSide side) =>
      price * (1 + (side == OrderSide.buy ? 1 : -1) * slippagePercent / 100);

  double fee(double price, double quantity) => price * quantity * feePercent / 100;

  /// Orders are eligible only on bars AFTER submission (enforced by caller).
  ({double price, bool atOpen})? entry(ReplayOrder order, CandleData bar) {
    if (order.type == OrderType.market) {
      return (price: marketFill(bar.open, order.side), atOpen: true);
    }
    final buy = order.isLong;
    final limit = order.type == OrderType.limit;
    final triggeredAtOpen = limit
        ? (buy ? bar.open <= order.price : bar.open >= order.price)
        : (buy ? bar.open >= order.price : bar.open <= order.price);
    final touched = limit
        ? (buy ? bar.low <= order.price : bar.high >= order.price)
        : (buy ? bar.high >= order.price : bar.low <= order.price);
    if (!triggeredAtOpen && !touched) return null;
    final price = triggeredAtOpen ? bar.open : order.price;
    // Limit entries never receive a price worse than their limit.
    return (price: limit ? price : marketFill(price, order.side), atOpen: triggeredAtOpen);
  }

  ({double price, String reason})? exit(ReplayOrder order, CandleData bar,
      {bool enteredIntrabar = false}) {
    final sl = order.stopLossPrice;
    final tp = order.takeProfitPrice;
    final exitSide = order.isLong ? OrderSide.sell : OrderSide.buy;
    // Opening gaps have known chronology; respect an opening target before a
    // later stop touch. For intrabar entries, opening prices predate the entry.
    if (!enteredIntrabar) {
      if (sl != null && (order.isLong ? bar.open <= sl : bar.open >= sl)) {
        return (price: marketFill(bar.open, exitSide), reason: 'sl_hit');
      }
      if (tp != null && (order.isLong ? bar.open >= tp : bar.open <= tp)) {
        return (price: tp, reason: 'tp_hit');
      }
    }
    if (sl != null && (order.isLong ? bar.low <= sl : bar.high >= sl)) {
      return (price: marketFill(sl, exitSide), reason: 'sl_hit');
    }
    if (tp != null) {
      // A close beyond target proves a post-entry target crossing. Otherwise,
      // defer favorable intrabar exits when OHLC cannot establish chronology.
      final touched = enteredIntrabar
          ? (order.isLong ? bar.close >= tp : bar.close <= tp)
          : (order.isLong ? bar.high >= tp : bar.low <= tp);
      if (touched) return (price: tp, reason: 'tp_hit');
    }
    return null;
  }

  double stopRisk(ReplayOrder order, double fillPrice) {
    final stopFill = marketFill(order.stopLossPrice!,
        order.isLong ? OrderSide.sell : OrderSide.buy);
    return math.max(0, (order.isLong ? fillPrice - stopFill : stopFill - fillPrice)) *
        order.quantity + fee(fillPrice, order.quantity) + fee(stopFill, order.quantity);
  }
}
