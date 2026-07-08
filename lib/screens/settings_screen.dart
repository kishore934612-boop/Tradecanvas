import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/user_profile.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/utils/formatters.dart';
import 'package:app/components/ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final appState = Provider.of<AppState>(context);
    final provider = Provider.of<TradingProvider>(context);
    final profile = appState.profile;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(title: 'Settings', showBackButton: true),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                children: [
          _group(colors, 'Appearance', [
            _settingRow(colors, Icons.dark_mode_outlined, 'Theme Mode', trailing: _themeSelector(context, appState, colors)),
            _divider(colors),
            _customThemeRow(context, appState, colors),
          ]),
          const SizedBox(height: 16.0),
          _group(colors, 'Preferences', [
            _toggleRow(colors, Icons.vibration_rounded, 'Haptic Feedback', profile.hapticsEnabled, (v) => appState.setHaptics(v)),
            _divider(colors),
            _toggleRow(colors, Icons.menu_book_rounded, 'Journal Prompts', profile.journalPromptsEnabled, (v) => appState.setJournalPrompts(v)),
          ]),
          const SizedBox(height: 16.0),
          _group(colors, 'Trading Profile', [
            _settingRow(colors, Icons.school_outlined, 'Experience', value: profile.experience.label, onTap: () => _editExperience(context, appState)),
            _divider(colors),
            _settingRow(colors, Icons.style_outlined, 'Style', value: profile.style.label, onTap: () => _editStyle(context, appState)),
          ]),
          const SizedBox(height: 16.0),
          _group(colors, 'Legal', [
            _settingRow(colors, Icons.privacy_tip_outlined, 'Privacy Policy', onTap: () => _showPrivacyPolicy(context, colors)),
            _divider(colors),
            _settingRow(colors, Icons.gavel_outlined, 'Terms and Conditions', onTap: () => _showTermsAndConditions(context, colors)),
          ]),
          const SizedBox(height: 16.0),
          _group(colors, 'Account', [
            _settingRow(colors, Icons.account_balance_wallet_outlined, 'Starting Capital', value: formatCurrency(provider.startingCapital)),
            _divider(colors),
            _settingRow(colors, Icons.restart_alt_rounded, 'Reset Account', value: '', onTap: () => _confirmReset(context, provider), danger: true),

          ]),
          const SizedBox(height: 20.0),
          Center(child: Text('TradeVerse · Paper trading simulator', style: TextStyle(fontSize: 11.5, color: colors.mutedForeground, fontWeight: FontWeight.bold))),
          const SizedBox(height: 4.0),
          Center(child: Text('Version 1.0.0 (Build 1)', style: TextStyle(fontSize: 11.0, color: colors.mutedForeground.withValues(alpha: 0.7), fontWeight: FontWeight.w600))),
          const SizedBox(height: 4.0),
          Center(child: Text('All capital is virtual. Not financial advice.', style: TextStyle(fontSize: 10.5, color: colors.mutedForeground.withValues(alpha: 0.5)))),
        ],
      ),
    ),
          ],
        ),
      ),
    );
  }

  Widget _group(ThemePalette colors, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 4.0, bottom: 8.0), child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: colors.mutedForeground, letterSpacing: 0.6))),
        GlassCard(padding: EdgeInsets.zero, child: Column(children: children)),
      ],
    );
  }

  Widget _divider(ThemePalette colors) => Divider(height: 1, color: colors.border, indent: 56);

  Widget _settingRow(ThemePalette colors, IconData icon, String title, {String? value, Widget? trailing, VoidCallback? onTap, bool danger = false}) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: danger ? colors.negative : colors.mutedForeground, size: 22.0),
        title: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: danger ? colors.negative : colors.foreground)),
        trailing: trailing ??
            (value != null && value.isNotEmpty
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.mutedForeground)),
                    if (onTap != null) Icon(Icons.chevron_right_rounded, color: colors.mutedForeground),
                  ])
                : (onTap != null ? Icon(Icons.chevron_right_rounded, color: colors.mutedForeground) : null)),
      ),
    );
  }

  Widget _toggleRow(ThemePalette colors, IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: colors.mutedForeground, size: 22.0),
        title: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: colors.foreground)),
        trailing: Switch(value: value, activeThumbColor: colors.primary, onChanged: onChanged),
      ),
    );
  }

  Widget _themeSelector(BuildContext context, AppState appState, ThemePalette colors) {
    final modes = {ThemeMode.system: Icons.brightness_auto_rounded, ThemeMode.light: Icons.light_mode_rounded, ThemeMode.dark: Icons.dark_mode_rounded};
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: modes.entries.map((e) {
        final active = appState.themeMode == e.key;
        return GestureDetector(
          onTap: () => appState.setThemeMode(e.key),
          child: Container(
            margin: const EdgeInsets.only(left: 6.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(color: active ? colors.primary.withValues(alpha: 0.15) : colors.muted, borderRadius: BorderRadius.circular(8.0), border: Border.all(color: active ? colors.primary : Colors.transparent)),
            child: Icon(e.value, size: 18.0, color: active ? colors.primary : colors.mutedForeground),
          ),
        );
      }).toList(),
    );
  }

  Widget _customThemeRow(BuildContext context, AppState appState, ThemePalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: colors.mutedForeground, size: 22.0),
              const SizedBox(width: 14.0),
              Text(
                'Color Theme',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: colors.foreground,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: kThemeOptions.map((opt) {
              final isSelected = appState.themeIndex == opt.index;
              return GestureDetector(
                onTap: () {
                  if (appState.profile.hapticsEnabled) {
                    HapticFeedback.lightImpact();
                  }
                  appState.setThemeIndex(opt.index);
                },
                child: Container(
                  width: 28.0,
                  height: 28.0,
                  margin: const EdgeInsets.only(left: 8.0),
                  decoration: BoxDecoration(
                    color: opt.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? colors.foreground : Colors.transparent,
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: opt.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 4.0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          color: opt.index == 0
                              ? const Color(0xFF090D16)
                              : Colors.white,
                          size: 14.0,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _editExperience(BuildContext context, AppState appState) {
    _pickSheet<Experience>(context, 'Experience', Experience.values, appState.profile.experience, (e) => e.label, (e) => appState.updateProfile(experience: e));
  }

  void _editStyle(BuildContext context, AppState appState) {
    _pickSheet<TradingStyle>(context, 'Trading Style', TradingStyle.values, appState.profile.style, (e) => e.label, (e) => appState.updateProfile(style: e));
  }



  void _pickSheet<T>(BuildContext context, String title, List<T> options, T current, String Function(T) label, ValueChanged<T> onPick) {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.0))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14.0),
            Text(title, style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: colors.foreground)),
            const SizedBox(height: 10.0),
            ...options.map((o) {
              final active = o == current;
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  onTap: () {
                    onPick(o);
                    Navigator.of(ctx).pop();
                  },
                  title: Text(label(o), style: TextStyle(color: colors.foreground, fontWeight: FontWeight.w600)),
                  trailing: active ? Icon(Icons.check_circle_rounded, color: colors.primary) : null,
                ),
              );
            }),
            const SizedBox(height: 10.0),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, TradingProvider provider) {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        title: Text('Reset Account', style: TextStyle(color: colors.foreground, fontWeight: FontWeight.bold)),
        content: Text('This clears all trades, positions, orders, journal entries and progress, and restores your starting capital. This cannot be undone.', style: TextStyle(color: colors.foreground)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: TextStyle(color: colors.mutedForeground))),
          TextButton(
            onPressed: () {
              provider.resetAccount();
              Navigator.of(ctx).pop();
            },
            child: Text('Reset', style: TextStyle(color: colors.destructive, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }



  void _showPrivacyPolicy(BuildContext context, ThemePalette colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.0))),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16.0),
            Text('Privacy Policy', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: colors.foreground)),
            const SizedBox(height: 16.0),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  'Privacy Policy for TradeVerse\n\n'
                  'Last Updated: July 2026\n\n'
                  '1. Information Collection\n'
                  'TradeVerse is a beginner paper trading simulator app. All trades, portfolios, and settings are stored locally on your device. We do not collect or store any personal identification information (PII) on external servers.\n\n'
                  '2. Local Storage\n'
                  'The application utilizes local device storage (SharedPreferences) to keep track of your virtual wallet balance, portfolio allocations, and trading history. Clearing your app cache or uninstalling the app will permanently delete this data.\n\n'
                  '3. Data Security\n'
                  'Since all data resides on your device, the security of your trading simulator data is dependent on the security of your device. We recommend keeping your operating system updated and securing your device with bio-metrics or passcodes.\n\n'
                  '4. Changes to Policy\n'
                  'We may update our Privacy Policy from time to time. Any changes will be posted directly within the app.\n\n'
                  '5. Contact Us\n'
                  'For questions about this Privacy Policy, please contact support@tradeverse.app.',
                  style: TextStyle(color: colors.foreground, fontSize: 13.5, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTermsAndConditions(BuildContext context, ThemePalette colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.0))),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16.0),
            Text('Terms & Conditions', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: colors.foreground)),
            const SizedBox(height: 16.0),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  'Terms and Conditions for TradeVerse\n\n'
                  'Last Updated: July 2026\n\n'
                  '1. Educational Purposes Only\n'
                  'TradeVerse is purely an educational tool and simulator app for paper trading. No real fiat money, cryptocurrency, or stocks are traded or held. All balance numbers represent virtual simulated currency.\n\n'
                  '2. Financial Advice Disclaimer\n'
                  'The contents, market prices, indicators, and details within TradeVerse are simulated or pulled for paper-trading simulations. Nothing in this app constitutes financial, investment, legal, or tax advice.\n\n'
                  '3. No Financial Risk\n'
                  'Since all trades use play virtual money, you cannot lose real money or claim real profits. You agree that the creators of TradeVerse are not liable for any financial decisions or actions you make in real markets.\n\n'
                  '4. Localized Simulation\n'
                  'Prices and execution are simulated locally and might not reflect live bid-ask spreads, real-world execution speeds, or broker latencies. We make no guarantees of price feed availability or accuracy.\n\n'
                  '5. Termination of App Access\n'
                  'We reserve the right to modify or discontinue any app features at any time without notice.\n\n'
                  'If you have questions, contact support@tradeverse.app.',
                  style: TextStyle(color: colors.foreground, fontSize: 13.5, height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
