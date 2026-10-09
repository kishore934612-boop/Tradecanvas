/// Onboarding — Trader profile selection & Candle Loading screen.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app/components/ui.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/instrument.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/providers/market_data_provider.dart';
import 'package:app/screens/main_tabs_screen.dart';
import 'package:app/utils/haptics.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  // Selected Profile Data
  String _traderType = 'Intraday';
  final Set<String> _favCoins = {'BTCUSDT', 'ETHUSDT', 'SOLUSDT'};
  Timeframe _defaultTimeframe = Timeframe.h1;
  String _username = '';
  final TextEditingController _usernameController = TextEditingController();

  bool _isSettingUp = false;
  bool _showNameError = false;

  final List<String> _availableCoins = const [
    'BTCUSDT',
    'ETHUSDT',
    'SOLUSDT',
    'BNBUSDT',
    'XRPUSDT',
    'ADAUSDT',
    'DOGEUSDT',
    'PEPEUSDT',
    'AVAXUSDT',
    'LINKUSDT',
  ];

  @override
  void dispose() {
    _pages.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _next() {
    Haptics.selection();
    // Validate mandatory Name step (index 1)
    if (_index == 1 && _username.trim().isEmpty) {
      Haptics.vibrate();
      setState(() => _showNameError = true);
      return;
    }
    setState(() => _showNameError = false);

    if (_index < 4) {
      _pages.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
      return;
    }
    _startCanvasSetup();
  }

  void _startCanvasSetup() {
    setState(() => _isSettingUp = true);
  }

  void _toggleCoin(String coin) {
    Haptics.selection();
    setState(() {
      if (_favCoins.contains(coin)) {
        if (_favCoins.length > 1) _favCoins.remove(coin);
      } else {
        if (_favCoins.length < 5) _favCoins.add(coin);
      }
    });
  }

  void _finish() {
    final appState = context.read<AppState>();
    final marketData = context.read<MarketDataProvider>();

    // Update user profile preferences
    if (_username.trim().isNotEmpty) {
      appState.updateDisplayName(_username.trim());
    }
    appState.setTraderType(_traderType);
    appState.setFavoriteCoins(_favCoins.toList());
    appState.setDefaultTimeframe(_defaultTimeframe.apiValue);
    appState.completeOnboarding();

    // Sync selected favourite coins directly as user's active watchlist coins
    unawaited(marketData.replaceWatchlist(_favCoins.toList()));

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainTabsScreen(startTour: true),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (_isSettingUp) {
      return Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: _CandleLoadingScreen(colors: colors, onComplete: _finish),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.candlestick_chart_rounded,
                      size: 20,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'TradeCanvas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),

            // Step Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: List.generate(5, (i) {
                  final active = i <= _index;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: active
                            ? colors.primary
                            : colors.border.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Page View — swipe gesture disabled; pages step via Continue/Back buttons.
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) {
                  Haptics.selection();
                  setState(() => _index = i);
                },
                children: [
                  _buildWelcomePage(colors),
                  _buildUserNamePage(colors),
                  _buildTraderTypePage(colors),
                  _buildFavCoinsPage(colors),
                  _buildTimeframePage(colors),
                ],
              ),
            ),

            // Bottom Navigation Row
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_index > 0)
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: colors.foreground,
                      ),
                      onPressed: () {
                        Haptics.selection();
                        _pages.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  const Spacer(),
                  Builder(
                    builder: (context) {
                      final isNameInvalid = _index == 1 && _username.trim().isEmpty;
                      return ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isNameInvalid
                              ? colors.primary.withValues(alpha: 0.5)
                              : colors.primary,
                          foregroundColor: colors.primaryForeground,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _index == 4 ? 'Set Up Canvas' : 'Continue',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PAGES
  // ============================================================

  Widget _buildWelcomePage(ThemePalette colors) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.analytics_rounded,
              size: 64,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Welcome to TradeCanvas',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: colors.foreground,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Institutional-grade technical analysis, real-time market streams & custom candle engines built for precision traders.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: colors.mutedForeground,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Technical Analysis Disclaimer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Technical Analysis Tool Only',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'TradeCanvas is exclusively a technical analysis and charting platform. It does not provide financial advice, broker execution, or investment recommendations.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.mutedForeground,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTraderTypePage(ThemePalette colors) {
    final types = [
      {
        'title': 'Scalp Trader',
        'desc': 'Ultra fast executions on 1m – 5m timeframes.',
        'icon': Icons.flash_on_rounded,
      },
      {
        'title': 'Intraday Trader',
        'desc': 'Capturing day moves on 15m – 1h charts.',
        'icon': Icons.access_time_filled_rounded,
      },
      {
        'title': 'Swing Trader',
        'desc': 'Multi-day momentum trends on 4h – 1D charts.',
        'icon': Icons.trending_up_rounded,
      },
      {
        'title': 'Position Trader',
        'desc': 'Macro trend positioning on 1D – 1W charts.',
        'icon': Icons.public_rounded,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'STEP 2 OF 4',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'What type of trader are you?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tailor default chart layouts for your style.',
            style: TextStyle(fontSize: 12, color: colors.mutedForeground),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              itemCount: types.length,
              itemBuilder: (context, index) {
                final item = types[index];
                final selected = _traderType == item['title'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      Haptics.selection();
                      setState(() => _traderType = item['title'] as String);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.primary.withValues(alpha: 0.12)
                            : colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? colors.primary
                              : colors.border.withValues(alpha: 0.4),
                          width: selected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? colors.primary
                                  : colors.border.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item['icon'] as IconData,
                              size: 16,
                              color: selected
                                  ? Colors.white
                                  : colors.foreground,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] as String,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: colors.foreground,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  item['desc'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.mutedForeground,
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavCoinsPage(ThemePalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'STEP 3 OF 4',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_favCoins.length}/5 Selected',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Favourite Coins',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select up to 5 coins for your quick dashboard.',
            style: TextStyle(fontSize: 12, color: colors.mutedForeground),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _availableCoins.length,
              itemBuilder: (context, index) {
                final coin = _availableCoins[index];
                final base = coin.replaceAll('USDT', '');
                final selected = _favCoins.contains(coin);

                return InkWell(
                  onTap: () => _toggleCoin(coin),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.primary.withValues(alpha: 0.12)
                          : colors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? colors.primary
                            : colors.border.withValues(alpha: 0.4),
                        width: selected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        SymbolAvatar(
                          label: base,
                          color: colors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            base,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colors.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframePage(ThemePalette colors) {
    const tfs = Timeframe.values;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'STEP 4 OF 4',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: colors.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Default Timeframe',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose your preferred primary chart interval.',
            style: TextStyle(fontSize: 12, color: colors.mutedForeground),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tf in tfs)
                ChoiceChip(
                  showCheckmark: false,
                  label: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(tf.label),
                  ),
                  selected: _defaultTimeframe == tf,
                  selectedColor: colors.primary,
                  backgroundColor: colors.card,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _defaultTimeframe == tf
                        ? colors.primaryForeground
                        : colors.foreground,
                  ),
                  onSelected: (_) {
                    Haptics.selection();
                    setState(() => _defaultTimeframe = tf);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserNamePage(ThemePalette colors) {
    final bool hasError = _showNameError && _username.trim().isEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'STEP 1 OF 4',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.negative.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'REQUIRED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colors.negative,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 48,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'What should we call you?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: colors.foreground,
                  letterSpacing: -0.4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Enter your display name to personalize your trading profile.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.mutedForeground,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _usernameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.foreground,
              ),
              decoration: InputDecoration(
                hintText: 'e.g. Alex Trader',
                hintStyle: TextStyle(
                  color: colors.mutedForeground.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.badge_rounded,
                  color: hasError ? colors.negative : colors.primary,
                ),
                filled: true,
                fillColor: colors.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: hasError
                        ? colors.negative
                        : colors.border.withValues(alpha: 0.6),
                    width: hasError ? 1.5 : 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: hasError ? colors.negative : colors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _username = val;
                  if (val.trim().isNotEmpty) {
                    _showNameError = false;
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            if (hasError)
              Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: colors.negative,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Display name is required to continue.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.negative,
                    ),
                  ),
                ],
              )
            else
              Text(
                'Your name will be displayed on your trading profile.',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.mutedForeground.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CANDLE LOADING PROGRESS SCREEN
// ============================================================

class _CandleLoadingScreen extends StatefulWidget {
  final ThemePalette colors;
  final VoidCallback onComplete;

  const _CandleLoadingScreen({required this.colors, required this.onComplete});

  @override
  State<_CandleLoadingScreen> createState() => _CandleLoadingScreenState();
}

class _CandleLoadingScreenState extends State<_CandleLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _progressTimer;
  double _progress = 0.0;
  String _statusText = 'Setting up your canvas…';

  final List<_FakeCandle> _candles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _generateFakeCandles();
    _startProgress();
  }

  void _generateFakeCandles() {
    double base = 100.0;
    for (int i = 0; i < 24; i++) {
      final change = (_random.nextDouble() - 0.48) * 4.0;
      final open = base;
      final close = open + change;
      final high = math.max(open, close) + _random.nextDouble() * 2.0;
      final low = math.min(open, close) - _random.nextDouble() * 2.0;
      _candles.add(_FakeCandle(open, close, high, low));
      base = close;
    }
  }

  void _startProgress() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      setState(() {
        _progress += 0.009; // ~5.5 seconds total smooth loading sequence
        if (_progress > 0.25 && _progress < 0.55) {
          _statusText = 'Configuring market indicators…';
        } else if (_progress >= 0.55 && _progress < 0.88) {
          _statusText = 'Syncing Binance websocket data…';
        } else if (_progress >= 0.88) {
          _statusText = 'Canvas ready!';
        }

        if (_progress >= 1.0) {
          _progressTimer?.cancel();
          widget.onComplete();
        }
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Live Candlestick Progress Animation Box
          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border.withValues(alpha: 0.6)),
              boxShadow: colors.cardShadow,
            ),
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _CandleProgressPainter(
                    candles: _candles,
                    progress: _progress.clamp(0.0, 1.0),
                    bullishColor: colors.positive,
                    bearishColor: colors.negative,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          // Status & Percentage
          Text(
            _statusText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: colors.border.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Technical Analysis & Charting Tool Only',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.mutedForeground.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          const Spacer(),
        ],
      ),
    );
  }
}

class _FakeCandle {
  final double open;
  final double close;
  final double high;
  final double low;
  const _FakeCandle(this.open, this.close, this.high, this.low);
}

class _CandleProgressPainter extends CustomPainter {
  final List<_FakeCandle> candles;
  final double progress;
  final Color bullishColor;
  final Color bearishColor;

  _CandleProgressPainter({
    required this.candles,
    required this.progress,
    required this.bullishColor,
    required this.bearishColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final visibleCount = (candles.length * progress).ceil();
    final candleW = size.width / candles.length;

    double minP = double.infinity;
    double maxP = -double.infinity;
    for (final c in candles) {
      minP = math.min(minP, c.low);
      maxP = math.max(maxP, c.high);
    }
    final span = math.max(1.0, maxP - minP);

    for (int i = 0; i < visibleCount; i++) {
      final c = candles[i];
      final isUp = c.close >= c.open;
      final color = isUp ? bullishColor : bearishColor;
      final paint = Paint()..color = color;

      final x = i * candleW + candleW / 2;
      final highY = size.height - ((c.high - minP) / span) * size.height;
      final lowY = size.height - ((c.low - minP) / span) * size.height;
      final openY = size.height - ((c.open - minP) / span) * size.height;
      final closeY = size.height - ((c.close - minP) / span) * size.height;

      // Wick
      canvas.drawRect(Rect.fromLTRB(x - 1.0, highY, x + 1.0, lowY), paint);

      // Body
      final top = math.min(openY, closeY);
      final bot = math.max(openY, closeY);
      final bodyH = math.max(2.0, bot - top);
      final bodyW = math.max(2.0, candleW * 0.7);

      canvas.drawRect(Rect.fromLTWH(x - bodyW / 2, top, bodyW, bodyH), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CandleProgressPainter oldDelegate) => true;
}
