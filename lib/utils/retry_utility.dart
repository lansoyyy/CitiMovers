import 'dart:async';
import 'package:flutter/foundation.dart';

/// Retry Utility for CitiMovers
/// Provides exponential backoff retry logic for transient failures
class RetryUtility {
  // Private constructor to prevent instantiation
  RetryUtility._();

  // Singleton pattern
  static final RetryUtility _instance = RetryUtility._();
  factory RetryUtility() => _instance;

  /// Default retry configuration
  static const int _defaultMaxAttempts = 3;
  static const Duration _defaultInitialDelay = Duration(seconds: 1);
  static const double _defaultBackoffMultiplier = 2.0;
  static const Duration _defaultMaxDelay = Duration(seconds: 30);

  /// Retry a function with exponential backoff
  ///
  /// Parameters:
  /// - [fn]: The function to retry (must return a Future)
  /// - [maxAttempts]: Maximum number of retry attempts (default: 3)
  /// - [initialDelay]: Initial delay before first retry (default: 1 second)
  /// - [backoffMultiplier]: Multiplier for exponential backoff (default: 2.0)
  /// - [maxDelay]: Maximum delay between retries (default: 30 seconds)
  /// - [retryIf]: Optional function to determine if an error should trigger a retry
  /// - [onRetry]: Optional callback called before each retry attempt
  ///
  /// Returns the result of the successful function call
  /// Throws the last error if all attempts fail
  static Future<T> retry<T>({
    required Future<T> Function() fn,
    int maxAttempts = _defaultMaxAttempts,
    Duration initialDelay = _defaultInitialDelay,
    double backoffMultiplier = _defaultBackoffMultiplier,
    Duration maxDelay = _defaultMaxDelay,
    bool Function(dynamic error)? retryIf,
    void Function(int attempt, dynamic error)? onRetry,
  }) async {
    if (maxAttempts < 1) {
      throw ArgumentError('maxAttempts must be at least 1');
    }

    if (initialDelay.inMilliseconds < 0) {
      throw ArgumentError('initialDelay must be non-negative');
    }

    if (backoffMultiplier < 1.0) {
      throw ArgumentError('backoffMultiplier must be at least 1.0');
    }

    dynamic lastError;
    int attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;

      try {
        final result = await fn();
        if (attempt > 1) {
          debugPrint('RetryUtility: Operation succeeded on attempt $attempt');
        }
        return result;
      } catch (error) {
        lastError = error;

        // Check if we should retry this error
        if (retryIf != null && !retryIf(error)) {
          debugPrint('RetryUtility: Error not retryable, throwing: $error');
          rethrow;
        }

        // Check if this was the last attempt
        if (attempt >= maxAttempts) {
          debugPrint(
            'RetryUtility: All $maxAttempts attempts failed. Last error: $error',
          );
          rethrow;
        }

        // Calculate delay with exponential backoff
        final delay = _calculateDelay(
          attempt,
          initialDelay,
          backoffMultiplier,
          maxDelay,
        );

        debugPrint(
          'RetryUtility: Attempt $attempt/$maxAttempts failed. '
          'Retrying in ${delay.inSeconds}s. Error: $error',
        );

        // Call onRetry callback if provided
        onRetry?.call(attempt, error);

        // Wait before retrying
        await Future.delayed(delay);
      }
    }

