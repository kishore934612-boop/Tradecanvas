import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/trading_provider.dart';

class PriceStreamBuilder extends StatefulWidget {
  final String symbol;
  final Widget Function(BuildContext context, double price, double change) builder;

  const PriceStreamBuilder({
    super.key,
    required this.symbol,
    required this.builder,
  });

  @override
  State<PriceStreamBuilder> createState() => _PriceStreamBuilderState();
}

class _PriceStreamBuilderState extends State<PriceStreamBuilder> {
  late TradingProvider _provider;
  StreamSubscription? _subscription;
  late double _price;
  late double _change;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = Provider.of<TradingProvider>(context, listen: false);
    _price = _provider.priceOf(widget.symbol);
    _change = _provider.changeOf(widget.symbol);
    _subscribe();
  }

  @override
  void didUpdateWidget(PriceStreamBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) {
      _price = _provider.priceOf(widget.symbol);
      _change = _provider.changeOf(widget.symbol);
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _provider.priceUpdateStream.where((sym) => sym == widget.symbol).listen((_) {
      if (mounted) {
        setState(() {
          _price = _provider.priceOf(widget.symbol);
          _change = _provider.changeOf(widget.symbol);
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
    return widget.builder(context, _price, _change);
  }
}
