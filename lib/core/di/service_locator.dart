/// Service Locator for Dependency Injection
/// 
/// This provides a simple dependency injection mechanism using GetIt pattern.
/// All services, repositories, and controllers should be registered here.
library;

import 'package:app/core/events/event_bus.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/core/logging/file_logger.dart';
import 'package:app/core/notifications/notification_manager.dart';
import 'package:app/services/notification_service.dart';

class ServiceLocator {
  ServiceLocator._();
  
  static final ServiceLocator _instance = ServiceLocator._();
  static ServiceLocator get instance => _instance;
  
  final Map<Type, dynamic> _services = {};
  final Map<Type, Function> _factories = {};
  
  /// Register a singleton service
  void registerSingleton<T>(T service) {
    _services[T] = service;
  }

  /// Register the default AppLogger (FileLogger) singleton
  void registerDefaultLoggers() {
    registerSingleton<AppLogger>(FileLogger.instance);
  }
  
  /// Register a factory for lazy instantiation
  void registerFactory<T>(T Function() factory) {
    _factories[T] = factory;
  }
  
  /// Register a lazy singleton (created on first access)
  void registerLazySingleton<T>(T Function() factory) {
    _factories[T] = () {
      final service = factory();
      _services[T] = service;
      _factories.remove(T);
      return service;
    };
  }
  
  /// Get a service instance
  T get<T>() {
    // Check if singleton exists
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }
    
    // Check if factory exists
    if (_factories.containsKey(T)) {
      final factory = _factories[T]!;
      return factory() as T;
    }
    
    throw Exception('Service of type $T not registered');
  }
  
  /// Check if service is registered
  bool isRegistered<T>() {
    return _services.containsKey(T) || _factories.containsKey(T);
  }
  
  /// Reset all services (useful for testing)
  void reset() {
    _services.clear();
    _factories.clear();
  }
  
  /// Unregister a specific service
  void unregister<T>() {
    _services.remove(T);
    _factories.remove(T);
  }

  /// Register default services (loggers, notifications)
  void registerDefaults() {
    registerDefaultLoggers();
    if (!isRegistered<NotificationManager>()) {
      registerSingleton<NotificationManager>(
        NotificationManager(eventBus: isRegistered<EventBus>() ? get<EventBus>() : EventBus.instance),
      );
    }
    if (!isRegistered<NotificationService>()) {
      registerSingleton<NotificationService>(
        NotificationService(isRegistered<EventBus>() ? get<EventBus>() : EventBus.instance),
      );
    }
  }
}

/// Convenience getter
ServiceLocator get sl => ServiceLocator.instance;

/// Named alias — used as serviceLocator<T>() via call()
ServiceLocator get serviceLocator => ServiceLocator.instance;

extension ServiceLocatorCall on ServiceLocator {
  /// Allows generic lookup via [call].
  T call<T>() => get<T>();
}
