import 'interface.dart';

/// A silent logger that does nothing.
class NullLogger implements Logger {
  const NullLogger();

  @override
  void debug(String message, [Map<String, dynamic>? fields]) {}

  @override
  void info(String message, [Map<String, dynamic>? fields]) {}

  @override
  void warn(String message, [Map<String, dynamic>? fields]) {}

  @override
  void error(
    String message, [
    Map<String, dynamic>? fields,
    Object? err,
    StackTrace? stackTrace,
  ]) {}

  @override
  Logger withFields(Map<String, dynamic> fields) => this;
}
