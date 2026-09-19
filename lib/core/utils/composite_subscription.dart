import 'dart:async';

/// Cancels and clears every subscription in the list in one call.
///
/// Usage:
/// ```dart
/// final _subs = <StreamSubscription>[];
///
/// // in initState:
/// _subs.add(AppEventBus.instance.on<SomeEvent>().listen(_onSome));
///
/// // in dispose:
/// _subs.cancelAll();
/// ```
extension CompositeSubscription on List<StreamSubscription> {
  void cancelAll() {
    for (final s in this) { s.cancel(); }
    clear();
  }
}
