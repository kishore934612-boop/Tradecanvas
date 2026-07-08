/// Asset Metadata — Phase 9
///
/// Rich per-asset metadata that eliminates hardcoded market-specific
/// logic scattered throughout the codebase.
///
/// Every asset self-describes:
///   • Display formatting (decimal precision, currency symbol)
///   • Trading rules (lot size, tick size, min/max order)
///   • Session hours (open/close times, timezone, trading days)
///   • Icon / exchange information
library;

import 'package:flutter/material.dart';
import 'package:app/constants/markets.dart';

// ============================================================
// TRADING SESSION
// ============================================================

/// A weekly trading schedule.
class TradingSession {
  /// Name of the session (e.g. 'NYSE', 'NSE', 'Forex', '24/7')
  final String name;

  /// IANA timezone identifier (e.g. 'America/New_York', 'Asia/Kolkata')
  final String timezone;

  /// UTC offset in hours (used for lightweight calculations without tz package)
  final double utcOffsetHours;

  /// Opening time (local to the exchange).
  final TimeOfDay openTime;

  /// Closing time (local to the exchange).
  final TimeOfDay closeTime;

  /// ISO weekdays that are trading days (1=Mon, 7=Sun).
  final List<int> tradingDays;

  /// True if this market trades continuously (e.g. crypto).
  final bool is24h;

  /// True if pre-market / after-hours trading is available.
  final bool hasExtendedHours;

  /// Pre-market start (local time), null if none.
  final TimeOfDay? preMarketOpen;

  /// After-hours end (local time), null if none.
  final TimeOfDay? afterHoursClose;

  const TradingSession({
    required this.name,
    required this.timezone,
    required this.utcOffsetHours,
    required this.openTime,
    required this.closeTime,
    required this.tradingDays,
    this.is24h = false,
    this.hasExtendedHours = false,
    this.preMarketOpen,
    this.afterHoursClose,
  });

  // ── Pre-defined sessions ──────────────────────────────────

  /// Crypto: 24/7, no timezone
  static const TradingSession crypto = TradingSession(
    name: '24/7',
    timezone: 'UTC',
    utcOffsetHours: 0,
    openTime: TimeOfDay(hour: 0, minute: 0),
    closeTime: TimeOfDay(hour: 23, minute: 59),
    tradingDays: [1, 2, 3, 4, 5, 6, 7],
    is24h: true,
  );

  /// NYSE / NASDAQ: 09:30–16:00 ET (UTC-4 EDT / UTC-5 EST)
  /// Pre-market: 04:00 ET, After-hours: 20:00 ET
  static const TradingSession nyse = TradingSession(
    name: 'NYSE/NASDAQ',
    timezone: 'America/New_York',
    utcOffsetHours: -4, // EDT (summer); -5 in winter — approximation
    openTime: TimeOfDay(hour: 9, minute: 30),
    closeTime: TimeOfDay(hour: 16, minute: 0),
    tradingDays: [1, 2, 3, 4, 5],
    hasExtendedHours: true,
    preMarketOpen: TimeOfDay(hour: 4, minute: 0),
    afterHoursClose: TimeOfDay(hour: 20, minute: 0),
  );

  /// NSE / BSE: 09:15–15:30 IST (UTC+5:30)
  static const TradingSession nse = TradingSession(
    name: 'NSE/BSE',
    timezone: 'Asia/Kolkata',
    utcOffsetHours: 5.5,
    openTime: TimeOfDay(hour: 9, minute: 15),
    closeTime: TimeOfDay(hour: 15, minute: 30),
    tradingDays: [1, 2, 3, 4, 5],
    hasExtendedHours: false,
    preMarketOpen: TimeOfDay(hour: 9, minute: 0),
  );

  /// Forex: 24/5 (Mon–Fri, UTC)
  static const TradingSession forex = TradingSession(
    name: 'Forex 24/5',
    timezone: 'UTC',
    utcOffsetHours: 0,
    openTime: TimeOfDay(hour: 0, minute: 0),
    closeTime: TimeOfDay(hour: 23, minute: 59),
    tradingDays: [1, 2, 3, 4, 5],
    is24h: false, // closed weekends
  );

  // ── Helpers ───────────────────────────────────────────────

  /// Whether [weekday] (1=Mon, 7=Sun) is a trading day for this session.
  bool isTradingDay(int weekday) => is24h || tradingDays.contains(weekday);

