/// Event Bus for decoupled communication between modules
/// 
/// This allows different parts of the app to communicate without direct dependencies.
/// Events are typed and can carry data payloads.
library;

import 'dart:async';

/// Base class for all events
abstract class AppEvent {
  final DateTime timestamp;
  
  AppEvent() : timestamp = DateTime.now();
}

/// Event Bus implementation
class EventBus {
  EventBus._();
  
  static final EventBus _instance = EventBus._();
  static EventBus get instance => _instance;
  
  final Map<Type, StreamController> _controllers = {};
  final Map<Type, Stream> _streams = {};
  
  /// Publish an event
  void publish<T extends AppEvent>(T event) {
    final controller = _getController<T>();
    // Deliver events asynchronously to keep the main isolate responsive
    Future.microtask(() => controller.add(event));
  }
  
  /// Subscribe to events of type T
  StreamSubscription<T> subscribe<T extends AppEvent>(
    void Function(T event) onEvent,
  ) {
    final stream = _getStream<T>();
    return stream.cast<T>().listen(onEvent);
  }

  /// Get stream of events of type T
  Stream<T> on<T extends AppEvent>() {
    return _getStream<T>().cast<T>();
  }
  
  /// Get or create controller for event type
  StreamController _getController<T extends AppEvent>() {
    if (!_controllers.containsKey(T)) {
      _controllers[T] = StreamController<T>.broadcast(sync: true);
    }
    return _controllers[T]!;
  }
  
  /// Get or create stream for event type
  Stream _getStream<T extends AppEvent>() {
    if (!_streams.containsKey(T)) {
      _streams[T] = _getController<T>().stream;
    }
    return _streams[T]!;
  }
  
  /// Dispose all controllers
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
    _streams.clear();
  }
}

/// Convenience getter
EventBus get eventBus => EventBus.instance;