    // This should never be reached, but for type safety
    throw lastError;
  }

  /// Calculate delay with exponential backoff
  static Duration _calculateDelay(
    int attempt,
    Duration initialDelay,
    double backoffMultiplier,
    Duration maxDelay,
  ) {
    // Calculate exponential delay: initialDelay * (backoffMultiplier ^ (attempt - 1))
    final exponentialDelay =
        initialDelay.inMilliseconds * (backoffMultiplier.pow(attempt - 1));

    // Cap at max delay
    final cappedDelay = exponentialDelay.clamp(
      initialDelay.inMilliseconds.toDouble(),
      maxDelay.inMilliseconds.toDouble(),
    );

    return Duration(milliseconds: cappedDelay.toInt());
  }

  /// Retry a function with a fixed delay between attempts
  ///
  /// Use this when you want consistent retry intervals instead of exponential backoff
  static Future<T> retryWithFixedDelay<T>({
    required Future<T> Function() fn,
    int maxAttempts = _defaultMaxAttempts,
    required Duration delay,
    bool Function(dynamic error)? retryIf,
    void Function(int attempt, dynamic error)? onRetry,
  }) async {
    if (maxAttempts < 1) {
      throw ArgumentError('maxAttempts must be at least 1');
    }

    dynamic lastError;
    int attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;

      try {
        final result = await fn();
        if (attempt > 1) {
          debugPrint('RetryUtility: Operation succeeded on attempt $attempt');
        }
        return result;
      } catch (error) {
        lastError = error;

        // Check if we should retry this error
        if (retryIf != null && !retryIf(error)) {
          debugPrint('RetryUtility: Error not retryable, throwing: $error');
          rethrow;
        }

        // Check if this was the last attempt
        if (attempt >= maxAttempts) {
          debugPrint(
            'RetryUtility: All $maxAttempts attempts failed. Last error: $error',
          );
          rethrow;
        }

        debugPrint(
          'RetryUtility: Attempt $attempt/$maxAttempts failed. '
          'Retrying in ${delay.inSeconds}s. Error: $error',
        );

        // Call onRetry callback if provided
        onRetry?.call(attempt, error);

        // Wait before retrying
        await Future.delayed(delay);
      }
    }

    // This should never be reached, but for type safety
    throw lastError;
  }

  /// Retry a function with custom delay calculation
  ///
  /// Use this when you need custom retry logic (e.g., Fibonacci backoff)
  static Future<T> retryWithCustomDelay<T>({
    required Future<T> Function() fn,
    required Duration Function(int attempt) delayCalculator,
    int maxAttempts = _defaultMaxAttempts,
    bool Function(dynamic error)? retryIf,
    void Function(int attempt, dynamic error)? onRetry,
  }) async {
    if (maxAttempts < 1) {
      throw ArgumentError('maxAttempts must be at least 1');
    }

    dynamic lastError;
    int attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;

      try {
        final result = await fn();
        if (attempt > 1) {
          debugPrint('RetryUtility: Operation succeeded on attempt $attempt');
        }
        return result;
      } catch (error) {
        lastError = error;

        // Check if we should retry this error
        if (retryIf != null && !retryIf(error)) {
          debugPrint('RetryUtility: Error not retryable, throwing: $error');
          rethrow;
        }

        // Check if this was the last attempt
        if (attempt >= maxAttempts) {
          debugPrint(
            'RetryUtility: All $maxAttempts attempts failed. Last error: $error',
          );
          rethrow;
        }

        // Calculate custom delay
        final delay = delayCalculator(attempt);

        debugPrint(
          'RetryUtility: Attempt $attempt/$maxAttempts failed. '
          'Retrying in ${delay.inSeconds}s. Error: $error',
        );

        // Call onRetry callback if provided
        onRetry?.call(attempt, error);

        // Wait before retrying
        await Future.delayed(delay);
      }
    }

    // This should never be reached, but for type safety
    throw lastError;
  }

  /// Common retry predicates for different error types
  static bool isNetworkError(dynamic error) {
    // Check for common network error indicators
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('socket') ||
        errorString.contains('host') ||
        errorString.contains('unreachable');
  }

  static bool isTransientError(dynamic error) {
    // Check for transient/temporary errors
    final errorString = error.toString().toLowerCase();
    return errorString.contains('temporary') ||
        errorString.contains('transient') ||
        errorString.contains('503') || // Service Unavailable
        errorString.contains('504') || // Gateway Timeout
        errorString.contains('429') || // Too Many Requests
        errorString.contains('rate limit');
  }

  static bool isRetryableFirebaseError(dynamic error) {
    // Check for retryable Firebase errors
    final errorString = error.toString().toLowerCase();
    return errorString.contains('unavailable') ||
        errorString.contains('deadline-exceeded') ||
        errorString.contains('internal') ||
        errorString.contains('503') ||
        errorString.contains('504');
  }

  static bool isRetryableMapsError(dynamic error) {
    // Check for retryable Google Maps API errors
    final errorString = error.toString().toLowerCase();
    return errorString.contains('over_query_limit') ||
        errorString.contains('server_error') ||
        errorString.contains('503') ||
        errorString.contains('504');
  }

  /// Pre-configured retry strategies for common use cases
  static Future<T> retryNetworkOperation<T>(Future<T> Function() fn) {
    return retry<T>(
      fn: fn,
      maxAttempts: 3,
      initialDelay: const Duration(seconds: 1),
      backoffMultiplier: 2.0,
      maxDelay: const Duration(seconds: 10),
      retryIf: isNetworkError,
    );
  }

  static Future<T> retryFirebaseOperation<T>(Future<T> Function() fn) {
    return retry<T>(
      fn: fn,
      maxAttempts: 5,
      initialDelay: const Duration(milliseconds: 500),
      backoffMultiplier: 1.5,
      maxDelay: const Duration(seconds: 5),
      retryIf: isRetryableFirebaseError,
    );
  }

  static Future<T> retryMapsOperation<T>(Future<T> Function() fn) {
    return retry<T>(
      fn: fn,
      maxAttempts: 3,
      initialDelay: const Duration(seconds: 2),
      backoffMultiplier: 2.0,
      maxDelay: const Duration(seconds: 16),
      retryIf: isRetryableMapsError,
    );
  }

  static Future<T> retryUploadOperation<T>(Future<T> Function() fn) {
    return retry<T>(
      fn: fn,
      maxAttempts: 5,
      initialDelay: const Duration(seconds: 1),
      backoffMultiplier: 2.0,
      maxDelay: const Duration(seconds: 30),
      retryIf: (error) {
        final errorString = error.toString().toLowerCase();
        return errorString.contains('network') ||
            errorString.contains('timeout') ||
            errorString.contains('connection') ||
            errorString.contains('503') ||
            errorString.contains('504');
      },
    );
  }
}

/// Extension on num for power calculation
extension NumExtension on num {
  num pow(int exponent) {
    if (exponent < 0) {
      throw ArgumentError('Exponent must be non-negative');
    }
    num result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= this;
    }
    return result;
  }
}
