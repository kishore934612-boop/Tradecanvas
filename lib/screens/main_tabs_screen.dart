/// Root tab shell: Dashboard, Chart, Settings.
///
/// The Chart tab reopens the last charted symbol. Tabs are kept alive in an
/// IndexedStack so switching away and back does not refetch candles or lose
/// zoom position.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app/constants/colors.dart';
import 'package:app/models/instrument.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/screens/chart_screen.dart';
import 'package:app/screens/dashboard_screen.dart';
import 'package:app/screens/settings_screen.dart';
import 'package:app/services/symbol_registry.dart';
import 'package:app/utils/haptics.dart';

class MainTabsScreen extends StatefulWidget {
  final bool startTour;

  const MainTabsScreen({super.key, this.startTour = false});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _index = 0;
  bool _isFullscreen = false;

  late final Instrument _initialChartInstrument;
  late final PageController _pageController;
  final GlobalKey<NavigatorState> _settingsNavKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final registry = context.read<SymbolRegistry>();
    _initialChartInstrument = registry.resolve(appState.lastSymbol);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _select(int next) {
    if (next == _index) return;
    Haptics.selection();
    setState(() => _index = next);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _onSwipePage(int next) {
    if (next == _index) return;
    Haptics.selection();
    setState(() => _index = next);
  }

  void _setFullscreen(bool full) {
    if (_isFullscreen == full) return;
    setState(() => _isFullscreen = full);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. If a sub-route on root Navigator (or modal/dialog) can pop, pop it.
        final rootNav = Navigator.of(context, rootNavigator: true);
        if (rootNav.canPop()) {
          rootNav.pop();
          return;
        }

        // 2. If nested settings tab Navigator has a stacked screen (e.g. Chart Customization), pop it.
        if (_settingsNavKey.currentState?.canPop() ?? false) {
          _settingsNavKey.currentState?.pop();
          return;
        }

        // 3. If currently on Chart (tab 1) or Settings (tab 2), navigate back to Dashboard (tab 0).
        if (_index != 0) {
          _select(0);
          return;
        }

        // 4. On Dashboard with no open sub-routes: exit app cleanly.
        await SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        // PageView with NeverScrollableScrollPhysics so screen navigation swipe
        // gesture is disabled; tabs are navigated exclusively via bottom bar taps.
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: _onSwipePage,
          // Each page is wrapped in _KeepAlivePage so swiping away and back
          // does not rebuild it — PageView, unlike the previous IndexedStack,
          // disposes off-screen pages by default, which would otherwise refetch
          // candles and lose chart zoom/scroll position on every swipe.
          children: [
            const _KeepAlivePage(child: DashboardScreen()),
            _KeepAlivePage(
              child: ChartScreen(
                instrument: _initialChartInstrument,
                showBackButton: false,
                onFullscreenChanged: _setFullscreen,
              ),
            ),
            _KeepAlivePage(
              child: Navigator(
                key: _settingsNavKey,
                onGenerateRoute: (settings) {
                  return MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  );
                },
              ),
            ),
          ],
        ),
      bottomNavigationBar: _isFullscreen
          ? null
          : Container(
              decoration: BoxDecoration(
                color: colors.card,
                border: Border(
                  top: BorderSide(color: colors.border.withValues(alpha: 0.6)),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _index,
                onTap: _select,
                backgroundColor: Colors.transparent,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: colors.primary,
                unselectedItemColor: colors.mutedForeground,
                selectedLabelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.space_dashboard_outlined, size: 22),
                    activeIcon: Icon(Icons.space_dashboard_rounded, size: 22),
                    label: 'Dashboard',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.candlestick_chart_outlined, size: 22),
                    activeIcon: Icon(Icons.candlestick_chart_rounded, size: 22),
                    label: 'Chart',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline_rounded, size: 22),
                    activeIcon: Icon(Icons.person_rounded, size: 22),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

/// Keeps a [PageView] child's state alive when it scrolls off-screen, so
/// switching tabs by swipe behaves the same as the previous IndexedStack:
/// no refetching, no lost scroll/zoom position.
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
