import 'dart:convert';
import 'dart:io';

import 'interface.dart';
import 'level.dart';
import 'record.dart';

/// Handler for log records.
typedef LogHandler = void Function(LogRecord record);

/// Formatter for log records.
typedef LogFormatter = String Function(LogRecord record);

/// ANSI color codes for terminal output.
class _AnsiColors {
  static const reset = '\x1B[0m';
  static const gray = '\x1B[90m';
  static const blue = '\x1B[34m';
  static const yellow = '\x1B[33m';
  static const red = '\x1B[31m';
  static const cyan = '\x1B[36m';
  static const dim = '\x1B[2m';
}

/// Default logger implementation.
class DefaultLogger implements Logger {
  /// Minimum log level to output.
  final LogLevel minLevel;

  /// Output as JSON (true) or text (false).
  /// Ignored if [formatter] is provided.
  final bool json;

  /// Enable colored output (default: true).
  /// Ignored if [formatter] is provided.
  final bool color;

  /// Custom log handler. If null, outputs to stdout/stderr.
  final LogHandler? handler;

  /// Custom formatter. If null, uses default text or JSON format.
  final LogFormatter? formatter;

  /// Default fields to include in every log.
  final Map<String, dynamic> _defaultFields;

  /// Creates a default logger.
  const DefaultLogger({
    this.minLevel = LogLevel.debug,
    this.json = false,
    this.color = true,
    this.handler,
    this.formatter,
    Map<String, dynamic> defaultFields = const {},
  }) : _defaultFields = defaultFields;

  @override
  void debug(String message, [Map<String, dynamic>? fields]) {
    _log(LogLevel.debug, message, fields);
  }

  @override
  void info(String message, [Map<String, dynamic>? fields]) {
    _log(LogLevel.info, message, fields);
  }

  @override
  void warn(String message, [Map<String, dynamic>? fields]) {
    _log(LogLevel.warn, message, fields);
  }

  @override
  void error(
    String message, [
    Map<String, dynamic>? fields,
    Object? err,
    StackTrace? stackTrace,
  ]) {
    _log(LogLevel.error, message, fields, err, stackTrace);
  }

  @override
  Logger withFields(Map<String, dynamic> fields) {
    return DefaultLogger(
      minLevel: minLevel,
      json: json,
      color: color,
      handler: handler,
      formatter: formatter,
      defaultFields: {..._defaultFields, ...fields},
    );
  }

  void _log(
    LogLevel level,
    String message, [
    Map<String, dynamic>? fields,
    Object? err,
    StackTrace? stackTrace,
  ]) {
    if (level.index < minLevel.index) return;

    final record = LogRecord(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      fields: {..._defaultFields, ...?fields},
      error: err,
      stackTrace: stackTrace,
    );

    if (handler != null) {
      handler!(record);
    } else {
      _defaultOutput(record);
    }
  }

  void _defaultOutput(LogRecord record) {
    final output = record.level.index >= LogLevel.warn.index ? stderr : stdout;
    final String text;
    if (formatter != null) {
      text = formatter!(record);
    } else if (json) {
      text = jsonEncode(record.toJson());
    } else {
      text = _formatText(record);
    }
    output.writeln(text);
  }

  String _formatText(LogRecord record) {
    final buffer = StringBuffer();

    // Timestamp (dim)
    if (color) buffer.write(_AnsiColors.dim);
    buffer.write(record.timestamp.toIso8601String());
    if (color) buffer.write(_AnsiColors.reset);
    buffer.write(' ');

    // Level (colored)
    final levelStr = record.level.name.toUpperCase().padRight(5);
    if (color) {
      buffer.write(_levelColor(record.level));
      buffer.write('[$levelStr]');
      buffer.write(_AnsiColors.reset);
    } else {
      buffer.write('[$levelStr]');
    }
    buffer.write(' ');

    // Message
    buffer.write(record.message);

    // Fields (cyan)
    if (record.fields.isNotEmpty) {
      if (color) buffer.write(_AnsiColors.cyan);
      final fieldsStr =
          record.fields.entries.map((e) => '${e.key}=${e.value}').join(' ');
      buffer.write(' $fieldsStr');
      if (color) buffer.write(_AnsiColors.reset);
    }

    // Error (red)
    if (record.error != null) {
      if (color) buffer.write(_AnsiColors.red);
      buffer.write(' error=${record.error}');
      if (color) buffer.write(_AnsiColors.reset);
    }

    return buffer.toString();
  }

  String _levelColor(LogLevel level) {
    return switch (level) {
      LogLevel.debug => _AnsiColors.gray,
      LogLevel.info => _AnsiColors.blue,
      LogLevel.warn => _AnsiColors.yellow,
      LogLevel.error => _AnsiColors.red,
    };
  }
}
