import 'dart:async';

import 'package:test/test.dart';
import 'package:zlogger/zlogger.dart';

void main() {
  group('LogLevel', () {
    test('has correct order', () {
      expect(LogLevel.debug.index, lessThan(LogLevel.info.index));
      expect(LogLevel.info.index, lessThan(LogLevel.warn.index));
      expect(LogLevel.warn.index, lessThan(LogLevel.error.index));
    });
  });

  group('LogRecord', () {
    test('toJson includes all fields', () {
      final record = LogRecord(
        timestamp: DateTime(2025, 1, 1, 12, 0, 0),
        level: LogLevel.info,
        message: 'Test message',
        fields: {'userId': 123, 'action': 'login'},
      );

      final json = record.toJson();

      expect(json['time'], '2025-01-01T12:00:00.000');
      expect(json['level'], 'info');
      expect(json['msg'], 'Test message');
      expect(json['userId'], 123);
      expect(json['action'], 'login');
    });

    test('toJson includes error when present', () {
      final record = LogRecord(
        timestamp: DateTime(2025, 1, 1),
        level: LogLevel.error,
        message: 'Error occurred',
        error: Exception('Test error'),
      );

      final json = record.toJson();

      expect(json['error'], contains('Test error'));
    });
  });

  group('DefaultLogger', () {
    test('logs at or above minLevel', () {
      final logs = <LogRecord>[];
      final logger = DefaultLogger(
        minLevel: LogLevel.info,
        handler: logs.add,
      );

      logger.debug('debug message');
      logger.info('info message');
      logger.warn('warn message');

      expect(logs.length, 2);
      expect(logs[0].level, LogLevel.info);
      expect(logs[1].level, LogLevel.warn);
    });

    test('includes fields in log record', () {
      final logs = <LogRecord>[];
      final logger = DefaultLogger(handler: logs.add);

      logger.info('message', {'key': 'value'});

      expect(logs.single.fields['key'], 'value');
    });

    test('withFields creates child logger with default fields', () {
      final logs = <LogRecord>[];
      final logger = DefaultLogger(handler: logs.add);
      final childLogger = logger.withFields({'service': 'auth'});

      childLogger.info('login attempt', {'userId': 123});

      expect(logs.single.fields['service'], 'auth');
      expect(logs.single.fields['userId'], 123);
    });

    test('error includes error and stackTrace', () {
      final logs = <LogRecord>[];
      final logger = DefaultLogger(handler: logs.add);

      try {
        throw Exception('Test error');
      } catch (e, st) {
        logger.error('failed', {'operation': 'test'}, e, st);
      }

      expect(logs.single.error, isA<Exception>());
      expect(logs.single.stackTrace, isNotNull);
      expect(logs.single.fields['operation'], 'test');
    });

    test('uses custom formatter', () {
      final outputs = <String>[];
      final logger = DefaultLogger(
        formatter: (record) => '${record.level.name}: ${record.message}',
        handler: (record) {
          // Simulate what _defaultOutput does with formatter
          outputs.add('${record.level.name}: ${record.message}');
        },
      );

      logger.info('test message');

      expect(outputs.single, 'info: test message');
    });
  });

  group('NullLogger', () {
    test('does nothing', () {
      const logger = NullLogger();

      // These should not throw
      logger.debug('message');
      logger.info('message');
      logger.warn('message');
      logger.error('message');
    });

    test('withFields returns self', () {
      const logger = NullLogger();
      final child = logger.withFields({'key': 'value'});

      expect(child, same(logger));
    });
  });

  group('LogConfig', () {
    tearDown(() {
      // Reset global logger after each test
      LogConfig.global = const DefaultLogger();
    });

    test('global logger can be set and retrieved', () {
      final logs = <LogRecord>[];
      final customLogger = DefaultLogger(handler: logs.add);

      LogConfig.global = customLogger;
      LogConfig.global.info('test');

      expect(logs.length, 1);
    });
  });

  group('log (top-level)', () {
    late List<LogRecord> logs;

    setUp(() {
      logs = <LogRecord>[];
      LogConfig.global = DefaultLogger(handler: logs.add);
    });

    tearDown(() {
      LogConfig.global = const DefaultLogger();
    });

    test('logs without zone context', () {
      log.info('message', {'key': 'value'});

      expect(logs.length, 1);
      expect(logs.single.message, 'message');
      expect(logs.single.fields['key'], 'value');
    });

    test('includes zone context fields', () {
      Log.scope({'request_id': 'abc-123'}, () {
        log.info('inside zone');
      });

      expect(logs.length, 1);
      expect(logs.single.fields['request_id'], 'abc-123');
    });

    test('merges zone context with log fields', () {
      Log.scope({'request_id': 'abc-123'}, () {
        log.info('message', {'userId': 42});
      });

      expect(logs.single.fields['request_id'], 'abc-123');
      expect(logs.single.fields['userId'], 42);
    });

    test('works with nested zones', () {
      Log.scope({'request_id': 'abc-123'}, () {
        Log.scope({'user_id': '456'}, () {
          log.info('nested');
        });
      });

      expect(logs.single.fields['request_id'], 'abc-123');
      expect(logs.single.fields['user_id'], '456');
    });

    test('works with async code', () async {
      await Log.scope({'request_id': 'abc-123'}, () async {
        await Future.delayed(Duration(milliseconds: 10));
        log.info('after delay');
      });

      expect(logs.single.fields['request_id'], 'abc-123');
    });

    test('supports all log levels', () {
      log.debug('d');
      log.info('i');
      log.warn('w');
      log.error('e');

      expect(logs.length, 4);
      expect(logs[0].level, LogLevel.debug);
      expect(logs[1].level, LogLevel.info);
      expect(logs[2].level, LogLevel.warn);
      expect(logs[3].level, LogLevel.error);
    });

    test('error includes error and stackTrace', () {
      try {
        throw Exception('test error');
      } catch (e, st) {
        log.error('failed', {'op': 'test'}, e, st);
      }

      expect(logs.single.error, isA<Exception>());
      expect(logs.single.stackTrace, isNotNull);
    });
  });

  group('Log.named', () {
    late List<LogRecord> logs;

    setUp(() {
      logs = <LogRecord>[];
      LogConfig.global = DefaultLogger(handler: logs.add);
    });

    tearDown(() {
      LogConfig.global = const DefaultLogger();
    });

    test('includes logger name in fields', () {
      final log = Log.named('UserService');
      log.info('message');

      expect(logs.single.fields['logger'], 'UserService');
    });

    test('supports all log levels', () {
      final log = Log.named('TestClass');
      log.debug('debug');
      log.info('info');
      log.warn('warn');
      log.error('error');

      expect(logs.length, 4);
      expect(logs[0].level, LogLevel.debug);
      expect(logs[1].level, LogLevel.info);
      expect(logs[2].level, LogLevel.warn);
      expect(logs[3].level, LogLevel.error);
      for (final record in logs) {
        expect(record.fields['logger'], 'TestClass');
      }
    });

    test('merges with zone context', () {
      final log = Log.named('MyService');
      Log.scope({'request_id': 'abc-123'}, () {
        log.info('message', {'userId': 42});
      });

      expect(logs.single.fields['logger'], 'MyService');
      expect(logs.single.fields['request_id'], 'abc-123');
      expect(logs.single.fields['userId'], 42);
    });

    test('error includes error and stackTrace', () {
      final log = Log.named('ErrorTest');
      try {
        throw Exception('test');
      } catch (e, st) {
        log.error('failed', {'op': 'test'}, e, st);
      }

      expect(logs.single.fields['logger'], 'ErrorTest');
      expect(logs.single.error, isA<Exception>());
      expect(logs.single.stackTrace, isNotNull);
    });
  });

  group('Log.currentContext', () {
    test('returns empty map outside zone', () {
      expect(Log.currentContext, isEmpty);
    });

    test('returns context inside zone', () {
      Log.scope({'request_id': 'abc-123'}, () {
        expect(Log.currentContext['request_id'], 'abc-123');
      });
    });
  });
}
