/// Chart screen — the main charting surface for one instrument.
///
/// Owns a [ChartController] and a [DrawingController] for the lifetime of the
/// screen, and persists the timeframe/indicator/style choice per symbol so the
/// chart reopens exactly as it was left.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app/components/chart/chart_painter.dart' show ChartStyle;
import 'package:app/components/chart/chart_quick_dropdown_menu.dart';
import 'package:app/components/chart/chart_toolbar.dart';
import 'package:app/components/chart/chart_view.dart';
import 'package:app/components/chart/indicator_sheet.dart';
import 'package:app/analysis_tools/models/analysis_type.dart';
import 'package:app/components/chart/smc_sheet.dart';
import 'package:app/components/chart/strategy_sheet.dart';
import 'package:app/components/ui.dart';
import 'package:app/constants/colors.dart';
import 'package:app/core/di/service_locator.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/data/providers/market/binance_provider.dart';
import 'package:app/domain/repositories/chart_prefs_repository.dart';
import 'package:app/domain/repositories/drawing_repository.dart';
import 'package:app/engine/chart_controller.dart';
import 'package:app/engine/drawing_controller.dart';
import 'package:app/engine/magnetic_snap.dart';
import 'package:app/engine/smc_engine.dart';
import 'package:app/engine/smc_filter.dart';
import 'package:app/engine/strategy_engine.dart';
import 'package:app/models/drawing.dart';
import 'package:app/models/instrument.dart';
import 'package:app/models/smc_type.dart';
import 'package:app/models/strategy_type.dart';
import 'package:app/models/user_profile.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/providers/market_data_provider.dart';
import 'package:app/screens/replay_screen.dart';
import 'package:app/screens/symbol_search_screen.dart';
import 'package:app/services/persistence/persistence_service.dart';
import 'package:app/services/symbol_registry.dart';
import 'package:app/utils/haptics.dart';

class ChartScreen extends StatefulWidget {
  final Instrument instrument;
  final String? initialTimeframe;
  final bool showBackButton;
  final ValueChanged<bool>? onFullscreenChanged;

  ChartScreen({
    super.key,
    Instrument? instrument,
    String? symbol,
    this.initialTimeframe,
    this.showBackButton = true,
    this.onFullscreenChanged,
  }) : instrument = instrument ??
            (symbol != null
                ? Instrument.placeholder(symbol)
                : Instrument.placeholder('BTCUSDT'));

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  late final ChartPrefsRepository _prefsRepo;

  late ChartController _chart;
  late DrawingController _drawings;
  late Instrument _instrument;

  Set<StrategyType> _enabledStrategies = {};
  StrategySettings _strategySettings = const StrategySettings();
  List<StrategySignal> _strategySignals = [];

  Set<SmcType> _enabledSmc = {};
  SmcSettings _smcSettings = const SmcSettings();
  List<SmcStructure> _smcStructures = [];

  final GlobalKey<ChartViewRefState> _chartViewKey =
      GlobalKey<ChartViewRefState>();

  ChartStyle _style = ChartStyle.candles;
  bool _fullscreen = false;
  bool _isScrolledAway = false;

  @override
  void initState() {
    super.initState();
    _instrument = widget.instrument;
    _prefsRepo = serviceLocator<ChartPrefsRepository>();

    final binanceProvider = serviceLocator<BinanceProvider>();
    final logger = serviceLocator<Logger>();

    _chart = ChartController(
      provider: binanceProvider,
      logger: logger,
      instrument: _instrument,
    );

    final drawingRepo = serviceLocator<DrawingRepository>();
    _drawings = DrawingController(
      repository: drawingRepo,
      logger: logger,
      symbol: _instrument.symbol,
    );

    _chart.addListener(_onChartDataChanged);

    _chart.load();
    if (widget.initialTimeframe != null && widget.initialTimeframe!.isNotEmpty) {
      _chart.setTimeframe(Timeframe.fromApiValue(widget.initialTimeframe!));
    }
    _drawings.load();
    _loadSavedPreferences();
    _loadSavedStrategies();
    _loadSavedSmc();
  }

