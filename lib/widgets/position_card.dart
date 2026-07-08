import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/constants/markets.dart';
import 'package:app/models/trading_models.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/utils/formatters.dart';
import 'package:app/components/ui.dart';

class PositionCard extends StatefulWidget {
  final Position position;
  const PositionCard({super.key, required this.position});

  @override
  State<PositionCard> createState() => _PositionCardState();
}

class _PositionCardState extends State<PositionCard> {
  late TradingProvider _provider;
  StreamSubscription? _subscription;
  late double _price;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = Provider.of<TradingProvider>(context, listen: false);
    _price = _provider.priceOf(widget.position.symbol);
    _subscribe();
  }

  @override
  void didUpdateWidget(PositionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position.symbol != widget.position.symbol) {
      _price = _provider.priceOf(widget.position.symbol);
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _provider.priceUpdateStream
        .where((sym) => sym == widget.position.symbol)
        .listen((_) {
      if (mounted) {
        setState(() {
          _price = _provider.priceOf(widget.position.symbol);
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
    final position = widget.position;
    final asset = getAssetBySymbol(position.symbol);
    final price = _price;
    final pnl = position.pnl(price);
    final pnlPct = position.pnlPct(price);
    final isUp = pnl >= 0;
    final pnlColor = isUp ? colors.positive : colors.negative;
    final sideColor = position.side == PositionSide.long ? colors.positive : colors.negative;

    final config = MarketConfig.get(position.marketType, position.tradingType);
    double? pips;
    if (config.pipCalculationEnabled && asset != null) {
      final pipSize = asset.pipSize;
      if (pipSize > 0) {
        final diff = price - position.entryPrice;
        pips = diff / pipSize;
        if (position.side == PositionSide.short) {
          pips = -pips;
        }
      }
    }

    final pnlStr = '${isUp ? '+' : ''}${formatCurrency(pnl)}';
    final pipsStr = pips != null ? ' (${pips >= 0 ? '+' : ''}${pips.toStringAsFixed(1)} pips)' : '';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(color: sideColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6.0)),
                child: Text(position.side.label.toUpperCase(), style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w800, color: sideColor)),
              ),
              const SizedBox(width: 8.0),
              Text(position.symbol, style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: colors.foreground)),
              const Spacer(),
              Text('$pnlStr$pipsStr', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: pnlColor)),
            ],
          ),
          const SizedBox(height: 4.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${formatQty(position.qty)} @ ${formatPrice(position.entryPrice, position.marketType)}', style: TextStyle(fontSize: 12.0, color: colors.mutedForeground, fontWeight: FontWeight.w500)),
              Text('${isUp ? '+' : ''}${formatPct(pnlPct)}', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: pnlColor)),
            ],
          ),
          const SizedBox(height: 10.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 6.0,
            children: [
              _chip(colors, 'Mark ${formatPrice(price, position.marketType)}'),
              if (config.marginEnabled) _chip(colors, 'Margin ${formatCurrency(position.margin)}'),
              if (position.stopLoss != null) _chip(colors, 'SL ${formatPrice(position.stopLoss!, position.marketType)}', color: colors.negative),
              if (position.takeProfit != null) _chip(colors, 'TP ${formatPrice(position.takeProfit!, position.marketType)}', color: colors.positive),
              if (position.trailingStop != null) _chip(colors, 'Trail ${formatPrice(position.trailingStop!, position.marketType)}', color: colors.accent),
              if (config.liquidationEnabled) _chip(colors, 'Liq ${formatPrice(position.liquidationPrice, position.marketType)}', color: colors.negative),
            ],
          ),
          const SizedBox(height: 12.0),
          Row(
            children: [
              _actionBtn(context, 'Close 25%', () => _provider.closePosition(position.id, fraction: 0.25), colors, outline: true),
              const SizedBox(width: 8.0),
              _actionBtn(context, 'Close 50%', () => _provider.closePosition(position.id, fraction: 0.5), colors, outline: true),
              const SizedBox(width: 8.0),
              _actionBtn(context, 'Close All', () => _provider.closePosition(position.id), colors, color: colors.negative),
            ],
          ),
          const SizedBox(height: 8.0),
          InkWell(
            onTap: () => _editRisk(context, _provider, asset),
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              decoration: BoxDecoration(
                color: colors.muted,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: colors.border),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune_rounded, size: 15.0, color: colors.mutedForeground),
                  const SizedBox(width: 6.0),
                  Text('Edit SL / TP / Trailing', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.mutedForeground)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(ThemePalette colors, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(color: (color ?? colors.mutedForeground).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6.0)),
      child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color ?? colors.mutedForeground)),
    );
  }

  Widget _actionBtn(BuildContext context, String label, VoidCallback onTap, ThemePalette colors, {bool outline = false, Color? color}) {
    final c = color ?? colors.primary;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          decoration: BoxDecoration(
            color: outline ? Colors.transparent : c.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: outline ? c : Colors.transparent, width: 1.0),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: c)),
        ),
      ),
    );
  }

  void _editRisk(BuildContext context, TradingProvider provider, Asset? asset) {
    final colors = AppColors.of(context);
    final slCtrl = TextEditingController(text: widget.position.stopLoss?.toString() ?? '');
    final tpCtrl = TextEditingController(text: widget.position.takeProfit?.toString() ?? '');
    final trailCtrl = TextEditingController(text: widget.position.trailingStop?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.0))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16.0),
              Text('Adjust Risk · ${widget.position.symbol}', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: colors.foreground)),
              const SizedBox(height: 16.0),
              _riskInput(colors, 'Stop Loss price', slCtrl),
              const SizedBox(height: 12.0),
              _riskInput(colors, 'Take Profit price', tpCtrl),
              const SizedBox(height: 12.0),
              _riskInput(colors, 'Trailing stop distance', trailCtrl),
              const SizedBox(height: 18.0),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final trail = double.tryParse(trailCtrl.text);
                    provider.updatePositionRisk(
                      widget.position.id,
                      stopLoss: double.tryParse(slCtrl.text),
                      takeProfit: double.tryParse(tpCtrl.text),
                      trailingStop: trail,
                      clearTrailing: trail == null,
                    );
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.brightness == Brightness.dark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                  ),
                  child: const Text('Update Position', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16.0),
            ],
          ),
        );
      },
    );
  }

  Widget _riskInput(ThemePalette colors, String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.mutedForeground)),
        const SizedBox(height: 6.0),
        Container(
          decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(8.0), border: Border.all(color: colors.border)),
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: colors.foreground, fontSize: 16.0, fontWeight: FontWeight.bold),
            decoration: InputDecoration(hintText: 'Leave blank to disable', hintStyle: TextStyle(color: colors.mutedForeground.withValues(alpha: 0.6), fontWeight: FontWeight.normal, fontSize: 13.0), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 14.0)),
          ),
        ),
      ],
    );
  }
}
