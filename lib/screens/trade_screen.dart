import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/constants/markets.dart';
import 'package:app/models/trading_models.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/utils/formatters.dart';
import 'package:app/utils/position_calculator.dart';
import 'package:app/components/ui.dart';
import 'package:app/screens/main_tabs_screen.dart';
import 'package:app/widgets/journal_dialogs.dart';
import 'package:app/widgets/position_card.dart';

class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key});

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

enum _SizeMode { value, qty, risk }

class _TradeScreenState extends State<TradeScreen> {
  MarketType _selectedMarket = MarketType.crypto;
  String _selectedSymbol = 'BTC';
  TradingType? _tradingType;
  PositionSide _side = PositionSide.long;
  final OrderType _orderType = OrderType.market;
  final _SizeMode _sizeMode = _SizeMode.qty;
  double _leverage = 1.0;
  int _activeFormTab = 0; // 0: Order, 1: Positions



  bool _useStopLoss = false;
  bool _useTakeProfit = false;
  bool _useTrailing = false;

  final _valueCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _riskCtrl = TextEditingController(text: '1');
  final _limitCtrl = TextEditingController();
  final _stopCtrl = TextEditingController();
  final _slCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  final _trailCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _valueCtrl,
      _qtyCtrl,
      _riskCtrl,
      _limitCtrl,
      _stopCtrl,
      _slCtrl,
      _tpCtrl,
      _trailCtrl,
      _searchCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }


  void _resetInputs() {
    _valueCtrl.clear();
    _qtyCtrl.clear();
    _limitCtrl.clear();
    _stopCtrl.clear();
    _slCtrl.clear();
    _tpCtrl.clear();
    _trailCtrl.clear();
    _useStopLoss = false;
    _useTakeProfit = false;
    _useTrailing = false;
  }

  double _entryPrice(double currentPrice) {
    if (_orderType == OrderType.market) return currentPrice;
    final lim = double.tryParse(_limitCtrl.text);
    final stp = double.tryParse(_stopCtrl.text);
    return lim ?? stp ?? currentPrice;
  }

  double _computeQty(double entry, double equity) {
    switch (_sizeMode) {
      case _SizeMode.value:
        final v = double.tryParse(_valueCtrl.text) ?? 0;
        return entry > 0 ? (v * _leverage) / entry : 0;
      case _SizeMode.qty:
        return double.tryParse(_qtyCtrl.text) ?? 0;
      case _SizeMode.risk:
        final risk = double.tryParse(_riskCtrl.text) ?? 0;
        final sl = double.tryParse(_slCtrl.text);
        if (sl == null || risk <= 0) return 0;
        final perUnit = (entry - sl).abs();
        if (perUnit <= 0) return 0;
        return (equity * (risk / 100.0)) / perUnit;
    }
  }

  TradingType _effectiveTradingType(Asset asset) {
    if (_tradingType != null) {
      final available = tradingTypesFor(asset.type);
      if (available.contains(_tradingType!)) return _tradingType!;
    }
    return defaultTradingType(asset.type);
  }

  void _submit(Asset asset, double currentPrice, double qty, PositionCalc calc) {
    final appState = context.read<AppState>();
    final provider = context.read<TradingProvider>();
    final tt = _effectiveTradingType(asset);

    void doPlace(EntryJournal? journal) {
      final res = provider.placeOrder(
        symbol: asset.symbol,
        type: _orderType,
        side: _side,
        qty: qty,
        leverage: _leverage,
        tradingType: tt,
        limitPrice: double.tryParse(_limitCtrl.text),
        stopPrice: double.tryParse(_stopCtrl.text),
        stopLoss: _useStopLoss ? double.tryParse(_slCtrl.text) : null,
        takeProfit: _useTakeProfit ? double.tryParse(_tpCtrl.text) : null,
        trailingStop: _useTrailing ? double.tryParse(_trailCtrl.text) : null,
        entryJournal: journal,
      );
      if (!mounted) return;
      _showResult(res);
      if (res.success) setState(_resetInputs);
    }

    if (appState.profile.journalPromptsEnabled) {
      showEntryJournalDialog(context).then((journal) {
        // null => user cancelled the trade entirely
        if (journal == null) return;
        doPlace(journal);
      });
    } else {
      doPlace(null);
    }
  }

  void _showResult(TradeResult res) {
    final colors = AppColors.of(context);
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: Text(res.success ? 'Order Submitted' : 'Order Failed', style: TextStyle(color: colors.foreground, fontWeight: FontWeight.bold)),
        content: Text(res.success ? (res.message ?? 'Done') : (res.error ?? 'Unknown error'), style: TextStyle(color: colors.foreground)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context, ThemePalette colors) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: colors.border, width: 1.0),
            boxShadow: colors.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 12.0, 8.0),
                child: Row(
                  children: [
                    Icon(Icons.help_center_rounded, color: colors.primary, size: 24.0),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        'Trading Methods Guide',
                        style: TextStyle(
                          color: colors.foreground,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: colors.mutedForeground, size: 22.0),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1.0, thickness: 0.8),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHelpSection(
                        title: 'Crypto Trading',
                        color: colors.crypto,
                        icon: Icons.currency_bitcoin_rounded,
                        methods: [
                          _buildHelpMethod(
                            name: 'Spot Trading',
                            desc: 'Purchase the actual underlying cryptocurrency token. Leveraged products and short selling are not allowed, meaning risk is limited to the asset\'s value. No liquidation risk.',
                          ),
                          _buildHelpMethod(
                            name: 'Futures Trading',
                            desc: 'Trade perpetual contracts tracking asset prices. Access high leverage (up to 125x) and support short selling (profit when price drops). Liquidates if margin is depleted.',
                          ),
                        ],
                      ),
                      // Crypto Trading only

                    ],
                  ),
                ),
              ),
              const Divider(height: 1.0, thickness: 0.8),
              // Footer
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Got It',
                      style: TextStyle(
                        color: colors.primaryForeground,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, ThemePalette colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: TextStyle(fontSize: 10.0, color: colors.mutedForeground, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 10.5, color: colors.foreground, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildHelpSection({
    required String title,
    required Color color,
    required IconData icon,
    required List<Widget> methods,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 16.0),
            ),
            const SizedBox(width: 8.0),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10.0),
        ...methods,
      ],
    );
  }

  Widget _buildHelpMethod({required String name, required String desc}) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 6.0,
                height: 6.0,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8.0),
              Text(
                name,
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          Padding(
            padding: const EdgeInsets.only(left: 14.0),
            child: Text(
              desc,
              style: TextStyle(
                fontSize: 11.5,
                color: colors.mutedForeground,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    // ignore: unused_local_variable
    final positionsState = context.select<TradingProvider, String>((p) => p.positions.where((pos) => pos.symbol == _selectedSymbol).map((x) => '${x.id}_${x.qty}_${x.stopLoss}_${x.takeProfit}').join(','));

    final provider = Provider.of<TradingProvider>(context, listen: false);

    // Consume cross-tab navigation symbol.
    final mainTabs = mainTabsKey.currentState;
    if (mainTabs != null) {
      final sym = mainTabs.consumeSelectedSymbol();
      if (sym != null) {
        final preloadedAsset = getAssetBySymbol(sym);
        if (preloadedAsset != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _selectedSymbol = sym;
                _selectedMarket = preloadedAsset.type;
                _tradingType = defaultTradingType(preloadedAsset.type);
                _leverage = MarketConfig.get(preloadedAsset.type, _tradingType!).defaultLeverage;
                _side = PositionSide.long;
                _resetInputs();
              });
            }
          });
        }
      }
    }

    final asset = getAssetBySymbol(_selectedSymbol) ?? assets.firstWhere((a) => a.type == _selectedMarket);
    final tt = _tradingType ?? defaultTradingType(asset.type);
    final config = MarketConfig.get(asset.type, tt);

    // Enforce side constraint when config disallows shorts
    if (!config.shortTradingEnabled && _side == PositionSide.short) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _side = PositionSide.long);
      });
    }
    // Enforce leverage constraint
    if (!config.leverageEnabled && _leverage != 1.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _leverage = 1.0);
      });
    }
    if (_leverage > config.maxLeverage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _leverage = config.maxLeverage);
      });
    }

    final typeColor = AppColors.marketColor(colors, asset.type);
    final symbolPositions = provider.positions.where((p) => p.symbol == asset.symbol).toList();
    final availableTradingTypes = tradingTypesFor(asset.type);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: 'Trading Terminal',
              trailing: GestureDetector(
                onTap: () => _showHelpDialog(context, colors),
                child: Container(
                  width: 36.0,
                  height: 36.0,
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border, width: 0.8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.help_outline_rounded,
                    color: colors.primary,
                    size: 18.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12.0),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

              // Search bar to filter assets
              Container(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: colors.border,
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: colors.mutedForeground, size: 20.0),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        style: TextStyle(
                          color: colors.foreground,
                          fontSize: 15.0,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search asset in ${_selectedMarket.label}...',
                          hintStyle: TextStyle(color: colors.mutedForeground.withValues(alpha: 0.7)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        onChanged: (v) => setState(() {}),
                        autocorrect: false,
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          FocusScope.of(context).unfocus();
                          setState(() {});
                        },
                        child: Icon(Icons.close_rounded, color: colors.mutedForeground, size: 20.0),
                      ),
                  ],
                ),
              ),

              // Search suggestions list - only visible when user has typed something
              if (_searchCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8.0),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200.0),
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: colors.border, width: 1.0),
                  ),
                  child: Builder(
                    builder: (context) {
                      final query = _searchCtrl.text.toLowerCase();
                      final filtered = assets.where((a) {
                        return a.type == _selectedMarket &&
                               (a.symbol.toLowerCase().contains(query) ||
                                a.name.toLowerCase().contains(query));
                      }).toList();

                      if (filtered.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No matching assets found in this market.',
                            style: TextStyle(color: Colors.grey, fontSize: 13.0),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => Divider(color: colors.border, height: 1.0, thickness: 0.5),
                        itemBuilder: (context, idx) {
                          final a = filtered[idx];
                          final ic = AppColors.marketColor(colors, a.type);
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14.0,
                                backgroundColor: ic.withValues(alpha: 0.15),
                                child: Text(
                                  a.symbol.substring(0, 1),
                                  style: TextStyle(color: ic, fontSize: 11.0, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                a.symbol,
                                style: TextStyle(color: colors.foreground, fontWeight: FontWeight.bold, fontSize: 13.0),
                              ),
                              subtitle: Text(
                                a.name,
                                style: TextStyle(color: colors.mutedForeground, fontSize: 11.0),
                              ),
                              trailing: Icon(Icons.chevron_right_rounded, color: colors.mutedForeground, size: 16.0),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _selectedSymbol = a.symbol;
                                  _tradingType = defaultTradingType(a.type);
                                  _leverage = MarketConfig.get(a.type, _tradingType!).defaultLeverage;
                                  _resetInputs();
                                  _searchCtrl.clear();
                                  FocusScope.of(context).unfocus();
                                });
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 14.0),

              // ── Price header card ──────────────────────────────────
              StreamBuilder<String>(
                stream: provider.priceUpdateStream.where((sym) => sym == asset.symbol),
                builder: (context, _) {
                  final price      = provider.priceOf(asset.symbol);
                  final change     = provider.changeOf(asset.symbol);
                  final isPositive = change >= 0;
                  final changeColor = isPositive ? colors.positive : colors.negative;
                  final changeBg    = isPositive ? colors.positiveBackground : colors.negativeBackground;

                  // Asset logo widget (reusable)
                  Widget logoWidget() {
                    final logoUrl = getAssetLogoUrl(asset.symbol);
                    IconData fallback() {
                      return Icons.currency_bitcoin;
                    }
                    return Container(
                      width: 32.0, height: 32.0,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      alignment: Alignment.center,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: (logoUrl != null && logoUrl.isNotEmpty)
                            ? Image.network(logoUrl, width: 22, height: 22, fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Icon(fallback(), color: typeColor, size: 18))
                            : Icon(fallback(), color: typeColor, size: 18),
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(color: colors.border, width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1 — logo + name + badges + change pill
                        Row(
                          children: [
                            logoWidget(),
                            const SizedBox(width: 10.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    asset.name,
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.foreground),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3.0),
                                  Row(
                                    children: [
                                      // Market type badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                        decoration: BoxDecoration(
                                          color: typeColor,
                                          borderRadius: BorderRadius.circular(4.0),
                                        ),
                                        child: Text(
                                          asset.type.label.toUpperCase(),
                                          style: const TextStyle(fontSize: 8.0, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
                                        ),
                                      ),
                                      const SizedBox(width: 5.0),
                                      // Trading type badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                        decoration: BoxDecoration(
                                          color: colors.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4.0),
                                          border: Border.all(color: colors.primary.withValues(alpha: 0.25), width: 0.8),
                                        ),
                                        child: Text(
                                          tt.label.toUpperCase(),
                                          style: TextStyle(fontSize: 8.0, fontWeight: FontWeight.w800, color: colors.primary, letterSpacing: 0.3),
                                        ),
                                      ),
                                      const SizedBox(width: 5.0),
                                      // Symbol chip
                                      Text(
                                        asset.symbol,
                                        style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600, color: colors.mutedForeground),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Change pill (right-aligned)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                              decoration: BoxDecoration(
                                color: changeBg,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPositive ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                                    color: changeColor, size: 16.0,
                                  ),
                                  Text(
                                    formatSignedPct(change),
                                    style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: changeColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10.0),
                        // Divider
                        Divider(height: 1, thickness: 0.6, color: colors.border),
                        const SizedBox(height: 10.0),

                        // Row 2 — big price + leverage/volatility stats
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                formatPrice(price, asset.type),
                                style: TextStyle(
                                  fontSize: 28.0,
                                  fontWeight: FontWeight.bold,
                                  color: colors.foreground,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            // Mini stat pills
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _miniStat('Max Lev', '${asset.maxLeverage.toStringAsFixed(0)}x', colors),
                                const SizedBox(height: 4.0),
                                _miniStat('Volatility', '${(asset.volatility * 100).toStringAsFixed(1)}%', colors),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 14.0),

              // ---- Trading Mode Selector ----
              _TradingModeSelector(
                types: availableTradingTypes,
                selected: tt,
                colors: colors,
                onChanged: (t) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _tradingType = t;
                    _leverage = MarketConfig.get(asset.type, t).defaultLeverage;
                    _side = PositionSide.long;
                    _resetInputs();
                  });
                },
              ),
              const SizedBox(height: 14.0),

              // Tab Bar (Place Order, Positions)
              Row(
                children: [
                  _tabHeader('Place Order', 0, colors),
                  _tabHeader('Positions (${symbolPositions.length})', 1, colors),
                ],
              ),
              const SizedBox(height: 16.0),

              // Switchable Tab Body
              if (_activeFormTab == 0) ...[
                // Long / Short (only show short when allowed)
                if (config.shortTradingEnabled)
                  _LongShortToggle(side: _side, colors: colors, onChanged: (s) => setState(() => _side = s))
                else
                  _LongOnlyBadge(colors: colors),
                const SizedBox(height: 14.0),

                // ---- Leverage Slider (only for leveraged products) ----
                if (config.leverageEnabled) ...[
                  _LeverageSlider(
                    leverage: _leverage,
                    maxLeverage: config.maxLeverage,
                    colors: colors,
                    onChanged: (v) => setState(() => _leverage = v),
                  ),
                  const SizedBox(height: 14.0),
                ],

                // Position Sizing
                if (config.lotSizeEnabled) ...[
                  _label('Lot Size', colors),
                  const SizedBox(height: 8.0),
                  _ForexLotSelector(
                    ctrl: _qtyCtrl,
                    colors: colors,
                    onChanged: () => setState(() {}),
                  ),
                ] else ...[
                  _priceField('Quantity (units)', _qtyCtrl, colors, hint: '0.0'),
                ],
                const SizedBox(height: 18.0),
                const Divider(height: 1.0, thickness: 1.0),
                const SizedBox(height: 18.0),

                // Risk Controls
                _label('Risk Controls', colors),
                const SizedBox(height: 8.0),
                _riskToggleRow('Stop Loss', _useStopLoss, (v) => setState(() => _useStopLoss = v), _slCtrl, 'SL price', colors),
                _riskToggleRow('Take Profit', _useTakeProfit, (v) => setState(() => _useTakeProfit = v), _tpCtrl, 'TP price', colors),
                _riskToggleRow('Trailing Stop', _useTrailing, (v) => setState(() => _useTrailing = v), _trailCtrl, 'Trail distance', colors),
                const SizedBox(height: 16.0),

                // Live price-dependent Calculator and Submit Card
                StreamBuilder<String>(
                  stream: provider.priceUpdateStream.where((sym) => sym == asset.symbol),
                  builder: (context, _) {
                    final price = provider.priceOf(asset.symbol);
                    final entry = _entryPrice(price);
                    final equity = provider.equity;
                    final qty = _computeQty(entry, equity);
                    final effectiveLeverage = config.leverageEnabled ? _leverage : 1.0;

                    final calc = calcFromQty(
                      qty: config.lotSizeEnabled ? qty * config.lotBaseUnits : qty,
                      entryPrice: entry,
                      leverage: effectiveLeverage,
                      side: _side,
                      stopLoss: _useStopLoss ? double.tryParse(_slCtrl.text) : null,
                      takeProfit: _useTakeProfit ? double.tryParse(_tpCtrl.text) : null,
                      accountEquity: equity,
                    );

                    final canSubmit = qty > 0 && calc.marginRequired <= provider.freeMargin && calc.marginRequired > 0;
                    final sideColor = _side == PositionSide.long ? colors.positive : colors.negative;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _calculatorCard(calc, asset, colors, config, tt),
                        const SizedBox(height: 20.0),
                        InkWell(
                          onTap: canSubmit ? () => _submit(asset, price, qty, calc) : null,
                          borderRadius: BorderRadius.circular(8.0),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            decoration: BoxDecoration(
                              gradient: canSubmit ? LinearGradient(colors: [sideColor, sideColor.withValues(alpha: 0.8)]) : null,
                              color: canSubmit ? null : colors.muted,
                              borderRadius: BorderRadius.circular(8.0),
                              boxShadow: canSubmit ? colors.glowShadow : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Open ${_side.label} · ${tt.label} · Market',
                              style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: canSubmit ? Colors.white : colors.mutedForeground),
                            ),
                          ),
                        ),
                        if (!canSubmit && qty > 0) ...[
                          const SizedBox(height: 8.0),
                          Text('Margin required ${formatCurrency(calc.marginRequired)} exceeds free margin ${formatCurrency(provider.freeMargin)}', style: TextStyle(fontSize: 11.5, color: colors.negative)),
                        ],
                      ],
                    );
                  }
                ),
              ] else if (_activeFormTab == 1) ...[
                // Open positions list
                if (symbolPositions.isNotEmpty) ...[
                  ...symbolPositions.map((p) => PositionCard(position: p)),
                ] else ...[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Column(
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, size: 48.0, color: colors.mutedForeground.withValues(alpha: 0.4)),
                          const SizedBox(height: 12.0),
                          Text(
                            'No open positions for ${asset.symbol}',
                            style: TextStyle(color: colors.mutedForeground, fontSize: 13.0, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ],
  ),
),
);
}

  Widget _tabHeader(String label, int index, ThemePalette colors) {
    final active = _activeFormTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeFormTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? colors.primary : Colors.transparent,
                width: 2.0,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: active ? FontWeight.bold : FontWeight.w600,
              color: active ? colors.primary : colors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, ThemePalette colors) =>
      Text(text, style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: colors.mutedForeground));



  Widget _priceField(String label, TextEditingController ctrl, ThemePalette colors, {String hint = '0.00'}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: colors.mutedForeground)),
        const SizedBox(height: 6.0),
        Container(
          decoration: BoxDecoration(color: colors.muted.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8.0)),
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: colors.foreground, fontSize: 16.0, fontWeight: FontWeight.bold),
            decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: colors.mutedForeground.withValues(alpha: 0.6)), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12.0)),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _riskToggleRow(String title, bool enabled, ValueChanged<bool> onToggle, TextEditingController ctrl, String hint, ThemePalette colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 130.0,
            child: Row(
              children: [
                Switch(value: enabled, activeThumbColor: colors.primary, onChanged: (v) => setState(() => onToggle(v)), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                const SizedBox(width: 4.0),
                Expanded(child: Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.foreground), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Opacity(
              opacity: enabled ? 1.0 : 0.4,
              child: Container(
                decoration: BoxDecoration(color: colors.muted.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8.0)),
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: TextField(
                  controller: ctrl,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: colors.foreground, fontSize: 14.0, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: colors.mutedForeground.withValues(alpha: 0.6)), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12.0)),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _calculatorCard(PositionCalc calc, Asset asset, ThemePalette colors, MarketConfig config, TradingType tt) {
    final rrColor = calc.riskReward >= 2 ? colors.positive : (calc.riskReward > 0 ? colors.accent : colors.mutedForeground);
    final riskColor = calc.riskPct == 0 ? colors.mutedForeground : (calc.riskPct <= 1 ? colors.positive : colors.negative);

    // Warnings
    final List<String> warnings = [];
    if (calc.riskPct > 2) warnings.add('⚠️ Risk exceeds 2% of account');
    if (_leverage > 20) warnings.add('⚠️ High leverage (${_leverage.toStringAsFixed(0)}x)');
    if (config.fundingFeesExist) warnings.add('ℹ️ Funding fees apply to perpetual positions');

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.calculate_rounded, size: 18.0, color: colors.primary), const SizedBox(width: 8.0), Text('Risk Calculator', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: colors.foreground))]),
          const SizedBox(height: 4.0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Text('${asset.type.label} · ${tt.label}', style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.w700, color: colors.primary)),
          ),
          const SizedBox(height: 12.0),
          if (config.lotSizeUsed)
            _calcRow('Lot Size', '${formatQty(calc.qty / config.lotBaseUnits)} lots (${formatQty(calc.qty)} units)', colors)
          else
            _calcRow('Position Size', '${formatQty(calc.qty)} ${asset.symbol}', colors),
          _calcRow('Position Value', formatCurrency(calc.positionValue), colors),
          _calcRow('Margin Required', formatCurrency(calc.marginRequired), colors),
          if (config.leverageAllowed)
            _calcRow('Leverage', '${_leverage.toStringAsFixed(0)}x', colors),
          _calcRow('Est. Profit', calc.estimatedProfit > 0 ? '+${formatCurrency(calc.estimatedProfit)}' : '—', colors, valueColor: calc.estimatedProfit > 0 ? colors.positive : null),
          _calcRow('Est. Loss', calc.estimatedLoss > 0 ? '-${formatCurrency(calc.estimatedLoss)}' : '—', colors, valueColor: calc.estimatedLoss > 0 ? colors.negative : null),
          _calcRow('Risk %', calc.riskPct > 0 ? formatPct(calc.riskPct) : '—', colors, valueColor: riskColor),
          _calcRow('Risk : Reward', calc.riskReward > 0 ? '1 : ${calc.riskReward.toStringAsFixed(2)}' : '—', colors, valueColor: rrColor),
          if (config.liquidationExists)
            _calcRow('Liquidation', formatPrice(calc.liquidationPrice, asset.type), colors, valueColor: colors.negative),

          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 12.0),
            ...warnings.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(w, style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600, color: colors.accent)),
            )),
          ],
        ],
      ),
    );
  }

  Widget _calcRow(String label, String value, ThemePalette colors, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.mutedForeground)),
          Flexible(child: Text(value, style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: valueColor ?? colors.foreground), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}



