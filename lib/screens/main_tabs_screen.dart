import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/constants/colors.dart';
import 'package:app/screens/learn_screen.dart';
import 'package:app/screens/portfolio_screen.dart';
import 'package:app/screens/markets_screen.dart';
import 'package:app/screens/trade_screen.dart';
import 'package:app/screens/more_screen.dart';

final GlobalKey<MainTabsScreenState> mainTabsKey = GlobalKey<MainTabsScreenState>();

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => MainTabsScreenState();
}

class MainTabsScreenState extends State<MainTabsScreen> {
  int _currentIndex = 0;
  String? _selectedTradeSymbol;

  void selectTab(int index, {String? symbol}) {
    if (symbol != null) {
      setState(() {
        _selectedTradeSymbol = symbol;
      });
    }
    setState(() {
      _currentIndex = index;
    });
  }

  /// Opens the Trade terminal preloaded with [symbol].
  void openTradeWith(String symbol) => selectTab(2, symbol: symbol);

  String? consumeSelectedSymbol() {
    final sym = _selectedTradeSymbol;
    _selectedTradeSymbol = null;
    return sym;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final List<Widget> screens = [
      const DashboardScreen(),
      const MarketsScreen(),
      const TradeScreen(),
      const LearnScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: colors.background,
      extendBody: false,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(top: BorderSide(color: colors.border, width: 1.0)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56.0,
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                HapticFeedback.lightImpact();
                selectTab(index);
              },
              backgroundColor: Colors.transparent,
              selectedItemColor: colors.brightness == Brightness.dark ? colors.primary : colors.tint,
              unselectedItemColor: colors.mutedForeground.withValues(alpha: 0.8),
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 10.0,
              unselectedFontSize: 10.0,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.2),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
              elevation: 0,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.space_dashboard_outlined, size: 22.0), activeIcon: Icon(Icons.space_dashboard_rounded, size: 22.0), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.show_chart_outlined, size: 22.0), activeIcon: Icon(Icons.show_chart, size: 22.0), label: 'Markets'),
                BottomNavigationBarItem(icon: Icon(Icons.candlestick_chart_outlined, size: 22.0), activeIcon: Icon(Icons.candlestick_chart, size: 22.0), label: 'Trade'),
                BottomNavigationBarItem(icon: Icon(Icons.school_outlined, size: 22.0), activeIcon: Icon(Icons.school, size: 22.0), label: 'Learn'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded, size: 22.0), activeIcon: Icon(Icons.person_rounded, size: 22.0), label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
