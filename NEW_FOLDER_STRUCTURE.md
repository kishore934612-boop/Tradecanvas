# TradeVerse - New Folder Structure

## Target Structure (Feature-Based + Layered)

```
lib/
├── main.dart
│
├── core/                              # Core infrastructure
│   ├── di/                           # Dependency injection
│   │   ├── service_locator.dart
│   │   └── injector.dart
│   │
│   ├── events/                       # Event bus
│   │   ├── event_bus.dart
│   │   ├── trade_events.dart
│   │   ├── market_events.dart
│   │   └── portfolio_events.dart
│   │
│   ├── logging/                      # Logging system
│   │   ├── logger.dart
│   │   └── log_levels.dart
│   │
│   ├── config/                       # App configuration
│   │   ├── app_config.dart
│   │   └── environment.dart
│   │
│   └── utils/                        # Shared utilities
│       ├── formatters.dart
│       ├── validators.dart
│       └── extensions.dart
│
├── domain/                            # Business logic layer
│   ├── entities/                     # Domain models
│   │   ├── asset.dart
│   │   ├── position.dart
│   │   ├── trade.dart
│   │   ├── order.dart
│   │   ├── portfolio.dart
│   │   ├── candle.dart
│   │   └── journal_entry.dart
│   │
│   ├── repositories/                 # Repository interfaces
│   │   ├── market_repository.dart
│   │   ├── portfolio_repository.dart
│   │   ├── journal_repository.dart
│   │   └── settings_repository.dart
│   │
│   ├── services/                     # Service interfaces
│   │   ├── trading_engine.dart
│   │   ├── risk_calculator.dart
│   │   ├── currency_engine.dart
│   │   └── validation_service.dart
│   │
│   └── use_cases/                    # Business use cases
│       ├── open_position_use_case.dart
│       ├── close_position_use_case.dart
│       ├── calculate_pnl_use_case.dart
│       └── validate_trade_use_case.dart
│
├── data/                              # Data layer
│   ├── providers/                    # Data source providers
│   │   ├── market/
│   │   │   ├── market_provider.dart  # Interface
│   │   │   ├── binance_provider.dart
│   │   │   ├── yahoo_provider.dart
│   │   │   └── mock_provider.dart
│   │   │
│   │   └── persistence/
│   │       ├── persistence_provider.dart  # Interface
│   │       ├── shared_prefs_provider.dart
│   │       └── secure_storage_provider.dart
│   │
│   ├── repositories/                 # Repository implementations
│   │   ├── market_repository_impl.dart
│   │   ├── portfolio_repository_impl.dart
│   │   ├── journal_repository_impl.dart
│   │   └── settings_repository_impl.dart
│   │
│   ├── models/                       # Data transfer objects
│   │   ├── api_models.dart
│   │   ├── cache_models.dart
│   │   └── storage_models.dart
│   │
│   └── cache/                        # Caching layer
│       ├── cache_manager.dart
│       └── cache_policies.dart
│
├── presentation/                      # Presentation layer
│   ├── controllers/                  # Feature controllers
│   │   ├── portfolio_controller.dart
│   │   ├── position_controller.dart
│   │   ├── order_controller.dart
│   │   ├── market_data_controller.dart
│   │   ├── journal_controller.dart
│   │   ├── challenge_controller.dart
│   │   └── chart_controller.dart
│   │
│   ├── managers/                     # Cross-cutting managers
│   │   ├── risk_manager.dart
│   │   ├── notification_manager.dart
│   │   └── market_scheduler.dart
│   │
│   ├── state/                        # State management
│   │   ├── app_state.dart           # Keep existing
│   │   └── trading_state.dart       # New unified state
│   │
│   ├── screens/                      # UI screens (keep existing)
│   │   ├── splash/
│   │   ├── onboarding/
│   │   ├── portfolio/
│   │   ├── markets/
│   │   ├── trading/
│   │   ├── analytics/
│   │   ├── journal/
│   │   ├── challenges/
│   │   └── settings/
│   │
│   ├── widgets/                      # Reusable widgets (keep existing)
│   │   ├── common/
│   │   ├── portfolio/
│   │   ├── trading/
│   │   └── charts/
│   │
│   └── components/                   # Complex components (keep existing)
│       ├── charts/
│       │   ├── candlestick_chart.dart
│       │   ├── chart_engine/
│       │   │   ├── candle_engine.dart
│       │   │   ├── indicator_engine.dart
│       │   │   ├── overlay_engine.dart
│       │   │   └── gesture_engine.dart
│       │   └── chart_painter.dart
│       │
│       ├── sparkline.dart
│       └── interactive_chart.dart
│
├── features/                          # Feature modules (gradual migration)
│   ├── authentication/               # Future
│   ├── notifications/                # Future
│   └── social/                       # Future
│
└── constants/                         # Keep existing
    ├── colors.dart
    ├── markets.dart
    └── app_constants.dart
```

## Migration Path

### Phase 1: Create New Structure
Create new folders without moving existing files.

### Phase 2: Gradual Migration
Move files one by one, maintaining imports.

### Phase 3: Update Imports
Update all import statements across app.

### Phase 4: Remove Old Structure
Delete old folders once fully migrated.

## Import Organization

```dart
// External packages
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Core
import 'package:app/core/di/service_locator.dart';
import 'package:app/core/logging/logger.dart';

// Domain
import 'package:app/domain/entities/position.dart';
import 'package:app/domain/repositories/market_repository.dart';

// Data
import 'package:app/data/providers/market/binance_provider.dart';

// Presentation
import 'package:app/presentation/controllers/portfolio_controller.dart';
import 'package:app/presentation/screens/portfolio/portfolio_screen.dart';

// Constants
import 'package:app/constants/markets.dart';
```

