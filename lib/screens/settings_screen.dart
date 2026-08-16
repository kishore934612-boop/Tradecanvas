/// Settings — profile preferences, chart customization, appearance and system settings.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app/components/ui.dart';
import 'package:app/constants/colors.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/screens/chart_customization_screen.dart';
import 'package:app/utils/haptics.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(title: 'Settings'),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  const _SectionLabel('Profile & Preferences'),
                  _UnifiedProfileCard(appState: appState),
                  const _SectionLabel('Appearance & Canvas'),
                  _AppearanceCanvasCard(appState: appState),
                  const _SectionLabel('App Preferences'),
                  _HapticsCard(appState: appState),
                  const _SectionLabel('System & Data'),
                  const _ClearDataCard(),
                  const SizedBox(height: 28),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'TradeCanvas v2.4.0',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Market data provided by Binance WS Engine',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.mutedForeground.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: colors.mutedForeground,
        ),
      ),
    );
  }
}

// ============================================================
// UNIFIED PROFILE CARD
// ============================================================

class _UnifiedProfileCard extends StatefulWidget {
  final AppState appState;
  const _UnifiedProfileCard({required this.appState});

  @override
  State<_UnifiedProfileCard> createState() => _UnifiedProfileCardState();
}

class _UnifiedProfileCardState extends State<_UnifiedProfileCard> {
  void _showCoinPickerSheet(BuildContext context) {
    const available = [
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

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final colors = AppColors.of(context);
            final currentFavs =
                List<String>.from(widget.appState.profile.favoriteCoins);

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit Favorite Coins',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                      Text(
                        '${currentFavs.length} / 5 Selected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final coin in available)
                        ChoiceChip(
                          avatar: SymbolAvatar(
                            label: coin.replaceAll('USDT', ''),
                            color: colors.primary,
                            size: 20,
                          ),
                          label: Text(coin.replaceAll('USDT', '')),
                          selected: currentFavs.contains(coin),
                          selectedColor: colors.primary.withValues(alpha: 0.2),
                          onSelected: (selected) {
                            Haptics.selection();
                            if (selected) {
                              if (currentFavs.length < 5) {
                                currentFavs.add(coin);
                                widget.appState.setFavoriteCoins(currentFavs);
                                setSheetState(() {});
                              }
                            } else {
                              if (currentFavs.length > 1) {
                                currentFavs.remove(coin);
                                widget.appState.setFavoriteCoins(currentFavs);
                                setSheetState(() {});
                              }
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.primaryForeground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Done'),
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

  void _showTraderTypeSheet(BuildContext context) {
    final types = [
      'Scalp Trader',
      'Intraday Trader',
      'Swing Trader',
      'Position Trader',
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = AppColors.of(context);
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change Trader Persona',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              const SizedBox(height: 14),
              for (final type in types)
                ListTile(
                  title: Text(
                    type,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          widget.appState.profile.traderType == type
                              ? FontWeight.bold
                              : FontWeight.w500,
                      color: widget.appState.profile.traderType == type
                          ? colors.primary
                          : colors.foreground,
                    ),
                  ),
                  onTap: () {
                    Haptics.selection();
                    widget.appState.setTraderType(type);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final profile = widget.appState.profile;
    final photoUrl = widget.appState.photoUrl;
    final displayName = widget.appState.username ?? 'Trader Profile';

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Account Header Row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colors.primary.withValues(alpha: 0.15),
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Icon(Icons.person_rounded,
                        color: colors.primary, size: 24)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.foreground,
                      ),
                    ),

                  ],
                ),
              ),

            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: colors.border.withValues(alpha: 0.5)),
          ),

          // 2. Trader Persona
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trader Persona',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.mutedForeground,
                ),
              ),
              InkWell(
                onTap: () => _showTraderTypeSheet(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile.traderType,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.edit_rounded,
                          size: 13, color: colors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 3. Favorite Coins Symbols
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Favorite Coins',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.mutedForeground,
                ),
              ),
              InkWell(
                onTap: () => _showCoinPickerSheet(context),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Edit Coins',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final coin in profile.favoriteCoins)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.card.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SymbolAvatar(
                        label: coin.replaceAll('USDT', ''),
                        color: colors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        coin.replaceAll('USDT', ''),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // 4. Default Timeframe
          Text(
            'Default Timeframe',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                for (final tf in ['1m', '5m', '15m', '1h', '4h', '1d'])
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Haptics.selection();
                        widget.appState.setDefaultTimeframe(tf);
                      },
                      borderRadius: BorderRadius.circular(7),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: profile.defaultTimeframe == tf
                              ? colors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          tf,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: profile.defaultTimeframe == tf
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: profile.defaultTimeframe == tf
                                ? Colors.white
                                : colors.mutedForeground,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// APPEARANCE & CANVAS CARD (Single container with icon theme toggle)
// ============================================================

class _AppearanceCanvasCard extends StatelessWidget {
  final AppState appState;
  const _AppearanceCanvasCard({required this.appState});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = appState.themeMode == ThemeMode.dark;

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Row 1: App Visual Theme with Theme Switch Icon Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  size: 20,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Visual Theme',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDark ? 'Dark Theme Active' : 'Light Theme Active',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Switch theme',
                onPressed: () {
                  Haptics.selection();
                  appState.setThemeMode(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
                },
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey(isDark),
                    color: colors.primary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: colors.border.withValues(alpha: 0.5)),
          ),

          // Row 2: Chart Customization
          InkWell(
            onTap: () {
              Haptics.selection();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ChartCustomizationScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.tune_rounded, size: 20, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chart Customization',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Candle templates & grid styles',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: colors.mutedForeground, size: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HAPTICS CARD
// ============================================================

class _HapticsCard extends StatelessWidget {
  final AppState appState;
  const _HapticsCard({required this.appState});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = appState.profile.hapticsEnabled;

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.vibration_rounded, size: 20, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Haptic Touch Feedback',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colors.foreground,
              ),
            ),
          ),
          Switch.adaptive(
            value: enabled,
            activeTrackColor: colors.primary,
            onChanged: (val) {
              Haptics.selection();
              appState.setHaptics(val);
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CLEAR DATA CARD
// ============================================================

class _ClearDataCard extends StatelessWidget {
  const _ClearDataCard();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () {
          Haptics.selection();
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Reset App Preferences?'),
              content: const Text(
                  'This will reset chart background, candle themes and preferences back to defaults.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    context.read<AppState>().resetPreferences();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Reset Defaults'),
                ),
              ],
            ),
          );
        },
        child: Row(
          children: [
            Icon(Icons.restart_alt_rounded,
                size: 20, color: colors.destructive),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Reset Preferences & Cache',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.destructive,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
