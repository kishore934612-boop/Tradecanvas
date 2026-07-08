import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/constants/markets.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/components/ui.dart';
import 'package:app/utils/formatters.dart';
import 'package:app/screens/main_tabs_screen.dart';
import 'package:app/components/price_stream_builder.dart';
import 'package:app/components/candlestick_chart.dart';

const Map<String, String> _assetDescriptions = {
  'BTC': 'Bitcoin is the first decentralized digital currency. It uses cryptography to secure and verify transactions, which are recorded on a public distributed ledger called a blockchain.',
  'ETH': 'Ethereum is a decentralized blockchain platform that establishes a peer-to-peer network that securely executes and verifies application code, called smart contracts.',
  'SOL': 'Solana is a high-performance blockchain platform optimized for scalability, offering fast transaction speeds and low fees for decentralized applications and smart contracts.',
  'AAPL': 'Apple Inc. designs, manufactures, and markets smartphones, personal computers, tablets, wearables, and accessories worldwide. Apple is one of the world\'s largest technology companies.',
  'MSFT': 'Microsoft Corporation is a multinational technology giant that develops, manufactures, licenses, supports, and sells computer software, consumer electronics, and personal computers.',
  'EUR/USD': 'The EUR/USD pair represents the exchange rate between the Euro and the US Dollar, the two largest reserve currencies in the global foreign exchange market.',
  'XAU': 'Gold is a highly liquid and historically secure safe-haven commodity, widely traded as a spot instrument to hedge against inflation and economic uncertainty.',
};

class CoinDetailScreen extends StatelessWidget {
  final String symbol;
  final VoidCallback? onTrade;

  const CoinDetailScreen({super.key, required this.symbol, this.onTrade});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final favorites = context.select<TradingProvider, List<String>>((p) => p.favorites);
    final provider = Provider.of<TradingProvider>(context, listen: false);
    
    // Find the asset details
    final asset = assets.firstWhere((a) => a.symbol == symbol, orElse: () => assets.first);
    final bool isFav = favorites.contains(asset.symbol);

