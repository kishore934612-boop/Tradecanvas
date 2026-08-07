import 'dart:math' as math;
import 'package:flutter/material.dart' show IconData;
import 'package:app/models/asset_metadata.dart';

enum MarketType { crypto }

extension MarketTypeLabel on MarketType {
  String get label {
    switch (this) {
      case MarketType.crypto:
        return 'Crypto';
    }
  }

  String get id {
    switch (this) {
      case MarketType.crypto:
        return 'crypto';
    }
  }
}

MarketType? marketTypeFromId(String id) {
  for (final t in MarketType.values) {
    if (t.id == id) return t;
  }
  return null;
}

/// The specific trading style for a given market.
enum TradingType { spot, futures }

extension TradingTypeLabel on TradingType {
  String get label {
    switch (this) {
      case TradingType.spot:
        return 'Spot';
      case TradingType.futures:
        return 'Futures';
    }
  }

  String get id {
    switch (this) {
      case TradingType.spot:
        return 'spot';
      case TradingType.futures:
        return 'futures';
    }
  }
}

TradingType tradingTypeFromId(String id) {
  for (final t in TradingType.values) {
    if (t.id == id) return t;
  }
  return TradingType.spot;
}

/// Returns the list of trading types available for a given market.
List<TradingType> tradingTypesFor(MarketType market) {
  switch (market) {
    case MarketType.crypto:
      return [TradingType.spot, TradingType.futures];
  }
}

/// Returns the default trading type for a given market.
TradingType defaultTradingType(MarketType market) {
  switch (market) {
    case MarketType.crypto:
      return TradingType.spot;
  }
}

/// Configuration rules that govern how each market+style combination behaves.
class MarketConfig {
  final MarketType marketType;
  final bool leverageAllowed;
  final bool shortSellingAllowed;
  final bool liquidationExists;
  final bool marginRequired;
  final bool fundingFeesExist;
  final bool lotSizeUsed;
  final double defaultLeverage;
  final double maxLeverage;
  final double makerFee;   // per-side fee rate (fraction, e.g. 0.001 = 0.1%)
  final double takerFee;   // per-side fee rate

  const MarketConfig({
    required this.marketType,
    this.leverageAllowed = false,
    this.shortSellingAllowed = false,
    this.liquidationExists = false,
    this.marginRequired = false,
    this.fundingFeesExist = false,
    this.lotSizeUsed = false,
    this.defaultLeverage = 1.0,
    this.maxLeverage = 1.0,
    this.makerFee = 0.0,
    this.takerFee = 0.0,
  });

  // Rules Engine Getters
  bool get longTradingEnabled => true;
  bool get shortTradingEnabled => shortSellingAllowed;
  bool get leverageEnabled => leverageAllowed;
  bool get marginEnabled => marginRequired;
  bool get liquidationEnabled => liquidationExists;
  bool get fundingFeeEnabled => fundingFeesExist;
  bool get lotSizeEnabled => lotSizeUsed;
  bool get brokerageEnabled => false;
  bool get pipCalculationEnabled => false;
  double get lotBaseUnits => 1.0;
  double get spreadPips => 0.0;
  double get commissionPerLot => 0.0;
  double get brokerageFee => 0.0;

  /// Returns the appropriate fee rate for a market order (taker) or limit (maker).
  double feeForOrder(bool isMarketOrder) =>
      isMarketOrder ? takerFee : makerFee;

  /// Factory that returns rules based on the market and trading style.
  static MarketConfig get(MarketType market, TradingType style) {
    switch (market) {
      case MarketType.crypto:
        if (style == TradingType.futures) {
          return const MarketConfig(
            marketType: MarketType.crypto,
            leverageAllowed: true,
            shortSellingAllowed: true,
            liquidationExists: true,
            marginRequired: true,
            fundingFeesExist: true,
            defaultLeverage: 10.0,
            maxLeverage: 20.0,
            makerFee: 0.0002, // Typical crypto futures fees
            takerFee: 0.0005,
          );
        }
        // Crypto Spot
        return const MarketConfig(
          marketType: MarketType.crypto,
          leverageAllowed: false,
          shortSellingAllowed: false,
          liquidationExists: false,
          marginRequired: false,
          defaultLeverage: 1.0,
          maxLeverage: 1.0,
          makerFee: 0.001, // Typical crypto spot fees (0.1%)
          takerFee: 0.001,
        );
    }
  }
}

