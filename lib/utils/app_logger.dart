import 'package:flutter/foundation.dart';

/// Простой логгер с ограничением спама в консоли.
class AppLogger {
  static final Map<String, int> _counters = <String, int>{};

  static int _next(String key) {
    final n = (_counters[key] ?? 0) + 1;
    _counters[key] = n;
    return n;
  }

  static void warn(
    String key,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    final n = _next(key);
    if (n <= 5 || n % 50 == 0) {
      debugPrint('[WARN][$key] #$n $message'
          '${error != null ? ' | error: $error' : ''}'
          '${data != null ? ' | data: $data' : ''}');
      if (stackTrace != null && n <= 2) {
        debugPrint(stackTrace.toString());
      }
    }
  }

  static void error(
    String key,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    final n = _next(key);
    debugPrint('[ERROR][$key] #$n $message'
        '${error != null ? ' | error: $error' : ''}'
        '${data != null ? ' | data: $data' : ''}');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}