  @override
  void dispose() {
    _chart.removeListener(_onChartDataChanged);
    _chart.dispose();
    _drawings.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPreferences() async {
    try {
      final savedPrefs = await _prefsRepo.get(_instrument.symbol);
      if (!mounted) return;

      final profile = context.read<AppState>().profile;
      final tfString = savedPrefs?.timeframe ?? profile.defaultTimeframe;
      final tf = Timeframe.fromApiValue(tfString);

      final chartStyle = profile.chartType == ChartTypePref.line
          ? ChartStyle.line
          : ChartStyle.candles;

      setState(() {
        _style = chartStyle;
      });

      unawaited(_chart.setTimeframe(tf));
    } catch (e) {
      Logger.instance.error('Failed to load chart preferences: $e');
    }
  }

  void _setTimeframe(Timeframe tf) {
    Haptics.selection();
    _chart.setTimeframe(tf);
    _prefsRepo.save(
      ChartPrefs(symbol: _instrument.symbol, timeframe: tf.apiValue),
    );
  }

  void _toggleStyle() {
    Haptics.selection();
    setState(() {
      _style = _style == ChartStyle.candles
          ? ChartStyle.line
          : ChartStyle.candles;
    });
  }

  void _openIndicators() {
    Haptics.selection();
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
          child: IndicatorSheet(
            enabledIndicators: _chart.enabledIndicators,
            onToggleIndicator: (type) {
              setState(() {
                _chart.toggleIndicator(type);
              });
            },
            enabledStrategies: _enabledStrategies,
            onToggleStrategy: _toggleStrategy,
            strategySettings: _strategySettings,
            onStrategySettingsChanged: _updateStrategySettings,
            enabledSmc: _enabledSmc,
            onToggleSmc: _toggleSmc,
            smcSettings: _smcSettings,
            onSmcSettingsChanged: _updateSmcSettings,
            indicatorStyles: _chart.indicatorStyles,
            onIndicatorStyleChanged: (type, style) {
              setState(() {
                _chart.setIndicatorStyle(type, style);
              });
            },
          ),
        ),
      ),
    );
  }





  void _onChartDataChanged() {
    _recomputeStrategies();
    _recomputeSmc();
  }

  Future<void> _loadSavedStrategies() async {
    try {
      if (!serviceLocator.isRegistered<PersistenceService>()) return;
      final p = serviceLocator<PersistenceService>();
      final list = await p.readStringList('enabled_strategies');
      if (list != null) {
        _enabledStrategies = list.map(StrategyType.fromId).toSet();
      }
      final jsonStr = await p.readString('strategy_settings');
      if (jsonStr != null) {
        _strategySettings = StrategySettings.fromJson(
            jsonDecode(jsonStr) as Map<String, dynamic>);
      }
      _recomputeStrategies();
    } catch (e) {
      Logger.instance.error('Failed to load strategy preferences: $e');
    }
  }

  Future<void> _loadSavedSmc() async {
    try {
      if (!serviceLocator.isRegistered<PersistenceService>()) return;
      final p = serviceLocator<PersistenceService>();
      final list = await p.readStringList('enabled_smc');
      if (list != null) {
        _enabledSmc = list.map(SmcType.fromId).toSet();
      }
      final jsonStr = await p.readString('smc_settings');
      if (jsonStr != null) {
        _smcSettings =
            SmcSettings.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      }
      _recomputeSmc();
    } catch (e) {
      Logger.instance.error('Failed to load SMC preferences: $e');
    }
  }

  void _recomputeStrategies() {
    if (_enabledStrategies.isEmpty) {
      if (_strategySignals.isNotEmpty) {
        setState(() {
          _strategySignals = [];
        });
      }
      return;
    }
    final signals = StrategyEngine.evaluate(
      candles: _chart.candles,
      activeStrategies: _enabledStrategies,
      settings: _strategySettings,
      indicators: _chart.indicators,
    );
    if (mounted) {
      setState(() {
        _strategySignals = signals;
      });
    }
  }

  void _recomputeSmc() {
    if (_enabledSmc.isEmpty) {
      if (_smcStructures.isNotEmpty) {
        setState(() {
          _smcStructures = [];
        });
      }
      return;
    }
    final rawStructures = SmcEngine.evaluate(
      candles: _chart.candles,
      activeOverlays: _enabledSmc,
      settings: _smcSettings,
    );
    final filtered = SmcFilter.filterAndMerge(
      structures: rawStructures,
      candles: _chart.candles,
      settings: _smcSettings,
    );
    if (mounted) {
      setState(() {
        _smcStructures = filtered;
      });
    }
  }

  void _toggleStrategy(StrategyType type) {
    setState(() {
      if (_enabledStrategies.contains(type)) {
        _enabledStrategies.remove(type);
      } else {
        _enabledStrategies.add(type);
      }
    });
    _recomputeStrategies();
    if (serviceLocator.isRegistered<PersistenceService>()) {
      final p = serviceLocator<PersistenceService>();
      p.writeStringList(
          'enabled_strategies', _enabledStrategies.map((s) => s.name).toList());
    }
  }

  void _toggleSmc(SmcType type) {
    setState(() {
      if (_enabledSmc.contains(type)) {
        _enabledSmc.remove(type);
      } else {
        _enabledSmc.add(type);
      }
    });
    _recomputeSmc();
    if (serviceLocator.isRegistered<PersistenceService>()) {
      final p = serviceLocator<PersistenceService>();
      p.writeStringList('enabled_smc', _enabledSmc.map((s) => s.name).toList());
    }
  }

  void _updateStrategySettings(StrategySettings settings) {
    setState(() {
      _strategySettings = settings;
    });
    _recomputeStrategies();
    if (serviceLocator.isRegistered<PersistenceService>()) {
      final p = serviceLocator<PersistenceService>();
      p.writeString('strategy_settings', jsonEncode(settings.toJson()));
    }
  }

  void _updateSmcSettings(SmcSettings settings) {
    setState(() {
      _smcSettings = settings;
    });
    _recomputeSmc();
    if (serviceLocator.isRegistered<PersistenceService>()) {
      final p = serviceLocator<PersistenceService>();
      p.writeString('smc_settings', jsonEncode(settings.toJson()));
    }
  }

  void _openStrategies() {
    Haptics.selection();
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
          child: StrategySheet(
            enabled: _enabledStrategies,
            onToggle: _toggleStrategy,
            settings: _strategySettings,
            onSettingsChanged: _updateStrategySettings,
          ),
        ),
      ),
    );
  }

  void _openSmc() {
    Haptics.selection();
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
          child: SmcSheet(
            enabled: _enabledSmc,
            onToggle: _toggleSmc,
            settings: _smcSettings,
            onSettingsChanged: _updateSmcSettings,
          ),
        ),
      ),
    );
  }

  void _toggleFullscreen() {
    Haptics.selection();
    setState(() {
      _fullscreen = !_fullscreen;
    });
    widget.onFullscreenChanged?.call(_fullscreen);

    if (_fullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  // ignore: unused_element
  void _showDrawingToolsTray() {
    Haptics.selection();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final colors = AppColors.of(context);

        final appState = context.read<AppState>();
        final profile = appState.profile;

        final categories = [
          (
            name: 'Smart Analysis (SMC)',
            tools: [
              (name: 'Bullish Order Block', icon: Icons.view_headline_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.bullishOrderBlock), active: _drawings.activeAnalysisTool == AnalysisType.bullishOrderBlock, isDestructive: false),
              (name: 'Bearish Order Block', icon: Icons.table_rows_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.bearishOrderBlock), active: _drawings.activeAnalysisTool == AnalysisType.bearishOrderBlock, isDestructive: false),
              (name: 'Bullish FVG', icon: Icons.unfold_more_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.bullishFvg), active: _drawings.activeAnalysisTool == AnalysisType.bullishFvg, isDestructive: false),
              (name: 'Bearish FVG', icon: Icons.unfold_less_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.bearishFvg), active: _drawings.activeAnalysisTool == AnalysisType.bearishFvg, isDestructive: false),
              (name: 'Break of Struct', icon: Icons.call_made_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.bos), active: _drawings.activeAnalysisTool == AnalysisType.bos, isDestructive: false),
              (name: 'Change of Char', icon: Icons.change_circle_outlined, action: () => _drawings.setActiveAnalysisTool(AnalysisType.choch), active: _drawings.activeAnalysisTool == AnalysisType.choch, isDestructive: false),
            ],
          ),
          (
            name: 'Liquidity',
            tools: [
              (name: 'Buy-side Liquidity', icon: Icons.water_drop_outlined, action: () => _drawings.setActiveAnalysisTool(AnalysisType.bsl), active: _drawings.activeAnalysisTool == AnalysisType.bsl, isDestructive: false),
              (name: 'Sell-side Liquidity', icon: Icons.opacity_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.ssl), active: _drawings.activeAnalysisTool == AnalysisType.ssl, isDestructive: false),
              (name: 'Equilibrium (EQ)', icon: Icons.drag_handle_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.equilibrium), active: _drawings.activeAnalysisTool == AnalysisType.equilibrium, isDestructive: false),
            ],
          ),
          (
            name: 'Supply & Demand',
            tools: [
              (name: 'Supply Zone', icon: Icons.arrow_circle_up_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.supplyZone), active: _drawings.activeAnalysisTool == AnalysisType.supplyZone, isDestructive: false),
              (name: 'Demand Zone', icon: Icons.arrow_circle_down_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.demandZone), active: _drawings.activeAnalysisTool == AnalysisType.demandZone, isDestructive: false),
              (name: 'Premium Zone', icon: Icons.vertical_align_top_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.premiumZone), active: _drawings.activeAnalysisTool == AnalysisType.premiumZone, isDestructive: false),
              (name: 'Discount Zone', icon: Icons.vertical_align_bottom_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.discountZone), active: _drawings.activeAnalysisTool == AnalysisType.discountZone, isDestructive: false),
              (name: 'Support Level', icon: Icons.call_received_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.supportZone), active: _drawings.activeAnalysisTool == AnalysisType.supportZone, isDestructive: false),
              (name: 'Resistance Level', icon: Icons.call_made_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.resistanceZone), active: _drawings.activeAnalysisTool == AnalysisType.resistanceZone, isDestructive: false),
            ],
          ),
          (
            name: 'Lines & Rays',
            tools: [
              (name: 'Trend Line', icon: Icons.show_chart_rounded, action: () => _drawings.setActiveTool(DrawingTool.trendline), active: _drawings.activeTool == DrawingTool.trendline, isDestructive: false),
              (name: 'Arrow', icon: Icons.north_east_rounded, action: () => _drawings.setActiveTool(DrawingTool.arrow), active: _drawings.activeTool == DrawingTool.arrow, isDestructive: false),
              (name: 'Horizontal Line', icon: Icons.horizontal_rule_rounded, action: () => _drawings.setActiveTool(DrawingTool.horizontalLine), active: _drawings.activeTool == DrawingTool.horizontalLine, isDestructive: false),
              (name: 'Vertical Line', icon: Icons.more_vert_rounded, action: () => _drawings.setActiveTool(DrawingTool.verticalLine), active: _drawings.activeTool == DrawingTool.verticalLine, isDestructive: false),
            ],
          ),
          (
            name: 'Shapes & Freehand',
            tools: [
              (name: 'Rectangle Box', icon: Icons.rectangle_outlined, action: () => _drawings.setActiveTool(DrawingTool.rectangle), active: _drawings.activeTool == DrawingTool.rectangle, isDestructive: false),
              (name: 'Triangle', icon: Icons.change_history_rounded, action: () => _drawings.setActiveTool(DrawingTool.triangle), active: _drawings.activeTool == DrawingTool.triangle, isDestructive: false),
            ],
          ),
          (
            name: 'Fibonacci & Math',
            tools: [
              (name: 'Fibonacci', icon: Icons.compress_rounded, action: () => _drawings.setActiveTool(DrawingTool.fibRetracement), active: _drawings.activeTool == DrawingTool.fibRetracement, isDestructive: false),
              (name: 'Fib Extension', icon: Icons.timeline_rounded, action: () => _drawings.setActiveTool(DrawingTool.fibExtension), active: _drawings.activeTool == DrawingTool.fibExtension, isDestructive: false),
            ],
          ),
          (
            name: 'Annotations & Measurement',
            tools: [
              (name: 'Text Label', icon: Icons.text_fields_rounded, action: () => _drawings.setActiveTool(DrawingTool.text), active: _drawings.activeTool == DrawingTool.text, isDestructive: false),
              (name: 'Callout Box', icon: Icons.mark_chat_read_rounded, action: () => _drawings.setActiveTool(DrawingTool.callout), active: _drawings.activeTool == DrawingTool.callout, isDestructive: false),
              (name: 'Measurement', icon: Icons.straighten_rounded, action: () => _drawings.setActiveTool(DrawingTool.measurement), active: _drawings.activeTool == DrawingTool.measurement, isDestructive: false),
            ],
          ),
          (
            name: 'Positions & Risk',
            tools: [
              (name: 'Long Position', icon: Icons.trending_up_rounded, action: () => _drawings.setActiveTool(DrawingTool.longPosition), active: _drawings.activeTool == DrawingTool.longPosition, isDestructive: false),
              (name: 'Short Position', icon: Icons.trending_down_rounded, action: () => _drawings.setActiveTool(DrawingTool.shortPosition), active: _drawings.activeTool == DrawingTool.shortPosition, isDestructive: false),
            ],
          ),
          (
            name: 'Chart Utilities',
            tools: [
              (name: 'Crosshair: ${profile.crosshairMode.label}', icon: Icons.center_focus_strong_rounded, action: () => appState.setCrosshairMode(profile.crosshairMode.next), active: profile.crosshairMode != CrosshairMode.free, isDestructive: false),
              (name: profile.crosshairShowLabels ? 'Labels: On' : 'Labels: Off', icon: Icons.subtitles_rounded, action: () => appState.setCrosshairShowLabels(!profile.crosshairShowLabels), active: profile.crosshairShowLabels, isDestructive: false),
              (name: 'Price Marker', icon: Icons.add_chart_rounded, action: () => _promptAddPriceLine(context), active: profile.customPriceLines.isNotEmpty, isDestructive: false),
              (name: profile.autoScale ? 'Auto Scale: On' : 'Auto Scale: Off', icon: Icons.aspect_ratio_rounded, action: () => appState.setAutoScale(!profile.autoScale), active: profile.autoScale, isDestructive: false),
              (name: profile.chartLocked ? 'Chart Locked' : 'Lock Chart', icon: profile.chartLocked ? Icons.lock_rounded : Icons.lock_open_rounded, action: () => appState.setChartLocked(!profile.chartLocked), active: profile.chartLocked, isDestructive: false),
              (name: 'Magnet Snap', icon: Icons.auto_awesome_rounded, action: () => _drawings.cycleMagneticMode(), active: _drawings.magneticMode != MagneticMode.off, isDestructive: false),
              (name: 'Clear All', icon: Icons.delete_outline_rounded, action: () => _drawings.clearSymbol(), active: false, isDestructive: true),
            ],
          ),
        ];

        int selectedCategoryIndex = 0;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final activeCategories = selectedCategoryIndex == -1
                ? categories
                : [categories[selectedCategoryIndex]];

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Drawing & Analysis Tools',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.mutedForeground,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Horizontal Category Switcher Chips Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _CategoryChip(
                          label: 'All',
                          isSelected: selectedCategoryIndex == -1,
                          onTap: () {
                            Haptics.selection();
                            setSheetState(() => selectedCategoryIndex = -1);
                          },
                          colors: colors,
                        ),
                        const SizedBox(width: 6),
                        for (int i = 0; i < categories.length; i++) ...[
                          _CategoryChip(
                            label: categories[i].name,
                            isSelected: selectedCategoryIndex == i,
                            onTap: () {
                              Haptics.selection();
                              setSheetState(() => selectedCategoryIndex = i);
                            },
                            colors: colors,
                          ),
                          if (i < categories.length - 1) const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: activeCategories.length,
                      itemBuilder: (context, catIdx) {
                        final cat = activeCategories[catIdx];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (selectedCategoryIndex == -1)
                              Padding(
                                padding: const EdgeInsets.only(top: 10, bottom: 6),
                                child: Text(
                                  cat.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.25,
                              ),
                              itemCount: cat.tools.length,
                              itemBuilder: (context, toolIdx) {
                                final tool = cat.tools[toolIdx];
                                final isDestructive = tool.isDestructive;
                                final active = tool.active;

                                return InkWell(
                                  onTap: () {
                                    Haptics.selection();
                                    tool.action();
                                    Navigator.pop(ctx);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? colors.primary.withValues(alpha: 0.18)
                                          : colors.card.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDestructive
                                            ? colors.destructive.withValues(alpha: 0.5)
                                            : (active
                                                  ? colors.primary
                                                  : colors.border.withValues(alpha: 0.3)),
                                        width: active ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          tool.icon,
                                          size: 22,
                                          color: isDestructive
                                              ? colors.destructive
                                              : (active
                                                    ? colors.primary
                                                    : colors.foreground),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          tool.name,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: active
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: isDestructive
                                                ? colors.destructive
                                                : (active
                                                      ? colors.primary
                                                      : colors.foreground),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _promptAddPriceLine(BuildContext context) async {
    final appState = context.read<AppState>();
    final colors = AppColors.of(context);
    final market = context.read<MarketDataProvider>();
    final currentPrice = market.priceOf(_instrument.symbol);

    final controller = TextEditingController(
      text: currentPrice > 0 ? currentPrice.toStringAsFixed(2) : '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text(
          'Add Price Marker',
          style: TextStyle(
            color: colors.foreground,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a price level to mark on the chart:',
              style: TextStyle(color: colors.mutedForeground, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(color: colors.foreground),
              decoration: InputDecoration(
                hintText: 'e.g. 65000.00',
                hintStyle: TextStyle(color: colors.mutedForeground),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.primary),
                ),
              ),
            ),
            if (appState.profile.customPriceLines.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active markers (${appState.profile.customPriceLines.length}):',
                    style: TextStyle(
                      color: colors.mutedForeground,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      appState.clearCustomPriceLines();
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'Clear All',
                      style: TextStyle(color: colors.destructive, fontSize: 11),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in appState.profile.customPriceLines)
                    InputChip(
                      label: Text(
                        _instrument.formatPrice(p),
                        style: const TextStyle(fontSize: 10),
                      ),
                      onDeleted: () {
                        appState.removeCustomPriceLine(p);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Add', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final parsed = double.tryParse(result);
      if (parsed != null && parsed > 0) {
        appState.addCustomPriceLine(parsed);
      }
    }
  }

  Future<void> _pickCoin() async {
    final selected = await Navigator.of(context).push<Instrument>(
      MaterialPageRoute(builder: (_) => const SymbolSearchScreen()),
    );
    if (selected == null || selected.symbol == _instrument.symbol) return;
    await _switchToSymbol(selected);
  }

  Future<void> _switchToSymbol(Instrument selected) async {
    if (selected.symbol == _instrument.symbol) return;
    if (!mounted) return;

    setState(() {
      _instrument = selected;
    });

    context.read<AppState>().setLastSymbol(selected.symbol);
    unawaited(_chart.setInstrument(selected));
    unawaited(_drawings.setSymbol(selected.symbol));
    unawaited(_loadSavedPreferences());
  }

  /// Swipe left/right on the header to step to the next/previous watchlist
  /// symbol, matching the same gesture on the Dashboard's featured chart.
  void _swipeSymbol(bool forward) {
    final market = context.read<MarketDataProvider>();
    final watchlist = market.watchlist;
    if (watchlist.length < 2) return;

    final registry = context.read<SymbolRegistry>();
    final currentIndex = watchlist.indexOf(_instrument.symbol);
    final baseIndex = currentIndex < 0 ? 0 : currentIndex;
    final nextIndex = (baseIndex + (forward ? 1 : -1)) % watchlist.length;
    final wrapped = nextIndex < 0 ? nextIndex + watchlist.length : nextIndex;

    Haptics.selection();
    unawaited(_switchToSymbol(registry.resolve(watchlist[wrapped])));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final market = context.watch<MarketDataProvider>();
    final price = market.priceOf(_instrument.symbol);
    final change = market.changeOf(_instrument.symbol);

    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_fullscreen) {
          _toggleFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (!_fullscreen)
                _Header(
                  instrument: _instrument,
                  price: price,
                  change: change,
                  isWatched: market.isWatched(_instrument.symbol),
                  onToggleWatch: () {
                    Haptics.light();
                    market.toggleWatchlist(_instrument.symbol);
                  },
                  onSwitchCoin: _pickCoin,
                  onSwipeSymbol: _swipeSymbol,
                  onOpenReplay: () {
                    Haptics.light();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReplayScreen(instrument: _instrument),
                      ),
                    );
                  },
                  onBack: widget.showBackButton
                      ? () => Navigator.of(context).pop()
                      : null,
                ),

              AnimatedBuilder(
                animation: _chart,
                builder: (context, _) => ChartToolbar(
                  timeframe: _chart.timeframe,
                  onTimeframe: _setTimeframe,
                  style: _style,
                  onToggleStyle: _toggleStyle,
                  onIndicators: _openIndicators,
                  hasActiveIndicators: _chart.enabledIndicators.isNotEmpty,
                  onStrategies: _openStrategies,
                  hasActiveStrategies: _enabledStrategies.isNotEmpty,
                  onSmc: _openSmc,
                  hasActiveSmc: _enabledSmc.isNotEmpty,
                  fullscreen: _fullscreen,
                  onToggleFullscreen: _toggleFullscreen,
                ),
              ),

              Expanded(
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _chart,
                      builder: (context, _) => Padding(
                        padding: const EdgeInsets.only(
                          left: 4,
                          top: 4,
                          bottom: 4,
                        ),
                        child: ChartView(
                          key: _chartViewKey,
                          controller: _chart,
                          drawings: _drawings,
                          style: _style,
                          strategySignals: _strategySignals,
                          strategySettings: _strategySettings,
                          smcStructures: _smcStructures,
                          smcSettings: _smcSettings,
                          onScrolledAwayChanged: (scrolled) {
                            if (_isScrolledAway != scrolled) {
                              setState(() => _isScrolledAway = scrolled);
                            }
                          },
                        ),
                      ),
                    ),

                    // 1. Live Price Reset Button (Only visible when user has scrolled away from live price)
                    if (_isScrolledAway)
                      Positioned(
                        right: 12,
                        bottom: 64,
                        child: FloatingActionButton.small(
                          heroTag: 'reset_view_btn',
                          onPressed: () {
                            Haptics.selection();
                            _chartViewKey.currentState?.resetView();
                          },
                          backgroundColor: colors.primary,
                          foregroundColor: colors.primaryForeground,
                          tooltip: 'Jump to Live Price',
                          child: const Icon(Icons.arrow_forward_rounded, size: 20),
                        ),
                      ),

                    // Animated Dropdown Menu Button on Right Side Bottom
                    Positioned(
                      right: 12,
                      bottom: 16,
                      child: ChartQuickDropdownMenu(
                        onOpenTools: _showDrawingToolsTray,
                      ),
                    ),



                    if (context.watch<AppState>().profile.chartLocked)
                      Positioned(
                        left: 12,
                        bottom: 16,
                        child: GestureDetector(
                          onTap: () {
                            Haptics.selection();
                            context.read<AppState>().setChartLocked(false);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Chart Locked',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Instrument instrument;
  final double? price;
  final double? change;
  final bool isWatched;
  final VoidCallback onToggleWatch;
  final VoidCallback onSwitchCoin;
  final VoidCallback onOpenReplay;
  final VoidCallback? onBack;

  /// Called with `true` for a left-swipe (next symbol) or `false` for a
  /// right-swipe (previous symbol).
  final ValueChanged<bool>? onSwipeSymbol;

  const _Header({
    required this.instrument,
    required this.price,
    required this.change,
    required this.isWatched,
    required this.onToggleWatch,
    required this.onSwitchCoin,
    required this.onOpenReplay,
    this.onBack,
    this.onSwipeSymbol,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isUp = (change ?? 0.0) >= 0;
    final changeColor = isUp ? colors.positive : colors.negative;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 200 || onSwipeSymbol == null) return;
        onSwipeSymbol!(velocity < 0);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(
            bottom: BorderSide(color: colors.border.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: colors.foreground),
                onPressed: onBack,
              ),

            InkWell(
              onTap: onSwitchCoin,
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  SymbolAvatar(
                    label: instrument.symbol,
                    color: colors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            instrument.symbol,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: colors.foreground,
                            ),
                          ),
                          Icon(
                            Icons.unfold_more_rounded,
                            size: 16,
                            color: colors.mutedForeground,
                          ),
                        ],
                      ),
                      Text(
                        '${instrument.base}/${instrument.quote}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            if (price != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price!.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: colors.foreground,
                    ),
                  ),
                  if (change != null)
                    Text(
                      '${isUp ? '+' : ''}${change!.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: changeColor,
                      ),
                    ),
                ],
              ),

            const SizedBox(width: 10),

            IconButton(
              icon: Icon(
                isWatched ? Icons.star_rounded : Icons.star_border_rounded,
                color: isWatched ? colors.primary : colors.mutedForeground,
                size: 22,
              ),
              onPressed: onToggleWatch,
            ),
            IconButton(
              icon: Icon(
                Icons.play_circle_outline_rounded,
                color: colors.primary,
                size: 22,
              ),
              onPressed: onOpenReplay,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemePalette colors;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary
              : colors.card.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.border.withValues(alpha: 0.6),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? colors.primaryForeground : colors.foreground,
          ),
        ),
      ),
    );
  }
}