    final String description = _assetDescriptions[symbol] ??
        'Trade ${asset.name} (${asset.symbol}) with up to ${asset.maxLeverage.toStringAsFixed(0)}x leverage. Monitor real-time price changes, configure risk parameters, and place instant orders directly in the terminal.';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 8.0),
              width: 24.0,
              height: 24.0,
              decoration: BoxDecoration(
                color: colors.muted,
                borderRadius: BorderRadius.circular(6.0),
              ),
              alignment: Alignment.center,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: () {
                  final logoUrl = getAssetLogoUrl(asset.symbol);
                  IconData getFallbackIcon() {
                    return Icons.currency_bitcoin;
                  }
                  final typeColor = AppColors.marketColor(colors, asset.type);
                  if (logoUrl != null && logoUrl.isNotEmpty) {
                    return Image.network(
                      logoUrl,
                      width: 20.0,
                      height: 20.0,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(getFallbackIcon(), color: typeColor, size: 16.0);
                      },
                    );
                  }
                  return Icon(getFallbackIcon(), color: typeColor, size: 16.0);
                }(),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  asset.symbol,
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                Text(
                  asset.name,
                  style: TextStyle(
                    color: colors.mutedForeground,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(width: 8.0),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                provider.toggleFavorite(asset.symbol);
              },
              child: Icon(
                isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFav ? colors.accent : colors.mutedForeground,
                size: 18.0,
              ),
            ),
          ],
        ),
        iconTheme: IconThemeData(color: colors.foreground),
        actions: [
          PriceStreamBuilder(
            symbol: symbol,
            builder: (context, price, change) {
              final bool isPositive = change >= 0;
              final Color changeColor = isPositive ? colors.positive : colors.negative;
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatPrice(price, asset.type),
                      style: TextStyle(
                        color: colors.foreground,
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${isPositive ? '+' : ''}${formatPct(change)}',
                      style: TextStyle(
                        color: changeColor,
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Candlestick chart section ────────────────────────────
                  _CompactChartSection(asset: asset),
                  const SizedBox(height: 20.0),

                  // Key statistics list
                  Text(
                    'Asset Statistics',
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                      color: colors.mutedForeground,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      children: [
                        _statRow('Base Price', formatPrice(asset.basePrice, asset.type), colors),
                        const Divider(height: 1.0, thickness: 0.5),
                        _statRow('Maximum Leverage', '${asset.maxLeverage.toStringAsFixed(0)}x', colors),
                        const Divider(height: 1.0, thickness: 0.5),
                        _statRow('Volatility Rating', '${(asset.volatility * 100.0).toStringAsFixed(1)}%', colors),
                        const Divider(height: 1.0, thickness: 0.5),
                        _statRow('Asset Category', asset.type.label, colors),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // About section
                  Text(
                    'About $symbol',
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                      color: colors.mutedForeground,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  GlassCard(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: colors.foreground,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                ],
              ),
            ),
          ),
          // Action button container at bottom
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colors.card,
              border: Border(top: BorderSide(color: colors.border, width: 0.8)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 52.0,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).pop();
                    if (onTrade != null) {
                      onTrade!();
                    } else {
                      mainTabsKey.currentState?.selectTab(2, symbol: asset.symbol);
                    }
                  },
                  borderRadius: BorderRadius.circular(10.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: colors.primaryGradient,
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: colors.glowShadow,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Trade ${asset.symbol} Now',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: colors.brightness == Brightness.dark ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, ThemePalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w600,
              color: colors.mutedForeground,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact chart section widget
// ---------------------------------------------------------------------------

class _CompactChartSection extends StatelessWidget {
  final Asset asset;
  const _CompactChartSection({required this.asset});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return PriceStreamBuilder(
      symbol: asset.symbol,
      builder: (context, price, change) {
        final isPositive = change >= 0;
        final changeColor = isPositive ? colors.positive : colors.negative;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header: live price + change badge
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Price Chart',
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                        color: colors.mutedForeground,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Row(
                      children: [
                        Text(
                          formatPrice(price, asset.type),
                          style: TextStyle(
                            fontSize: 20.0,
                            fontWeight: FontWeight.bold,
                            color: colors.foreground,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 3.0),
                          decoration: BoxDecoration(
                            color: isPositive
                                ? colors.positiveBackground
                                : colors.negativeBackground,
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          child: Text(
                            '${isPositive ? '+' : ''}${formatPct(change)}',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.bold,
                              color: changeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                // Fullscreen button
                _FullscreenLaunchButton(asset: asset, currentPrice: price),
              ],
            ),
            const SizedBox(height: 12.0),
            // Chart card
            GlassCard(
              padding: const EdgeInsets.fromLTRB(12.0, 12.0, 4.0, 10.0),
              child: CandlestickChart(
                asset: asset,
                currentPrice: price,
                height: 240.0,
                // Phase 6: feed the chart via ChartController (decoupled from provider)
                priceStream: Provider.of<TradingProvider>(context, listen: false)
                    .priceStreamFor(asset.symbol),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Fullscreen launch button
// ---------------------------------------------------------------------------

class _FullscreenLaunchButton extends StatelessWidget {
  final Asset asset;
  final double currentPrice;
  const _FullscreenLaunchButton(
      {required this.asset, required this.currentPrice});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: 'Full screen chart',
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CandlestickFullscreenScreen(
                asset: asset, currentPrice: currentPrice),
            fullscreenDialog: true,
          ));
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: colors.muted.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: colors.border, width: 0.8),
          ),
          child: Icon(Icons.open_in_full_rounded,
              color: colors.mutedForeground, size: 18.0),
        ),
      ),
    );
  }
}

// (Fullscreen chart is provided by CandlestickFullscreenScreen in candlestick_chart.dart)
