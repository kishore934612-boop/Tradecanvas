/// Charty — a charting tool for Binance spot markets.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:app/constants/colors.dart';
import 'package:app/core/di/service_locator.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/data/cache/cache_manager.dart';
import 'package:app/data/providers/market/binance_provider.dart';
import 'package:app/data/repositories/market_repository_impl.dart';
import 'package:app/data/repositories/sqlite_repositories.dart';
import 'package:app/domain/repositories/chart_prefs_repository.dart';
import 'package:app/domain/repositories/drawing_repository.dart';
import 'package:app/domain/repositories/kline_cache_repository.dart';
import 'package:app/domain/repositories/market_repository.dart';
import 'package:app/domain/repositories/watchlist_repository.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/providers/market_data_provider.dart';
import 'package:app/screens/splash_screen.dart';
import 'package:app/services/persistence/persistence_service.dart';
import 'package:app/services/persistence/shared_preferences_persistence.dart';
import 'package:app/services/persistence/sqlite_db_helper.dart';
import 'package:app/services/session.dart';
import 'package:app/services/symbol_registry.dart';
import 'package:app/services/sync/sync_coordinator.dart';
import 'package:app/utils/haptics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _registerServices();

  runApp(const CharyApp());
}

Future<void> _registerServices() async {
  final logger = Logger.instance;
  if (!kDebugMode) logger.setEnabled(false);

  logger.info('Charty starting');

  // ── Core ─────────────────────────────────────────────────
  serviceLocator.registerSingleton<Logger>(logger);
  serviceLocator.registerSingleton<EventBus>(EventBus.instance);
  serviceLocator.registerDefaults();

  // ── Persistence ──────────────────────────────────────────
  serviceLocator
      .registerSingleton<PersistenceService>(SharedPreferencesPersistence());

  final dbHelper = SqliteDbHelper.instance;
  await dbHelper.init(); // runs onCreate/onUpgrade or sets up web fallback
  serviceLocator.registerSingleton<SqliteDbHelper>(dbHelper);

  const session = LocalSession();
  serviceLocator.registerSingleton<SessionProvider>(session);
  serviceLocator.registerSingleton<SyncCoordinator>(SyncCoordinator.instance);

  // ── Repositories ─────────────────────────────────────────
  serviceLocator.registerSingleton<KlineCacheRepository>(
      PersistenceKlineCacheRepository(
          persistence: serviceLocator<PersistenceService>(), logger: logger));
  serviceLocator
      .registerSingleton<WatchlistRepository>(SqliteWatchlistRepository());
  serviceLocator.registerSingleton<DrawingRepository>(
      SqliteDrawingRepository(session: session, logger: logger));
  serviceLocator.registerSingleton<ChartPrefsRepository>(
      SqliteChartPrefsRepository(session: session));

  // ── Market data ──────────────────────────────────────────
  final binance = BinanceProvider();
  serviceLocator.registerSingleton<BinanceProvider>(binance);
  serviceLocator.registerSingleton<CacheManager>(CacheManager());

  final marketRepository = MarketRepositoryImpl(
    binanceProvider: binance,
    cache: serviceLocator<CacheManager>(),
    eventBus: serviceLocator<EventBus>(),
    logger: logger,
  );
  serviceLocator.registerSingleton<MarketRepository>(marketRepository);

  final registry = SymbolRegistry(
    provider: binance,
    persistence: serviceLocator<PersistenceService>(),
    logger: logger,
  );
  serviceLocator.registerSingleton<SymbolRegistry>(registry);

  // Drain anything queued from a previous offline session.
  SyncCoordinator.instance.triggerProcessing();

  logger.info('Services registered');
}

class CharyApp extends StatelessWidget {
  const CharyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider<SymbolRegistry>.value(
          value: serviceLocator<SymbolRegistry>(),
        ),
        ChangeNotifierProvider(
          create: (_) => MarketDataProvider(
            provider: serviceLocator<BinanceProvider>(),
            registry: serviceLocator<SymbolRegistry>(),
            watchlistRepo: serviceLocator<WatchlistRepository>(),
            session: serviceLocator<SessionProvider>(),
            logger: serviceLocator<Logger>(),
          ),
        ),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Symbols must load before the watchlist can resolve instruments.
    WidgetsBinding.instance.addPostFrameCallback((_) => _warmUp());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  Future<void> _warmUp() async {
    await context.read<SymbolRegistry>().load();
    if (!mounted) return;
    await context.read<MarketDataProvider>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    // Keep the haptics switch in sync with the stored preference.
    Haptics.enabled = appState.profile.hapticsEnabled;

    return MaterialApp(
      title: 'TradeCanvas',
      debugShowCheckedModeBanner: false,
      themeMode: appState.themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final palette = AppColors.forBrightness(brightness);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.primary,
        brightness: brightness,
      ).copyWith(
        surface: palette.card,
        primary: palette.primary,
        error: palette.destructive,
      ),
      dividerColor: palette.border,
    );

    return base.copyWith(
      textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme).apply(
        bodyColor: palette.foreground,
        displayColor: palette.foreground,
      ),
      extensions: [AppThemeExtension(palette)],
    );
  }
}
