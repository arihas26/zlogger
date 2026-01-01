/// Abstract logger interface.
abstract class Logger {
  /// Logs a debug message.
  void debug(String message, [Map<String, dynamic>? fields]);

  /// Logs an info message.
  void info(String message, [Map<String, dynamic>? fields]);

  /// Logs a warning message.
  void warn(String message, [Map<String, dynamic>? fields]);

  /// Logs an error message.
  void error(
    String message, [
    Map<String, dynamic>? fields,
    Object? err,
    StackTrace? stackTrace,
  ]);

  /// Creates a child logger with additional default fields.
  Logger withFields(Map<String, dynamic> fields);
}
