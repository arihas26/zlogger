import 'level.dart';

/// A structured log entry.
class LogRecord {
  /// Timestamp when the log was created.
  final DateTime timestamp;

  /// Log level.
  final LogLevel level;

  /// Log message.
  final String message;

  /// Additional fields.
  final Map<String, dynamic> fields;

  /// Error object if present.
  final Object? error;

  /// Stack trace if present.
  final StackTrace? stackTrace;

  const LogRecord({
    required this.timestamp,
    required this.level,
    required this.message,
    this.fields = const {},
    this.error,
    this.stackTrace,
  });

  /// Converts to JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'time': timestamp.toIso8601String(),
      'level': level.name,
      'msg': message,
      ...fields,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stack': stackTrace.toString(),
    };
  }
}
