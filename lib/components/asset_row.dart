import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/markets.dart';
import 'package:app/constants/colors.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/utils/formatters.dart';

class AssetRow extends StatefulWidget {
  final Asset asset;
  final VoidCallback onPress;

  const AssetRow({
    super.key,
    required this.asset,
    required this.onPress,
  });

  @override
  State<AssetRow> createState() => _AssetRowState();
}

class _AssetRowState extends State<AssetRow> {
  late TradingProvider _provider;
  StreamSubscription? _subscription;
  late double _price;
  late double _change;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = Provider.of<TradingProvider>(context, listen: false);
    _price = _provider.priceOf(widget.asset.symbol);
    _change = _provider.changeOf(widget.asset.symbol);
    _subscribe();
  }

  @override
  void didUpdateWidget(AssetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.symbol != widget.asset.symbol) {
      _price = _provider.priceOf(widget.asset.symbol);
      _change = _provider.changeOf(widget.asset.symbol);
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _provider.priceUpdateStream
        .where((sym) => sym == widget.asset.symbol)
        .listen((_) {
      if (mounted) {
        setState(() {
          _price = _provider.priceOf(widget.asset.symbol);
          _change = _provider.changeOf(widget.asset.symbol);
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final asset = widget.asset;

    final double price = _price;
    final double change = _change;
    final bool isPositive = change >= 0;
    final Color changeColor = isPositive ? colors.positive : colors.negative;
    final bool isFav = _provider.isFavorite(asset.symbol);

    final Color typeColor = AppColors.marketColor(colors, asset.type);
    final IconData typeIcon = Icons.currency_bitcoin;
    final String badgeText = asset.symbol.substring(0, asset.symbol.length < 3 ? asset.symbol.length : 3);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.6),
          width: 0.8,
        ),
        boxShadow: colors.cardShadow,
      ),
      child: InkWell(
        onTap: widget.onPress,
        borderRadius: BorderRadius.circular(AppColors.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          child: Row(
            children: [
              // Star Favorite Toggler
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _provider.toggleFavorite(asset.symbol);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4.0, 8.0, 10.0, 8.0),
                  child: Icon(
                    isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFav
                        ? colors.accent
                        : colors.mutedForeground.withValues(alpha: 0.4),
                    size: 22.0,
                  ),
                ),
              ),

              // Badge wrapper with glowing effect
              Container(
                width: 44.0,
                height: 44.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      typeColor.withValues(alpha: 0.2),
                      typeColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                ),
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.0),
                  child: () {
                    final logoUrl = getAssetLogoUrl(asset.symbol);
                    if (logoUrl != null && logoUrl.isNotEmpty) {
                      return Image.network(
                        logoUrl,
                        width: 28.0,
                        height: 28.0,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            typeIcon,
                            color: typeColor,
                            size: 20.0,
                          );
                        },
                      );
                    }
                    return Icon(
                      typeIcon,
                      color: typeColor,
                      size: 20.0,
                    );
                  }(),
                ),
              ),
              const SizedBox(width: 12.0),

              // Asset Symbol & Name Details
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          asset.symbol,
                          style: TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.bold,
                            color: colors.foreground,
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: colors.muted,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w800,
                              color: colors.mutedForeground,
                            ),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      asset.name,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: colors.mutedForeground,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12.0),

              // Realtime price metrics
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPrice(price, asset.type),
                    style: TextStyle(
                      fontSize: 15.0,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: isPositive
                          ? colors.positiveBackground.withValues(alpha: 0.7)
                          : colors.negativeBackground.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Text(
                      '${isPositive ? '+' : ''}${formatPct(change)}',
                      style: TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                        color: changeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
