/// A lightweight, zone-based structured logger for Dart.
///
/// Features:
/// - Simple API: `log.info('message')`
/// - Named loggers: `Log.named('UserService')`
/// - Zone-based context propagation (MDC-style)
/// - Structured logging with fields
/// - JSON output support
/// - Colored console output
///
/// ## Quick Start
///
/// ```dart
/// import 'package:zlogger/zlogger.dart';
///
/// void main() {
///   // Simple logging
///   log.info('Application started');
///   log.debug('Debug info', {'key': 'value'});
///
///   // With context (request_id propagates to all log calls)
///   Log.runWithContext({'request_id': 'abc-123'}, () {
///     log.info('Processing request');
///     myService.doWork(); // logs here also include request_id
///   });
/// }
/// ```
///
/// ## Named Loggers
///
/// ```dart
/// class UserService {
///   static final log = Log.named('UserService');
///
///   void findUser(String id) {
///     log.info('Finding user', {'userId': id});
///     // Output: ... [INFO] Finding user logger=UserService userId=123
///   }
/// }
/// ```
library;

export 'src/config.dart';
export 'src/default_logger.dart';
export 'src/interface.dart';
export 'src/level.dart';
export 'src/log.dart';
export 'src/null_logger.dart';
export 'src/record.dart';