// ---- Trading Mode Selector Widget ----
class _TradingModeSelector extends StatelessWidget {
  final List<TradingType> types;
  final TradingType selected;
  final ThemePalette colors;
  final ValueChanged<TradingType> onChanged;

  const _TradingModeSelector({
    required this.types,
    required this.selected,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(3.0),
      child: Row(
        children: types.map((t) {
          final active = selected == t;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 7.0),
                decoration: BoxDecoration(
                  gradient: active
                      ? LinearGradient(colors: [colors.primary, colors.primary.withValues(alpha: 0.8)])
                      : null,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  t.label,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: active ? colors.primaryForeground : colors.mutedForeground,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---- Long/Short Toggle ----
class _LongShortToggle extends StatelessWidget {
  final PositionSide side;
  final ThemePalette colors;
  final ValueChanged<PositionSide> onChanged;
  const _LongShortToggle({required this.side, required this.colors, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(PositionSide s, String label, IconData icon, Color color) {
      final active = side == s;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(s);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9.0),
            decoration: BoxDecoration(
              gradient: active ? LinearGradient(colors: [color, color.withValues(alpha: 0.85)]) : null,
              borderRadius: BorderRadius.circular(6.0),
              boxShadow: active ? colors.glowShadow : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16.0, color: active ? Colors.white : colors.mutedForeground),
                const SizedBox(width: 6.0),
                Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: active ? Colors.white : colors.mutedForeground)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(8.0), border: Border.all(color: colors.border)),
      padding: const EdgeInsets.all(3.0),
      child: Row(children: [seg(PositionSide.long, 'Long', Icons.arrow_upward_rounded, colors.positive), seg(PositionSide.short, 'Short', Icons.arrow_downward_rounded, colors.negative)]),
    );
  }
}

// ---- Long-Only Badge (for Spot / Cash) ----
class _LongOnlyBadge extends StatelessWidget {
  final ThemePalette colors;
  const _LongOnlyBadge({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(3.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [colors.positive, colors.positive.withValues(alpha: 0.85)]),
          borderRadius: BorderRadius.circular(6.0),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.arrow_upward_rounded, size: 16.0, color: Colors.white),
            const SizedBox(width: 6.0),
            const Text('Buy (Long Only)', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ---- Leverage Slider ----
class _LeverageSlider extends StatelessWidget {
  final double leverage;
  final double maxLeverage;
  final ThemePalette colors;
  final ValueChanged<double> onChanged;

  const _LeverageSlider({
    required this.leverage,
    required this.maxLeverage,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 16.0, color: colors.primary),
              const SizedBox(width: 6.0),
              Text('Leverage', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.foreground)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.5),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5.0),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                ),
                child: Text('${leverage.toStringAsFixed(0)}x', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: colors.primary,
              inactiveTrackColor: colors.muted,
              thumbColor: colors.primary,
              overlayColor: colors.primary.withValues(alpha: 0.12),
              trackHeight: 3.0,
            ),
            child: Slider(
              value: leverage.clamp(1.0, maxLeverage),
              min: 1.0,
              max: maxLeverage,
              divisions: (maxLeverage - 1).toInt().clamp(1, 500),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Forex Lot Size Selector ----
class _ForexLotSelector extends StatelessWidget {
  final TextEditingController ctrl;
  final ThemePalette colors;
  final VoidCallback onChanged;

  const _ForexLotSelector({
    required this.ctrl,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick lot presets
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            _lotPreset('0.01', 'Micro', colors),
            _lotPreset('0.1', 'Mini', colors),
            _lotPreset('1.0', 'Standard', colors),
          ],
        ),
        const SizedBox(height: 10.0),
        // Custom lot input
        Container(
          decoration: BoxDecoration(color: colors.muted.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8.0)),
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: colors.foreground, fontSize: 16.0, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'Lots (e.g. 0.01 = Micro)',
              hintStyle: TextStyle(color: colors.mutedForeground.withValues(alpha: 0.6)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
              suffixText: 'lots',
              suffixStyle: TextStyle(color: colors.mutedForeground, fontSize: 12.0, fontWeight: FontWeight.w600),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }

  Widget _lotPreset(String value, String label, ThemePalette colors) {
    final isActive = ctrl.text == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ctrl.text = value;
        onChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isActive ? colors.primary : colors.card,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: isActive ? colors.primary : colors.border),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: isActive ? colors.primaryForeground : colors.foreground)),
            Text(label, style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w600, color: isActive ? colors.primaryForeground.withValues(alpha: 0.7) : colors.mutedForeground)),
          ],
        ),
      ),
    );
  }
}
