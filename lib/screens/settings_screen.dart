/// Profile Screen — user profile overview, persona, favorite coins, and Settings navigation card.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app/components/ui.dart';
import 'package:app/constants/app_info.dart';
import 'package:app/constants/colors.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/providers/market_data_provider.dart';
import 'package:app/screens/settings_detail_screen.dart';
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
            const ScreenHeader(title: 'Profile'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  const _SectionLabel('Trader Profile'),
                  _UnifiedProfileCard(appState: appState),

                  const _SectionLabel('System Settings'),
                  _SettingsNavCard(),

                  const SizedBox(height: 28),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          appDisplayVersion,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Technical Analysis Engine & WS Market Stream',
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
// SETTINGS NAVIGATION CARD
// ============================================================

class _SettingsNavCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () {
          Haptics.selection();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SettingsDetailScreen(),
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
              child: Icon(Icons.settings_rounded, size: 22, color: colors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Theme mode, chart customization, preferences & legal',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.mutedForeground, size: 24),
          ],
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
                                context.read<MarketDataProvider>().replaceWatchlist(currentFavs);
                                setSheetState(() {});
                              }
                            } else {
                              if (currentFavs.length > 1) {
                                currentFavs.remove(coin);
                                widget.appState.setFavoriteCoins(currentFavs);
                                context.read<MarketDataProvider>().replaceWatchlist(currentFavs);
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

  void _showEditNameDialog(BuildContext context) {
    final controller =
        TextEditingController(text: widget.appState.username ?? '');
    final colors = AppColors.of(context);
    String? errorMessage;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.badge_rounded, color: colors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Edit Display Name',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter a new display name for your trading profile.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Display name',
                      hintStyle: TextStyle(color: colors.mutedForeground),
                      filled: true,
                      fillColor: colors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: errorMessage != null
                              ? colors.negative
                              : colors.border.withValues(alpha: 0.6),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: errorMessage != null
                              ? colors.negative
                              : colors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      if (errorMessage != null) {
                        setDialogState(() => errorMessage = null);
                      }
                    },
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.negative,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: colors.mutedForeground),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newName = controller.text.trim();
                    if (newName.isEmpty) {
                      setDialogState(
                          () => errorMessage = 'Name cannot be empty.');
                      return;
                    }
                    Haptics.selection();
                    widget.appState.updateDisplayName(newName);
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.primaryForeground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
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
                child: InkWell(
                  onTap: () => _showEditNameDialog(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 4, horizontal: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colors.foreground,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: colors.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Tap to edit name',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
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
