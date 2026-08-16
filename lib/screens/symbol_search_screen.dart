/// Symbol search across every tradable Binance spot pair.
///
/// Results are ranked by match quality then by 24h volume, so typing "bt"
/// surfaces BTCUSDT rather than an illiquid pair that happens to match.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app/components/ui.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/instrument.dart';
import 'package:app/providers/market_data_provider.dart';
import 'package:app/screens/chart_screen.dart';
import 'package:app/services/symbol_registry.dart';
import 'package:app/utils/haptics.dart';

class SymbolSearchScreen extends StatefulWidget {
  /// When true, tapping a row returns the [Instrument] via
  /// `Navigator.pop(instrument)` instead of opening the full chart screen.
  /// Used by the Dashboard to let the user pick the featured coin.
  final bool pickMode;

  const SymbolSearchScreen({super.key, this.pickMode = false});

  @override
  State<SymbolSearchScreen> createState() => _SymbolSearchScreenState();
}

class _SymbolSearchScreenState extends State<SymbolSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  String _query = '';
  String? _quoteFilter;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Autofocus so the keyboard is up immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // Debounce so a fast typist does not re-rank hundreds of symbols per key.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _query = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final registry = context.watch<SymbolRegistry>();
    final market = context.watch<MarketDataProvider>();

    final results = registry.search(
      _query,
      quoteFilter: _quoteFilter,
      limit: 100,
    );

    // Only the visible results should be able to trigger UI rebuilds.
    market.setInterest(results.map((i) => i.symbol));

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: widget.pickMode ? 'Choose Coin' : 'Add Symbol',
              showBackButton: true,
            ),
            _searchField(colors),
            _quoteFilters(registry, colors),
            const SizedBox(height: 4),
            Expanded(child: _results(registry, market, results, colors)),
          ],
        ),
      ),
    );
  }

  Widget _searchField(ThemePalette colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        onChanged: _onChanged,
        textCapitalization: TextCapitalization.characters,
        style: TextStyle(color: colors.foreground, fontSize: 14.5),
        decoration: InputDecoration(
          hintText: 'Search BTC, ETH, SOL…',
          hintStyle: TextStyle(color: colors.mutedForeground, fontSize: 14),
          prefixIcon:
              Icon(Icons.search_rounded, color: colors.mutedForeground, size: 20),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: colors.mutedForeground, size: 18),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _query = '');
                  },
                ),
          filled: true,
          fillColor: colors.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: colors.primary, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _quoteFilters(SymbolRegistry registry, ThemePalette colors) {
    final quotes = SymbolRegistry.preferredQuotes
        .where((q) => registry.availableQuotes().contains(q))
        .toList();
    if (quotes.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          PillButton(
            label: 'All',
            active: _quoteFilter == null,
            onTap: () => setState(() => _quoteFilter = null),
          ),
          const SizedBox(width: 8),
          for (final q in quotes) ...[
            PillButton(
              label: q,
              active: _quoteFilter == q,
              onTap: () => setState(
                  () => _quoteFilter = _quoteFilter == q ? null : q),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _results(
    SymbolRegistry registry,
    MarketDataProvider market,
    List<Instrument> results,
    ThemePalette colors,
  ) {
    if (registry.isLoading && !registry.isReady) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final error = registry.error;
    if (error != null && !registry.isReady) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        message: error,
        ctaLabel: 'Retry',
        onCta: () => registry.load(forceRefresh: true),
      );
    }

    if (results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        message: _query.isEmpty
            ? 'No symbols available.'
            : 'Nothing matches "$_query".',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: results.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        thickness: 0.6,
        color: colors.border.withValues(alpha: 0.4),
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) {
        final instrument = results[index];
        final watched = market.isWatched(instrument.symbol);
        final price = market.priceOf(instrument.symbol);
        final change = market.changeOf(instrument.symbol);
        final up = change >= 0;

        return ListTile(
          dense: true,
          leading: SymbolAvatar(
            label: instrument.base,
            color: colors.primary,
            size: 34,
          ),
          title: Text(
            instrument.displayName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          subtitle: instrument.quoteVolume24h > 0
              ? Text(
                  'Vol ${instrument.volumeLabel}',
                  style: TextStyle(
                      fontSize: 10.5, color: colors.mutedForeground),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (price > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      instrument.formatPrice(price),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.foreground,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '${up ? '+' : ''}${change.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: up ? colors.positive : colors.negative,
                      ),
                    ),
                  ],
                ),
              IconButton(
                tooltip: watched ? 'Remove from watchlist' : 'Add to watchlist',
                icon: Icon(
                  watched ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  size: 20,
                  color: watched ? colors.primary : colors.mutedForeground,
                ),
                onPressed: () {
                  Haptics.light();
                  market.toggleWatchlist(instrument.symbol);
                },
              ),
            ],
          ),
          onTap: () {
            Haptics.light();
            if (widget.pickMode) {
              Navigator.of(context).pop(instrument);
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChartScreen(instrument: instrument),
              ),
            );
          },
        );
      },
    );
  }
}