class Asset {
  final String symbol;
  final String name;
  final MarketType type;
  final double basePrice;
  final double volatility;
  final double maxLeverage;
  final String region; // 'Global'

  const Asset({
    required this.symbol,
    required this.name,
    required this.type,
    required this.basePrice,
    required this.volatility,
    this.maxLeverage = 20.0,
    this.region = 'Global',
  });

  String get typeString => type.id;

  double get pipSize => 0.01;

  // ── Rich metadata access ──────────────────────────

  /// Full AssetMetadata for this asset (null if not registered).

  /// Full AssetMetadata — falls back to derived values if unregistered.
  AssetMetadata get metadata => getAssetMetadataOrDefault(symbol);

  /// Exchange name (e.g. 'Binance').
  String get exchange => metadata.exchange;

  /// Native market currency (e.g. 'USD').
  String get marketCurrency => metadata.marketCurrency;

  /// Account currency for P&L calculations.
  String get accountCurrency => metadata.accountCurrency;

  /// Whether this asset is priced in a non-USD currency.
  bool get isNonUsdMarket => false;

  /// Currency symbol for display (e.g. '\$').
  String get currencySymbol => metadata.currencySymbol;

  /// Decimal precision for price display.
  int get decimalPrecision => metadata.decimalPrecision;

  /// Minimum price movement.
  double get tickSize => metadata.tickSize;

  /// Standard lot size.
  double get lotSize => metadata.lotSize;

  /// Minimum order quantity.
  double get minOrderSize => metadata.minOrderSize;

  /// Maximum order quantity.
  double get maxOrderSize => metadata.maxOrderSize;

  /// Trading session schedule.
  TradingSession get session => metadata.session;

  /// Icon for this market type.
  IconData get marketIcon => metadata.marketIcon;

  /// Format a price according to this asset's decimal precision.
  String formatPrice(double price) => metadata.formatPrice(price);

  /// Format a quantity (lots or units) for display.
  String formatQty(double qty) => metadata.formatQty(qty);

  /// Whether this asset uses lot-based sizing.
  bool get isLotBased => false;
}

const double startingBalance = 100000.0;

const List<Asset> assets = [
  // ---------------- Crypto ----------------
  Asset(symbol: 'BTC', name: 'Bitcoin', type: MarketType.crypto, basePrice: 67340.0, volatility: 0.025, maxLeverage: 20),
  Asset(symbol: 'ETH', name: 'Ethereum', type: MarketType.crypto, basePrice: 3820.0, volatility: 0.03, maxLeverage: 20),
  Asset(symbol: 'SOL', name: 'Solana', type: MarketType.crypto, basePrice: 178.0, volatility: 0.04, maxLeverage: 20),
  Asset(symbol: 'BNB', name: 'Binance Coin', type: MarketType.crypto, basePrice: 612.0, volatility: 0.028, maxLeverage: 20),
  Asset(symbol: 'XRP', name: 'Ripple', type: MarketType.crypto, basePrice: 0.62, volatility: 0.035, maxLeverage: 20),
  Asset(symbol: 'DOGE', name: 'Dogecoin', type: MarketType.crypto, basePrice: 0.185, volatility: 0.05, maxLeverage: 20),
  Asset(symbol: 'ADA', name: 'Cardano', type: MarketType.crypto, basePrice: 0.48, volatility: 0.038, maxLeverage: 20),
  Asset(symbol: 'AVAX', name: 'Avalanche', type: MarketType.crypto, basePrice: 39.5, volatility: 0.045, maxLeverage: 20),
];

Asset? getAssetBySymbol(String symbol) {
  for (var asset in assets) {
    if (asset.symbol == symbol) return asset;
  }
  return null;
}

List<Asset> assetsForType(MarketType type) => assets.where((a) => a.type == type).toList();

double simulatePrice(Asset asset, double seed) {
  final noise = (math.sin(seed * 127.1 + asset.basePrice) * 0.5 + 0.5) * 2 - 1;
  return asset.basePrice * (1 + noise * asset.volatility);
}

List<double> generateSparkline(Asset asset, {int points = 12}) {
  final List<double> result = [];
  double price = asset.basePrice;
  final now = DateTime.now().millisecondsSinceEpoch;
  for (int i = 0; i < points; i++) {
    final seed = (now / 60000 - points + i) * 0.01;
    final noise = (math.sin(seed * 127.1 + asset.basePrice + i * 17.3) * 0.5 + 0.5) * 2 - 1;
    price = price * (1 + noise * asset.volatility * 0.4);
    result.add(price);
  }
  return result;
}
