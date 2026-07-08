import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for kDebugMode
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app/constants/colors.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/screens/splash_screen.dart';
// Phase 2: Repository layer
import 'package:app/core/di/service_locator.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/data/cache/cache_manager.dart';
import 'package:app/data/providers/market/binance_provider.dart';
import 'package:app/data/repositories/market_repository_impl.dart';
import 'package:app/domain/repositories/market_repository.dart';
// Phase 8: Persistence layer
import 'package:app/services/persistence/persistence_service.dart';
import 'package:app/services/persistence/shared_preferences_persistence.dart';
import 'package:app/core/notifications/notification_manager.dart';
import 'package:app/services/learn_service.dart';
import 'package:app/services/leaderboard_service.dart';
import 'package:app/providers/learn_provider.dart';
import 'package:app/providers/leaderboard_provider.dart';
import 'package:app/providers/portfolio_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Phase 2: Initialize new repository layer
  await _initializeServices();
  // Register default services (loggers, notifications)
  serviceLocator.registerDefaults();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(
          create: (_) => TradingProvider(
            marketRepository: serviceLocator<MarketRepository>(),
            logger: serviceLocator<Logger>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LearnProvider(
            learnService: serviceLocator<LearnService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LeaderboardProvider(
            service: serviceLocator<LeaderboardService>(),
          ),
        ),
        ChangeNotifierProxyProvider<TradingProvider, PortfolioProvider>(
          create: (context) => PortfolioProvider(
            portfolioController: context.read<TradingProvider>().portfolioController,
            positionController: context.read<TradingProvider>().positionController,
            eventBus: serviceLocator<EventBus>(),
          ),
          update: (context, trading, previous) => previous ?? PortfolioProvider(
            portfolioController: trading.portfolioController,
            positionController: trading.positionController,
            eventBus: serviceLocator<EventBus>(),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

/// Initialize Phase 2 services: repository layer and providers
Future<void> _initializeServices() async {
  final logger = Logger.instance;
  logger.info('=== Phase 2: Initializing Repository Layer ===');
  
  // Phase 8: Register persistence layer first (everything else may depend on it)
  serviceLocator.registerSingleton<PersistenceService>(SharedPreferencesPersistence());

  // Register core services
  serviceLocator.registerSingleton<Logger>(logger);
  if (!kDebugMode) {
    logger.setEnabled(false);
  }
  serviceLocator.registerSingleton<EventBus>(EventBus.instance);
  serviceLocator.registerSingleton<NotificationManager>(
      NotificationManager(eventBus: serviceLocator<EventBus>()));
  serviceLocator.registerSingleton<CacheManager>(CacheManager());
  
  // Register providers
  serviceLocator.registerSingleton<BinanceProvider>(BinanceProvider());
  
  // Register Learn & Leaderboard Services
  final learnService = LearnService(persistence: serviceLocator<PersistenceService>());
  serviceLocator.registerSingleton<LearnService>(learnService);
  serviceLocator.registerSingleton<LeaderboardService>(LeaderboardService());
  
  // Register repository
  final repository = MarketRepositoryImpl(
    binanceProvider: serviceLocator<BinanceProvider>(),
    cache: serviceLocator<CacheManager>(),
    eventBus: serviceLocator<EventBus>(),
    logger: logger,
  );
  
  serviceLocator.registerSingleton<MarketRepository>(repository);
  
  // Initialize repository (connect to data sources)
  await repository.initialize();
  
  logger.info('=== Repository Layer Initialized Successfully ===');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  TextTheme _textTheme(ThemePalette palette, Brightness brightness) {
    final base = brightness == Brightness.light ? ThemeData.light().textTheme : ThemeData.dark().textTheme;
    return GoogleFonts.plusJakartaSansTextTheme(base).copyWith(
      displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: palette.text),
      displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: palette.text),
      displaySmall: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: palette.text),
      headlineLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: palette.text),
      headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: palette.text),
      headlineSmall: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: palette.text),
      titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: palette.text),
      titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: palette.text),
      titleSmall: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: palette.text),
    ).apply(bodyColor: palette.text, displayColor: palette.text);
  }

  ThemeData _buildTheme(ThemePalette p) {
    return ThemeData(
      brightness: p.brightness,
      primaryColor: p.primary,
      scaffoldBackgroundColor: p.background,
      cardColor: p.card,
      textTheme: _textTheme(p, p.brightness),
      dividerColor: p.border,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.primary,
        brightness: p.brightness,
        primary: p.primary,
        surface: p.card,
        error: p.destructive,
      ),
      useMaterial3: true,
      extensions: [AppThemeExtension(p)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return MaterialApp(
      title: 'TradeVerse',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(AppColors.getPalette(appState.themeIndex, Brightness.light)),
      darkTheme: _buildTheme(AppColors.getPalette(appState.themeIndex, Brightness.dark)),
      themeMode: appState.themeMode,
      home: const SplashScreen(),
    );
  }
}
