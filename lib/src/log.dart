import 'dart:async';

import 'config.dart';

/// Key for storing log context fields in Zone.
const Symbol _logContextKey = #zlogger.logContext;

/// Zone-based logger with automatic context propagation.
///
/// Use [Log.named] to create a named logger for classes:
/// ```dart
/// class UserService {
///   static final log = Log.named('UserService');
///
///   Future<User> findUser(String id) async {
///     log.info('Finding user', {'userId': id});
///     // Output: ... [INFO] Finding user logger=UserService userId=42
///     return await _repository.find(id);
///   }
/// }
/// ```
///
/// For quick logging without a class name, use the top-level [log] constant:
/// ```dart
/// log.info('message');
/// ```
class Log {
  /// Logger name (typically the class name).
  final String? name;

  const Log._([this.name]);

  /// Creates a named logger.
  ///
  /// Use this to include the class/module name in log output.
  ///
  /// ```dart
  /// class UserService {
  ///   static final log = Log.named('UserService');
  ///
  ///   void doSomething() {
  ///     log.info('message');  // includes logger=UserService
  ///   }
  /// }
  /// ```
  static Log named(String name) => Log._(name);

  /// Gets the current zone context fields.
  static Map<String, dynamic> get _zoneFields {
    final fields = Zone.current[_logContextKey];
    return fields is Map<String, dynamic> ? fields : const {};
  }

  /// Builds fields map with logger name and zone context.
  Map<String, dynamic> _buildFields([Map<String, dynamic>? fields]) {
    return {
      if (name != null) 'logger': name,
      ..._zoneFields,
      ...?fields,
    };
  }

  // ---------------------------------------------------------------------------
  // Instance methods (for named loggers)
  // ---------------------------------------------------------------------------

  /// Logs a debug message.
  void debug(String message, [Map<String, dynamic>? fields]) {
    LogConfig.global.debug(message, _buildFields(fields));
  }

  /// Logs an info message.
  void info(String message, [Map<String, dynamic>? fields]) {
    LogConfig.global.info(message, _buildFields(fields));
  }

  /// Logs a warning message.
  void warn(String message, [Map<String, dynamic>? fields]) {
    LogConfig.global.warn(message, _buildFields(fields));
  }

  /// Logs an error message.
  void error(
    String message, [
    Map<String, dynamic>? fields,
    Object? err,
    StackTrace? stackTrace,
  ]) {
    LogConfig.global.error(message, _buildFields(fields), err, stackTrace);
  }

  // ---------------------------------------------------------------------------
  // Static methods for Zone context management
  // ---------------------------------------------------------------------------

  /// Runs the given function within a log context zone.
  ///
  /// All [Log] calls within [fn] will include [fields] automatically.
  ///
  /// Example:
  /// ```dart
  /// Log.runWithContext({'request_id': 'abc-123'}, () {
  ///   log.info('Processing');  // includes request_id
  ///   await someService.doWork();  // logs here also include request_id
  /// });
  /// ```
  static R runWithContext<R>(Map<String, dynamic> fields, R Function() fn) {
    final merged = {..._zoneFields, ...fields};
    return runZoned(fn, zoneValues: {_logContextKey: merged});
  }

  /// Runs the given async function within a log context zone.
  static Future<R> runWithContextAsync<R>(
    Map<String, dynamic> fields,
    Future<R> Function() fn,
  ) {
    final merged = {..._zoneFields, ...fields};
    return runZoned(fn, zoneValues: {_logContextKey: merged});
  }

  /// Gets the current zone context fields.
  ///
  /// Useful for passing context to external systems.
  static Map<String, dynamic> get currentContext => _zoneFields;
}

/// Default logger instance for quick logging.
///
/// Use this when you don't need a named logger:
/// ```dart
/// log.info('message');
/// log.error('failed', {'op': 'test'}, error, stackTrace);
/// ```
///
/// For named loggers, use [Log.named] instead:
/// ```dart
/// static final log = Log.named('UserService');
/// ```
const log = Log._();