  /// Convert open time to total minutes past midnight.
  int get openMinutes => openTime.hour * 60 + openTime.minute;

  /// Convert close time to total minutes past midnight.
  int get closeMinutes => closeTime.hour * 60 + closeTime.minute;

  @override
  String toString() => 'TradingSession($name, $timezone, ${openTime.format24()}–${closeTime.format24()})';
}

extension _TimeOfDayFormat on TimeOfDay {
  String format24() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

// ============================================================
// ASSET METADATA
// ============================================================

/// Full metadata for one tradable instrument.
/// Eliminates all hardcoded `if asset.type == forex` logic in UI/engine.
class AssetMetadata {
  /// Symbol as used in the app (e.g. 'BTC', 'AAPL', 'EUR/USD')
  final String symbol;

  /// Full human-readable name
  final String name;

  /// Market category
  final MarketType marketType;

  /// Exchange that lists this instrument
  final String exchange;

  /// Native quote currency (what prices are shown in)
  final String marketCurrency;

  /// Account currency for P&L (always 'USD' for now)
  final String accountCurrency;

  /// Number of decimal places to display prices with
  final int decimalPrecision;

  /// Minimum price movement (e.g. 0.01 for stocks, 0.0001 for forex majors)
  final double tickSize;

  /// Size of one standard lot (1 for crypto/stocks, 100000 for forex)
  final double lotSize;

  /// Minimum order quantity (in lots or units)
  final double minOrderSize;

  /// Maximum order quantity
  final double maxOrderSize;

  /// Maximum leverage available for this instrument
  final double maxLeverage;

  /// Default leverage suggestion
  final double defaultLeverage;

  /// Trading session for this instrument
  final TradingSession session;

  /// Whether this asset uses lot-based sizing (forex only)
  bool get isLotBased => lotSize > 1;

  /// Pip size (relevant for forex; for others returns tickSize)
  double get pipSize => tickSize;

  /// Format a price value according to this asset's precision
  String formatPrice(double price) {
    final sign = price < 0 ? '-' : '';
    final str = price.abs().toString();
    final parts = str.split('.');
    String fract = parts.length > 1 ? parts[1] : '';
    if (fract == '0') {
      fract = '00';
    } else if (fract.length == 1) {
      fract = '${fract}0';
    }
    return '$sign${parts[0]}.$fract';
  }

  /// Format a quantity value (lots or units)
  String formatQty(double qty) {
    if (isLotBased) {
      // Show lots with 2 decimal places
      return qty.toStringAsFixed(2);
    }
    // Crypto: up to 4 decimals; stocks: whole numbers
    if (marketType == MarketType.crypto) {
      return qty >= 1 ? qty.toStringAsFixed(2) : qty.toStringAsFixed(4);
    }
    return qty.toStringAsFixed(2);
  }

  /// Currency symbol for display (e.g. '$', '₹')
  String get currencySymbol {
    switch (marketCurrency) {
      case 'USD': return '\$';
      case 'INR': return '₹';
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'JPY': return '¥';
      default: return marketCurrency;
    }
  }

  /// Icon data for this market type
  IconData get marketIcon {
    switch (marketType) {
      case MarketType.crypto:  return Icons.currency_bitcoin;
    }
  }

  const AssetMetadata({
    required this.symbol,
    required this.name,
    required this.marketType,
    required this.exchange,
    required this.marketCurrency,
    required this.accountCurrency,
    required this.decimalPrecision,
    required this.tickSize,
    required this.lotSize,
    required this.minOrderSize,
    required this.maxOrderSize,
    required this.maxLeverage,
    required this.defaultLeverage,
    required this.session,
  });

