import 'dart:async';
import 'package:flutter/foundation.dart';
import '../events/app_events.dart';

/// Base controller with common functionality for all screen controllers
///
/// Provides:
/// - Automatic event subscription cleanup
/// - Safe state updates (checks if disposed)
/// - Event bus integration
/// - Lifecycle management
///
/// Usage:
/// ```dart
/// class MyController extends BaseController {
///   MyController() {
///     // Setup event listeners
///     listenToEvent<UploadSuccessEvent>(_onUploadSuccess);
///   }
///
///   void _onUploadSuccess(UploadSuccessEvent event) {
///     // Handle event
///     // Subscription automatically cancelled on dispose
///   }
///
///   // Use updateState() instead of notifyListeners()
///   void someMethod() {
///     // ... do work ...
///     updateState(); // Safe even if disposed
///   }
/// }
/// ```
abstract class BaseController extends ChangeNotifier {
  final List<StreamSubscription> _subscriptions = [];
  bool _disposed = false;

  /// Check if controller has been disposed
  bool get isDisposed => _disposed;

  /// Subscribe to event bus events
  /// Subscription is automatically cancelled when controller is disposed
  ///
  /// Usage:
  /// ```dart
  /// listenToEvent<UploadSuccessEvent>((event) {
  ///   // Handle event
  /// });
  /// ```
  void listenToEvent<T extends AppEvent>(
    void Function(T event) handler,
  ) {
    if (_disposed) {
      debugPrint('[BaseController] Warning: Attempting to listen to event after disposal');
      return;
    }

    final sub = AppEventBus.instance.on<T>().listen(handler);
    _subscriptions.add(sub);
    debugPrint('[$runtimeType] Listening to ${T.toString()}');
  }

  /// Emit event to event bus
  ///
  /// Usage:
  /// ```dart
  /// emitEvent(CustomEvent(data: someData));
  /// ```
  void emitEvent(AppEvent event) {
    if (_disposed) {
      debugPrint('[BaseController] Warning: Attempting to emit event after disposal');
      return;
    }

    AppEventBus.instance.emit(event);
  }

  /// Safe state update - only notifies listeners if not disposed
  /// Use this instead of notifyListeners() directly
  void updateState() {
    if (!_disposed) {
      notifyListeners();
    } else {
      debugPrint('[$runtimeType] Warning: Attempted to update state after disposal');
    }
  }

  /// Initialize controller
  /// Override this to add custom initialization logic
  /// Called automatically by child classes
  @protected
  void init() {
    // Override in subclasses
  }

  @override
  @mustCallSuper
  void dispose() {
    _disposed = true;

    // Cancel all event subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    debugPrint('[$runtimeType] Disposed');
    super.dispose();
  }
}

/// Extension to add controller-specific utilities
extension BaseControllerExtension on BaseController {
  /// Execute async operation safely (catches errors)
  /// Returns true if successful, false if error
  Future<bool> safeExecute(Future<void> Function() operation) async {
    try {
      await operation();
      return true;
    } catch (e) {
      debugPrint('[$runtimeType] Error in operation: $e');
      return false;
    }
  }

  /// Debounce calls to a function
  /// Useful for search inputs, etc.
  void debounce(
    Duration duration,
    void Function() action, {
    String? key,
  }) {
    // Implementation would go here
    // For now, just call immediately
    action();
  }
}
