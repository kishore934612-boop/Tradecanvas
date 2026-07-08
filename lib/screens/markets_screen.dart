import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/constants/markets.dart';
import 'package:app/components/asset_row.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/screens/coin_detail_screen.dart';
import 'package:app/components/ui.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTab = 'all'; // 'all', 'watchlist'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Asset> get _processedAssets {
    final provider = Provider.of<TradingProvider>(context, listen: false);
    
    // 1. Initial filter based on tab selected
    List<Asset> list = List.from(assets);
    if (_selectedTab == 'watchlist') {
      list = assets.where((a) => provider.favorites.contains(a.symbol)).toList();
    }

    // 2. Secondary search query filter
    if (_searchQuery.isNotEmpty) {
      list = list.where((asset) {
        final symbolMatch = asset.symbol.toLowerCase().contains(_searchQuery);
        final nameMatch = asset.name.toLowerCase().contains(_searchQuery);
        return symbolMatch || nameMatch;
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final filtered = _processedAssets;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const ScreenHeader(
              title: 'Explore Markets',
            ),
            const SizedBox(height: 12.0),

            // 1. Category Capsule Tabs
            _buildTabSelector(colors),
            const SizedBox(height: 12.0),

            // 2. Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
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
                        controller: _searchController,
                        style: TextStyle(
                          color: colors.foreground,
                          fontSize: 15.0,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search ticker or asset name...',
                          hintStyle: TextStyle(color: colors.mutedForeground.withValues(alpha: 0.7)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        autocorrect: false,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                        },
                        child: Icon(Icons.close_rounded, color: colors.mutedForeground, size: 20.0),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12.0),

            // Watchlist Grid / List View
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(colors)
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 100.0),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return AssetRow(
                          key: ValueKey(item.symbol),
                          asset: item,
                          onPress: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CoinDetailScreen(
                                  symbol: item.symbol,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(ThemePalette colors) {
    return SizedBox(
      height: 36.0,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          _tabCapsule('All Crypto', 'all', colors),
          const SizedBox(width: 8.0),
          _tabCapsule('Watchlist', 'watchlist', colors),
        ],
      ),
    );
  }

  Widget _tabCapsule(String label, String id, ThemePalette colors) {
    final bool isSelected = _selectedTab == id;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedTab = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.card,
          borderRadius: BorderRadius.circular(18.0),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: 0.8,
          ),
          boxShadow: isSelected ? colors.glowShadow : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? (colors.brightness == Brightness.dark ? Colors.black : Colors.white)
                : colors.foreground,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemePalette colors) {
    if (_selectedTab == 'watchlist') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.star_outline_rounded,
                size: 48.0,
                color: colors.mutedForeground.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16.0),
              Text(
                'Starred Watchlist is Empty',
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6.0),
              Text(
                'Tap the star icon next to any coin in the All Crypto list to pin it here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.mutedForeground,
                  fontSize: 13.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 32.0,
            color: colors.mutedForeground,
          ),
          const SizedBox(height: 12.0),
          Text(
            'No matching assets found.',
            style: TextStyle(
              color: colors.mutedForeground,
              fontSize: 14.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