  @override
  String toString() => 'AssetMetadata($symbol on $exchange, $marketCurrency, prec=$decimalPrecision)';
}

// ============================================================
// ASSET METADATA REGISTRY
// ============================================================

/// Complete metadata for all supported instruments.
/// Single source of truth — replaces all hardcoded checks.
const Map<String, AssetMetadata> assetMetadataRegistry = {
  // ── Crypto (Binance) ──────────────────────────────────────
  'BTC': AssetMetadata(
    symbol: 'BTC', name: 'Bitcoin', marketType: MarketType.crypto,
    exchange: 'Binance', marketCurrency: 'USD', accountCurrency: 'USD',
    decimalPrecision: 2, tickSize: 0.01, lotSize: 1,
    minOrderSize: 0.00001, maxOrderSize: 100, maxLeverage: 20, defaultLeverage: 1,
    session: TradingSession.crypto,
  ),
  'ETH': AssetMetadata(
    symbol: 'ETH', name: 'Ethereum', marketType: MarketType.crypto,
    exchange: 'Binance', marketCurrency: 'USD', accountCurrency: 'USD',
    decimalPrecision: 2, tickSize: 0.01, lotSize: 1,
    minOrderSize: 0.0001, maxOrderSize: 1000, maxLeverage: 20, defaultLeverage: 1,
    session: TradingSession.crypto,
  ),
  'SOL': AssetMetadata(
    symbol: 'SOL', name: 'Solana', marketType: MarketType.crypto,
    exchange: 'Binance', marketCurrency: 'USD', accountCurrency: 'USD',
    decimalPrecision: 2, tickSize: 0.001, lotSize: 1,
    minOrderSize: 0.001, maxOrderSize: 10000, maxLeverage: 20, defaultLeverage: 1,
    session: TradingSession.crypto,
  ),
  'BNB': AssetMetadata(
    symbol: 'BNB', name: 'Binance Coin', marketType: MarketType.crypto,
    exchange: 'Binance', marketCurrency: 'USD', accountCurrency: 'USD',
    decimalPrecision: 2, tickSize: 0.001, lotSize: 1,
    minOrderSize: 0.001, maxOrderSize: 10000, maxLeverage: 20, defaultLeverage: 1,
    session: TradingSession.crypto,
  ),
  'XRP': AssetMetadata(
    symbol: 'XRP', name: 'Ripple', marketType: MarketType.crypto,
    exchange: 'Binance', marketCurrency: 'USD', accountCurrency: 'USD',
    decimalPrecision: 4, tickSize: 0.0001, lotSize: 1,
    minOrderSize: 1, maxOrderSize: 1000000, maxLeverage: 20, defaultLeverage: 1,
    session: TradingSession.crypto,
  ),
  'DOGE': AssetMetadata(
    symbol: 'DOGE', name: 'Dogecoin', marketType: MarketType.crypto,
    exchange: 'Binance', marketCurrency: 'USD', accountCurrency: 'USD',
    decimalPrecision: 4, tickSize: 0.00001, lotSize: 1,
    minOrderSize: 1, maxOrderSize: 10000000, maxLeverage: 20, defaultLeverage: 1,
    session: TradingSession.crypto,
  ),
  'ADA': AssetMetadata(
    symbol: 'ADA', name: 'Cardano', marketType: MarketType.crypto,
    exchange: 'Binance', marketCurrency: 'USD', accountCurrency: 'USD',
    decimalPrecision: 4, tickSize: 0.0001, lotSize: 1,
    minOrderSize: 1, maxOrderSize: 5000000, maxLeverage: 20, defaultLeverage: 1,
    session: TradingSession.crypto,
  ),
  'AVAX': AssetMetadata(
    symbol: 'AVAX', name: 'Avalanche', marketType: MarketType.crypto,
    exchange: 'Binance', marketCurrency: 'USD', accountCurrency: 'USD',
    decimalPrecision: 2, tickSize: 0.01, lotSize: 1,
    minOrderSize: 0.01, maxOrderSize: 100000, maxLeverage: 20, defaultLeverage: 1,
    session: TradingSession.crypto,
  ),
};

/// Lookup AssetMetadata by symbol. Returns null if not found.
AssetMetadata? getAssetMetadata(String symbol) => assetMetadataRegistry[symbol];

/// Lookup with fallback — returns a generic metadata if symbol not registered.
AssetMetadata getAssetMetadataOrDefault(String symbol) {
  return assetMetadataRegistry[symbol] ?? AssetMetadata(
    symbol: symbol,
    name: symbol,
    marketType: MarketType.crypto,
    exchange: 'Unknown',
    marketCurrency: 'USD',
    accountCurrency: 'USD',
    decimalPrecision: 2,
    tickSize: 0.01,
    lotSize: 1,
    minOrderSize: 0.0001,
    maxOrderSize: 999999,
    maxLeverage: 1,
    defaultLeverage: 1,
    session: TradingSession.crypto,
  );
}
