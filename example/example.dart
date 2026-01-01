/// Example demonstrating zlogger features.
///
/// Run with: dart run example/example.dart
library;

import 'dart:async';

import 'package:zlogger/zlogger.dart';

void main() async {
  // Configure the global logger (optional - defaults work fine)
  LogConfig.global = DefaultLogger(minLevel: LogLevel.debug, color: true);

  print('=== Basic Logging ===\n');

  // Simple logging with top-level `log`
  log.info('Application started');
  log.debug('Debug information', {'version': '1.0.0'});
  log.warn('This is a warning');

  print('\n=== Named Loggers ===\n');

  // Named loggers for classes
  final userService = UserService();
  await userService.findUser('123');

  print('\n=== Zone Context (MDC-style) ===\n');

  // Context propagation - request_id flows through all log calls
  await Log.runWithContextAsync({'request_id': 'req-abc-123'}, () async {
    log.info('Request started');

    // Service logs automatically include request_id
    await userService.findUser('456');

    // Nested context
    Log.runWithContext({'user_id': 'user-789'}, () {
      log.info('Processing for user');
    });

    log.info('Request completed');
  });

  print('\n=== Error Logging ===\n');

  try {
    throw Exception('Something went wrong!');
  } catch (e, st) {
    log.error('Operation failed', {'operation': 'example'}, e, st);
  }

  print('\n=== JSON Output ===\n');

  // JSON output for structured logging
  final jsonLogger = DefaultLogger(json: true);
  LogConfig.global = jsonLogger;

  log.info('JSON formatted log', {'key': 'value', 'count': 42});

  print('''

=== Summary ===

zlogger provides:
  1. log.info() - Simple top-level logging
  2. Log.named('ClassName') - Named loggers with class name
  3. Log.runWithContext() - Zone-based context propagation (MDC-style)
  4. Structured logging with fields
  5. JSON output support
  6. Colored console output
''');
}

// Example service class with named logger
class UserService {
  // Create a named logger - the name appears in all log output
  static final log = Log.named('UserService');

  Future<Map<String, dynamic>> findUser(String id) async {
    log.info('Finding user', {'userId': id});

    // Simulate async work
    await Future.delayed(Duration(milliseconds: 50));

    final user = {'id': id, 'name': 'John Doe'};
    log.debug('User found', {'userId': id, 'name': user['name']});

    return user;
  }
}
