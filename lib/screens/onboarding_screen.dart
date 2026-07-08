import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/user_profile.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/utils/formatters.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _step = 0;

  Experience _experience = Experience.beginner;
  final Set<String> _markets = {'crypto'};
  TradingStyle _style = TradingStyle.dayTrading;
  final String _currency = '\$';
  double _capital = 100000;
  final TextEditingController _customCapital = TextEditingController();

  static const int _stepCount = 3;

  @override
  void dispose() {
    _pageController.dispose();
    _customCapital.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_step < _stepCount - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  bool get _canProceed {
    if (_step == 2) return _capital > 0;
    return true;
  }

  void _finish() {
    final appState = context.read<AppState>();
    final trading = context.read<TradingProvider>();
    appState.completeOnboarding(
      experience: _experience,
      markets: _markets,
      style: _style,
      startingCapital: _capital,
      currencySymbol: _currency,
    );
    trading.applyStartingCapital(_capital);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress + brand
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
              child: Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      onPressed: _back,
                      icon: Icon(Icons.arrow_back_rounded, color: colors.foreground),
                    )
                  else
                    const SizedBox(width: 48.0),
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (r) => colors.primaryGradient.createShader(r),
                      child: const Text(
                        'TradeVerse',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48.0),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: List.generate(_stepCount, (i) {
                  final active = i <= _step;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 4.0,
                      margin: const EdgeInsets.symmetric(horizontal: 3.0),
                      decoration: BoxDecoration(
                        gradient: active ? colors.primaryGradient : null,
                        color: active ? null : colors.border,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _experienceStep(colors),
                  _styleStep(colors),
                  _capitalStep(colors),
                ],
              ),
            ),
            // CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 8.0),
              child: SizedBox(
                width: double.infinity,
                child: InkWell(
                  onTap: _canProceed ? _next : null,
                  borderRadius: BorderRadius.circular(10.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    decoration: BoxDecoration(
                      gradient: _canProceed ? colors.primaryGradient : null,
                      color: _canProceed ? null : colors.muted,
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: _canProceed ? colors.glowShadow : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _step == _stepCount - 1 ? 'Start Trading' : 'Continue',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: _canProceed ? (colors.brightness == Brightness.dark ? Colors.black : Colors.white) : colors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Disclaimer
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14.0, color: colors.mutedForeground.withValues(alpha: 0.7)),
                  const SizedBox(width: 6.0),
                  Flexible(
                    child: Text(
                      'No real money is used. All trades are simulated with virtual currency.',
                      style: TextStyle(fontSize: 11.0, color: colors.mutedForeground.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepScaffold(String title, String subtitle, List<Widget> children) {
    final colors = AppColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 26.0, fontWeight: FontWeight.bold, color: colors.foreground, letterSpacing: -0.5)),
          const SizedBox(height: 6.0),
          Text(subtitle, style: TextStyle(fontSize: 14.0, color: colors.mutedForeground, height: 1.4)),
          const SizedBox(height: 24.0),
          ...children,
        ],
      ),
    );
  }

  Widget _selectCard({required String title, String? subtitle, required bool active, required VoidCallback onTap, IconData? icon}) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(18.0),
        decoration: BoxDecoration(
          color: active ? colors.primary.withValues(alpha: 0.12) : colors.card,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: active ? colors.primary : colors.border, width: active ? 1.6 : 0.8),
          boxShadow: active ? colors.glowShadow : colors.cardShadow,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: active ? colors.primary : colors.mutedForeground, size: 24.0),
              const SizedBox(width: 14.0),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3.0),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: colors.mutedForeground, height: 1.3)),
                  ],
                ],
              ),
            ),
            if (active) Icon(Icons.check_circle_rounded, color: colors.primary, size: 22.0),
          ],
        ),
      ),
    );
  }

  Widget _experienceStep(ThemePalette colors) {
    return _stepScaffold('Your experience', 'We tailor guidance and defaults to your level.', [
      _selectCard(title: 'Beginner', subtitle: 'New to trading, learning the ropes.', icon: Icons.school_rounded, active: _experience == Experience.beginner, onTap: () => setState(() => _experience = Experience.beginner)),
      _selectCard(title: 'Intermediate', subtitle: 'Comfortable with charts and orders.', icon: Icons.insights_rounded, active: _experience == Experience.intermediate, onTap: () => setState(() => _experience = Experience.intermediate)),
      _selectCard(title: 'Advanced', subtitle: 'Experienced with leverage and risk.', icon: Icons.workspace_premium_rounded, active: _experience == Experience.advanced, onTap: () => setState(() => _experience = Experience.advanced)),
    ]);
  }



  Widget _styleStep(ThemePalette colors) {
    return _stepScaffold('Preferred style', 'This sets sensible defaults for leverage and holding time.', [
      _selectCard(title: 'Scalping', subtitle: 'Quick in-and-out, seconds to minutes.', icon: Icons.bolt_rounded, active: _style == TradingStyle.scalping, onTap: () => setState(() => _style = TradingStyle.scalping)),
      _selectCard(title: 'Day Trading', subtitle: 'Open and close within the day.', icon: Icons.today_rounded, active: _style == TradingStyle.dayTrading, onTap: () => setState(() => _style = TradingStyle.dayTrading)),
      _selectCard(title: 'Swing Trading', subtitle: 'Hold for days to weeks.', icon: Icons.waves_rounded, active: _style == TradingStyle.swingTrading, onTap: () => setState(() => _style = TradingStyle.swingTrading)),
      _selectCard(title: 'Position Trading', subtitle: 'Long-term, weeks to months.', icon: Icons.timeline_rounded, active: _style == TradingStyle.positionTrading, onTap: () => setState(() => _style = TradingStyle.positionTrading)),
    ]);
  }

  Widget _capitalStep(ThemePalette colors) {
    final presets = [10000.0, 50000.0, 100000.0];
    return _stepScaffold('Virtual capital', 'How much practice capital to start with? This is paper money.', [
      ...presets.map((p) {
        final active = _capital == p && _customCapital.text.isEmpty;
        return _selectCard(
          title: '$_currency${_fmt(p)}',
          active: active,
          onTap: () => setState(() {
            _capital = p;
            _customCapital.clear();
          }),
        );
      }),
      const SizedBox(height: 4.0),
      Text('Custom amount', style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: colors.mutedForeground)),
      const SizedBox(height: 8.0),
      Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: colors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            Text(_currency, style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: colors.foreground)),
            const SizedBox(width: 8.0),
            Expanded(
              child: TextField(
                controller: _customCapital,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: colors.foreground),
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  hintStyle: TextStyle(color: colors.mutedForeground.withValues(alpha: 0.6)),
                  border: InputBorder.none,
                ),
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  setState(() => _capital = parsed != null && parsed > 0 ? parsed : 0);
                },
              ),
            ),
          ],
        ),
      ),
    ]);
  }



  String _fmt(double v) {
    final old = appCurrency;
    appCurrency = '';
    final s = formatCurrency(v);
    appCurrency = old;
    return s;
  }
}
