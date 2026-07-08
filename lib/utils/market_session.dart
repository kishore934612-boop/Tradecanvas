import 'package:app/constants/markets.dart';
import 'package:app/domain/repositories/market_repository.dart' show MarketStatus;

/// Returns the current market status for an asset.
MarketStatus getMarketStatus(Asset asset) {
  return MarketStatus.open;
}

/// Whether live candle updates should be applied for this asset right now.
bool isMarketLive(Asset asset) => true;

/// Rounds down a timestamp in milliseconds to the start of its candle interval.
int candleBoundary(int timestampMs, int intervalMs) {
  if (intervalMs <= 0) return timestampMs;
  return timestampMs - (timestampMs % intervalMs);
}
