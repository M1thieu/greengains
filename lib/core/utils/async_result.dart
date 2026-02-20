/// Type-safe result wrapper for async operations
/// Eliminates try-catch boilerplate and standardizes error handling
///
/// Usage:
/// ```dart
/// final state = ValueNotifier<AsyncResult<Data>>(const Loading());
///
/// Future<void> loadData() async {
///   state.value = const Loading();
///   try {
///     final data = await repository.getData();
///     state.value = Success(data);
///   } catch (e) {
///     state.value = Error('Failed: $e');
///   }
/// }
///
/// // In widget:
/// ValueListenableBuilder<AsyncResult<Data>>(
///   valueListenable: state,
///   builder: (context, result, _) {
///     return result.when(
///       success: (data) => DataWidget(data),
///       loading: () => LoadingIndicator(),
///       error: (msg) => ErrorWidget(msg),
///     );
///   },
/// )
/// ```
sealed class AsyncResult<T> {
  const AsyncResult();
}

/// Successful result with data
class Success<T> extends AsyncResult<T> {
  final T data;
  const Success(this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> &&
          runtimeType == other.runtimeType &&
          data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success($data)';
}

/// Loading state (operation in progress)
class Loading<T> extends AsyncResult<T> {
  const Loading();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Loading<T> && runtimeType == other.runtimeType;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'Loading()';
}

/// Error state with message
class Error<T> extends AsyncResult<T> {
  final String message;
  final Exception? exception;

  const Error(this.message, [this.exception]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Error<T> &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'Error($message)';
}

/// Extension for easy pattern matching and utilities
extension AsyncResultExtension<T> on AsyncResult<T> {
  /// Pattern match on the result state
  R when<R>({
    required R Function(T data) success,
    required R Function() loading,
    required R Function(String message) error,
  }) {
    return switch (this) {
      Success(data: final data) => success(data),
      Loading() => loading(),
      Error(message: final msg) => error(msg),
    };
  }

  /// Pattern match with optional handlers (returns null if not matched)
  R? maybeWhen<R>({
    R Function(T data)? success,
    R Function()? loading,
    R Function(String message)? error,
    required R Function() orElse,
  }) {
    return switch (this) {
      Success(data: final data) when success != null => success(data),
      Loading() when loading != null => loading(),
      Error(message: final msg) when error != null => error(msg),
      _ => orElse(),
    };
  }

  /// Get data if success, otherwise null
  T? get dataOrNull => switch (this) {
        Success(data: final data) => data,
        _ => null,
      };

  /// Get error message if error, otherwise null
  String? get errorOrNull => switch (this) {
        Error(message: final msg) => msg,
        _ => null,
      };

  /// Check if result is in success state
  bool get isSuccess => this is Success<T>;

  /// Check if result is in loading state
  bool get isLoading => this is Loading<T>;

  /// Check if result is in error state
  bool get isError => this is Error<T>;

  /// Map data if success, otherwise return same state
  AsyncResult<R> map<R>(R Function(T data) mapper) {
    return switch (this) {
      Success(data: final data) => Success(mapper(data)),
      Loading() => const Loading(),
      Error(message: final msg, exception: final ex) => Error(msg, ex),
    };
  }

  /// FlatMap for chaining async operations
  AsyncResult<R> flatMap<R>(AsyncResult<R> Function(T data) mapper) {
    return switch (this) {
      Success(data: final data) => mapper(data),
      Loading() => const Loading(),
      Error(message: final msg, exception: final ex) => Error(msg, ex),
    };
  }
}

/// Helper to create AsyncResult from Future
extension FutureToAsyncResult<T> on Future<T> {
  /// Convert `Future<T>` to `Future<AsyncResult<T>>`
  /// Catches exceptions and wraps in Error state
  Future<AsyncResult<T>> toAsyncResult([String Function(Object)? errorMapper]) async {
    try {
      final data = await this;
      return Success(data);
    } catch (e) {
      final message = errorMapper?.call(e) ?? e.toString();
      return Error(message, e is Exception ? e : null);
    }
  }
}
