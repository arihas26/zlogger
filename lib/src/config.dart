import 'default_logger.dart';
import 'interface.dart';

/// Global logger instance.
Logger _globalLogger = const DefaultLogger();

/// Configuration for the global logger.
class LogConfig {
  LogConfig._();

  /// Gets the global logger instance.
  static Logger get global => _globalLogger;

  /// Sets the global logger instance.
  static set global(Logger logger) => _globalLogger = logger;
}
