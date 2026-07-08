/// Structured logging system for TradeVerse
/// 
/// Replaces print statements with categorized, leveled logging.
/// Can be disabled in production builds.
library;

import 'package:app/core/logging/file_logger.dart';

import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
  network,
  market,
  trade,
  chart,
}

extension LogLevelX on LogLevel {
  String get prefix {
    switch (this) {
      case LogLevel.debug:
        return '🐛';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.network:
        return '🌐';
      case LogLevel.market:
        return '📊';
      case LogLevel.trade:
        return '💰';
      case LogLevel.chart:
        return '📈';
    }
  }
  
  String get name {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.network:
        return 'NET';
      case LogLevel.market:
        return 'MKT';
      case LogLevel.trade:
        return 'TRADE';
      case LogLevel.chart:
        return 'CHART';
    }
  }
}

class AppLogger {
  AppLogger();
  
  static final AppLogger _instance = FileLogger.instance;
  static AppLogger get instance => _instance;
  
  bool _enabled = kDebugMode;
  LogLevel _minLevel = LogLevel.debug;
  
  /// Enable/disable logging
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }
  
  /// Set minimum log level
  void setMinLevel(LogLevel level) {
    _minLevel = level;
  }
  
  /// Log a message
  void log(LogLevel level, String message, [Object? error, StackTrace? stackTrace]) {
    if (!_enabled) return;
    if (level.index < _minLevel.index) return;
    
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final prefix = level.prefix;
    final levelName = level.name.padRight(5);
    
    final logMessage = '[$timestamp] $prefix [$levelName] $message';
    
    // ignore: avoid_print
    print(logMessage);
    
    if (error != null) {
      // ignore: avoid_print
      print('  Error: $error');
    }
    
    if (stackTrace != null) {
      // ignore: avoid_print
      print('  Stack trace:\n$stackTrace');
    }
  }
  
  /// Convenience methods
  void debug(String message) => log(LogLevel.debug, message);
  void info(String message) => log(LogLevel.info, message);
  void warning(String message) => log(LogLevel.warning, message);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      log(LogLevel.error, message, error, stackTrace);
  
  void network(String message) => log(LogLevel.network, message);
  void market(String message) => log(LogLevel.market, message);
  void trade(String message) => log(LogLevel.trade, message);
  void chart(String message) => log(LogLevel.chart, message);
}

/// Global logger instance
final logger = FileLogger.instance;

/// Alias used throughout the codebase for brevity.
typedef Logger = AppLogger;
