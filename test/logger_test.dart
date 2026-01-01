import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zlogger/zlogger.dart';

/// Captures stdout/stderr output during a function execution.
Future<({String stdout, String stderr})> captureOutput(
  Future<void> Function() fn,
) async {
  final stdoutBuffer = StringBuffer();
  final stderrBuffer = StringBuffer();

  await IOOverrides.runZoned(
    () async => await fn(),
    stdout: () => _MockStdout(stdoutBuffer),
    stderr: () => _MockStdout(stderrBuffer),
  );

  return (stdout: stdoutBuffer.toString(), stderr: stderrBuffer.toString());
}

class _MockStdout implements Stdout {
  final StringBuffer buffer;
  _MockStdout(this.buffer);

  @override
  void writeln([Object? object = '']) => buffer.writeln(object);

  @override
  void write(Object? object) => buffer.write(object);

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding encoding) {}

  @override
  void add(List<int> data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) => Future.value();

  @override
  Future close() => Future.value();

  @override
  Future get done => Future.value();

  @override
  Future flush() => Future.value();

  @override
  bool get hasTerminal => false;

  @override
  IOSink get nonBlocking => this;

  @override
  bool get supportsAnsiEscapes => true;

  @override
  int get terminalColumns => 80;

  @override
  int get terminalLines => 24;

  @override
  void writeAll(Iterable objects, [String sep = '']) {
    buffer.writeAll(objects, sep);
  }

  @override
  void writeCharCode(int charCode) {
    buffer.writeCharCode(charCode);
  }

  @override
  String get lineTerminator => '\n';

  @override
  set lineTerminator(String lineTerminator) {}
}

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

  group('LogRecord (additional)', () {
    test('toJson includes stackTrace when present', () {
      final stackTrace = StackTrace.current;
      final record = LogRecord(
        timestamp: DateTime(2025, 1, 1),
        level: LogLevel.error,
        message: 'Error with stack',
        stackTrace: stackTrace,
      );

      final json = record.toJson();

      expect(json['stack'], isNotNull);
      expect(json['stack'], contains('logger_test.dart'));
    });

    test('toJson with empty fields', () {
      final record = LogRecord(
        timestamp: DateTime(2025, 1, 1, 12, 0, 0),
        level: LogLevel.info,
        message: 'No fields',
      );

      final json = record.toJson();

      expect(json['time'], '2025-01-01T12:00:00.000');
      expect(json['level'], 'info');
      expect(json['msg'], 'No fields');
      expect(json.keys, containsAll(['time', 'level', 'msg']));
    });

    test('toJson with both error and stackTrace', () {
      final record = LogRecord(
        timestamp: DateTime(2025, 1, 1),
        level: LogLevel.error,
        message: 'Full error',
        error: Exception('Test'),
        stackTrace: StackTrace.current,
      );

      final json = record.toJson();

      expect(json['error'], contains('Test'));
      expect(json['stack'], isNotNull);
    });
  });

  group('DefaultLogger output formats', () {
    test('formats JSON output correctly', () {
      final outputs = <String>[];
      final logger = DefaultLogger(
        json: true,
        handler: (record) {
          // Capture what would be JSON output
          outputs.add(record.toJson().toString());
        },
      );

      logger.info('test message', {'userId': 123});

      expect(outputs.single, contains('info'));
      expect(outputs.single, contains('test message'));
      expect(outputs.single, contains('123'));
    });

    test('filters by minLevel for all levels', () {
      final logs = <LogRecord>[];

      // Test minLevel = warn
      final warnLogger = DefaultLogger(
        minLevel: LogLevel.warn,
        handler: logs.add,
      );

      warnLogger.debug('debug');
      warnLogger.info('info');
      warnLogger.warn('warn');
      warnLogger.error('error');

      expect(logs.length, 2);
      expect(logs[0].level, LogLevel.warn);
      expect(logs[1].level, LogLevel.error);

      logs.clear();

      // Test minLevel = error
      final errorLogger = DefaultLogger(
        minLevel: LogLevel.error,
        handler: logs.add,
      );

      errorLogger.debug('debug');
      errorLogger.info('info');
      errorLogger.warn('warn');
      errorLogger.error('error');

      expect(logs.length, 1);
      expect(logs.single.level, LogLevel.error);
    });

    test('uses defaultFields from constructor', () {
      final logs = <LogRecord>[];
      final logger = DefaultLogger(
        handler: logs.add,
        defaultFields: {'app': 'test-app', 'version': '1.0.0'},
      );

      logger.info('message');

      expect(logs.single.fields['app'], 'test-app');
      expect(logs.single.fields['version'], '1.0.0');
    });

    test('log fields override defaultFields', () {
      final logs = <LogRecord>[];
      final logger = DefaultLogger(
        handler: logs.add,
        defaultFields: {'key': 'default'},
      );

      logger.info('message', {'key': 'override'});

      expect(logs.single.fields['key'], 'override');
    });

    test('withFields preserves all settings', () {
      final logs = <LogRecord>[];
      final logger = DefaultLogger(
        minLevel: LogLevel.warn,
        json: true,
        color: false,
        handler: logs.add,
        defaultFields: {'base': 'value'},
      );

      final child = logger.withFields({'child': 'field'});
      child.info('should be filtered'); // Below minLevel
      child.warn('should appear');

      expect(logs.length, 1);
      expect(logs.single.fields['base'], 'value');
      expect(logs.single.fields['child'], 'field');
    });

    test('error without optional parameters', () {
      final logs = <LogRecord>[];
      final logger = DefaultLogger(handler: logs.add);

      logger.error('simple error');

      expect(logs.single.message, 'simple error');
      expect(logs.single.error, isNull);
      expect(logs.single.stackTrace, isNull);
    });

    test('error with only error object', () {
      final logs = <LogRecord>[];
      final logger = DefaultLogger(handler: logs.add);

      logger.error('with error', null, Exception('test'));

      expect(logs.single.error, isA<Exception>());
      expect(logs.single.stackTrace, isNull);
      expect(logs.single.fields, isEmpty);
    });
  });

  group('Log.scope (additional)', () {
    late List<LogRecord> logs;

    setUp(() {
      logs = <LogRecord>[];
      LogConfig.global = DefaultLogger(handler: logs.add);
    });

    tearDown(() {
      LogConfig.global = const DefaultLogger();
    });

    test('returns sync value', () {
      final result = Log.scope({'key': 'value'}, () {
        return 42;
      });

      expect(result, 42);
    });

    test('returns async value', () async {
      final result = await Log.scope({'key': 'value'}, () async {
        await Future.delayed(Duration(milliseconds: 1));
        return 'async result';
      });

      expect(result, 'async result');
    });

    test('log fields override zone context', () {
      Log.scope({'key': 'zone-value'}, () {
        log.info('message', {'key': 'log-value'});
      });

      expect(logs.single.fields['key'], 'log-value');
    });

    test('inner zone overrides outer zone', () {
      Log.scope({'key': 'outer'}, () {
        Log.scope({'key': 'inner'}, () {
          log.info('message');
        });
      });

      expect(logs.single.fields['key'], 'inner');
    });

    test('context is isolated between zones', () {
      Log.scope({'request': 'first'}, () {
        log.info('first request');
      });

      Log.scope({'request': 'second'}, () {
        log.info('second request');
      });

      expect(logs.length, 2);
      expect(logs[0].fields['request'], 'first');
      expect(logs[1].fields['request'], 'second');
    });

    test('deeply nested zones accumulate context', () {
      Log.scope({'a': '1'}, () {
        Log.scope({'b': '2'}, () {
          Log.scope({'c': '3'}, () {
            log.info('deep');
          });
        });
      });

      expect(logs.single.fields['a'], '1');
      expect(logs.single.fields['b'], '2');
      expect(logs.single.fields['c'], '3');
    });
  });

  group('Log.named (additional)', () {
    late List<LogRecord> logs;

    setUp(() {
      logs = <LogRecord>[];
      LogConfig.global = DefaultLogger(handler: logs.add);
    });

    tearDown(() {
      LogConfig.global = const DefaultLogger();
    });

    test('logger name appears first in fields', () {
      final namedLog = Log.named('ServiceA');
      Log.scope({'request_id': 'req-123'}, () {
        namedLog.info('message', {'action': 'test'});
      });

      final fields = logs.single.fields;
      expect(fields['logger'], 'ServiceA');
      expect(fields['request_id'], 'req-123');
      expect(fields['action'], 'test');
    });

    test('multiple named loggers work independently', () {
      final logA = Log.named('ServiceA');
      final logB = Log.named('ServiceB');

      logA.info('from A');
      logB.info('from B');

      expect(logs.length, 2);
      expect(logs[0].fields['logger'], 'ServiceA');
      expect(logs[1].fields['logger'], 'ServiceB');
    });

    test('error with all parameters', () {
      final namedLog = Log.named('ErrorService');
      final error = FormatException('bad format');
      final stack = StackTrace.current;

      namedLog.error('failed', {'code': 500}, error, stack);

      expect(logs.single.fields['logger'], 'ErrorService');
      expect(logs.single.fields['code'], 500);
      expect(logs.single.error, error);
      expect(logs.single.stackTrace, stack);
    });
  });

  group('LogLevel', () {
    test('all levels have correct names', () {
      expect(LogLevel.debug.name, 'debug');
      expect(LogLevel.info.name, 'info');
      expect(LogLevel.warn.name, 'warn');
      expect(LogLevel.error.name, 'error');
    });

    test('values list contains all levels in order', () {
      expect(LogLevel.values, [
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warn,
        LogLevel.error,
      ]);
    });
  });

  group('Edge cases', () {
    late List<LogRecord> logs;

    setUp(() {
      logs = <LogRecord>[];
      LogConfig.global = DefaultLogger(handler: logs.add);
    });

    tearDown(() {
      LogConfig.global = const DefaultLogger();
    });

    test('empty message', () {
      log.info('');
      expect(logs.single.message, '');
    });

    test('null values in fields', () {
      log.info('message', {'nullKey': null});
      expect(logs.single.fields['nullKey'], isNull);
    });

    test('complex field values', () {
      log.info('message', {
        'list': [1, 2, 3],
        'map': {'nested': 'value'},
        'bool': true,
        'double': 3.14,
      });

      expect(logs.single.fields['list'], [1, 2, 3]);
      expect(logs.single.fields['map'], {'nested': 'value'});
      expect(logs.single.fields['bool'], true);
      expect(logs.single.fields['double'], 3.14);
    });

    test('special characters in message', () {
      log.info('Line1\nLine2\tTabbed');
      expect(logs.single.message, 'Line1\nLine2\tTabbed');
    });

    test('unicode in message and fields', () {
      log.info('日本語メッセージ 🎉', {'emoji': '👍', 'kanji': '漢字'});

      expect(logs.single.message, '日本語メッセージ 🎉');
      expect(logs.single.fields['emoji'], '👍');
      expect(logs.single.fields['kanji'], '漢字');
    });

    test('very long message', () {
      final longMessage = 'x' * 10000;
      log.info(longMessage);
      expect(logs.single.message.length, 10000);
    });

    test('many fields', () {
      final manyFields = {for (var i = 0; i < 100; i++) 'key$i': 'value$i'};
      log.info('message', manyFields);
      expect(logs.single.fields.length, 100);
    });

    test('concurrent logging in different zones', () async {
      final futures = <Future<void>>[];

      for (var i = 0; i < 10; i++) {
        futures.add(
          Log.scope({'index': i}, () async {
            await Future.delayed(Duration(milliseconds: i));
            log.info('message $i');
          }),
        );
      }

      await Future.wait(futures);

      expect(logs.length, 10);
      for (var i = 0; i < 10; i++) {
        final record = logs.firstWhere((r) => r.message == 'message $i');
        expect(record.fields['index'], i);
      }
    });
  });

  group('DefaultLogger output (stdout/stderr)', () {
    test('debug and info output to stdout', () async {
      final logger = const DefaultLogger(color: false);

      final output = await captureOutput(() async {
        logger.debug('debug message');
        logger.info('info message');
      });

      expect(output.stdout, contains('debug message'));
      expect(output.stdout, contains('info message'));
      expect(output.stderr, isEmpty);
    });

    test('warn and error output to stderr', () async {
      final logger = const DefaultLogger(color: false);

      final output = await captureOutput(() async {
        logger.warn('warn message');
        logger.error('error message');
      });

      expect(output.stderr, contains('warn message'));
      expect(output.stderr, contains('error message'));
      expect(output.stdout, isEmpty);
    });

    test('text format includes timestamp, level, message', () async {
      final logger = const DefaultLogger(color: false);

      final output = await captureOutput(() async {
        logger.info('test message');
      });

      // Check format: timestamp [LEVEL] message
      expect(output.stdout, contains('[INFO ]'));
      expect(output.stdout, contains('test message'));
      // ISO 8601 timestamp pattern
      expect(
        output.stdout,
        matches(RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}')),
      );
    });

    test('text format includes fields', () async {
      final logger = const DefaultLogger(color: false);

      final output = await captureOutput(() async {
        logger.info('message', {'userId': 123, 'action': 'login'});
      });

      expect(output.stdout, contains('userId=123'));
      expect(output.stdout, contains('action=login'));
    });

    test('text format includes error', () async {
      final logger = const DefaultLogger(color: false);

      final output = await captureOutput(() async {
        logger.error('failed', null, Exception('test error'));
      });

      expect(output.stderr, contains('error=Exception: test error'));
    });

    test('colored output includes ANSI codes', () async {
      final logger = const DefaultLogger(color: true);

      final output = await captureOutput(() async {
        logger.info('colored message');
      });

      // Check for ANSI escape codes
      expect(output.stdout, contains('\x1B['));
    });

    test('non-colored output has no ANSI codes', () async {
      final logger = const DefaultLogger(color: false);

      final output = await captureOutput(() async {
        logger.info('plain message');
      });

      expect(output.stdout, isNot(contains('\x1B[')));
    });

    test('JSON output format', () async {
      final logger = const DefaultLogger(json: true);

      final output = await captureOutput(() async {
        logger.info('json test', {'key': 'value'});
      });

      final jsonOutput = jsonDecode(output.stdout.trim());
      expect(jsonOutput['level'], 'info');
      expect(jsonOutput['msg'], 'json test');
      expect(jsonOutput['key'], 'value');
      expect(jsonOutput['time'], isNotNull);
    });

    test('JSON output with error and stackTrace', () async {
      final logger = const DefaultLogger(json: true);

      final output = await captureOutput(() async {
        try {
          throw Exception('json error');
        } catch (e, st) {
          logger.error('failed', {'code': 500}, e, st);
        }
      });

      final jsonOutput = jsonDecode(output.stderr.trim());
      expect(jsonOutput['level'], 'error');
      expect(jsonOutput['msg'], 'failed');
      expect(jsonOutput['code'], 500);
      expect(jsonOutput['error'], contains('json error'));
      expect(jsonOutput['stack'], isNotNull);
    });

    test('custom formatter is used for output', () async {
      final logger = DefaultLogger(
        formatter: (record) => 'CUSTOM: ${record.message}',
      );

      final output = await captureOutput(() async {
        logger.info('formatter test');
      });

      expect(output.stdout.trim(), 'CUSTOM: formatter test');
    });

    test('custom formatter with all record fields', () async {
      final logger = DefaultLogger(
        formatter: (record) {
          return '${record.level.name}|${record.message}|${record.fields}';
        },
      );

      final output = await captureOutput(() async {
        logger.warn('test', {'key': 'val'});
      });

      expect(output.stderr, contains('warn|test|{key: val}'));
    });

    test('all log levels use correct colors', () async {
      final logger = const DefaultLogger(color: true);

      // Debug - gray
      var output = await captureOutput(() async {
        logger.debug('debug');
      });
      expect(output.stdout, contains('\x1B[90m')); // gray

      // Info - blue
      output = await captureOutput(() async {
        logger.info('info');
      });
      expect(output.stdout, contains('\x1B[34m')); // blue

      // Warn - yellow
      output = await captureOutput(() async {
        logger.warn('warn');
      });
      expect(output.stderr, contains('\x1B[33m')); // yellow

      // Error - red
      output = await captureOutput(() async {
        logger.error('error');
      });
      expect(output.stderr, contains('\x1B[31m')); // red
    });

    test('fields are colored cyan', () async {
      final logger = const DefaultLogger(color: true);

      final output = await captureOutput(() async {
        logger.info('message', {'key': 'value'});
      });

      expect(output.stdout, contains('\x1B[36m')); // cyan for fields
    });

    test('error in output is colored red', () async {
      final logger = const DefaultLogger(color: true);

      final output = await captureOutput(() async {
        logger.error('failed', null, Exception('err'));
      });

      // Should contain red color code for error
      final redCount = '\x1B[31m'.allMatches(output.stderr).length;
      expect(redCount, greaterThanOrEqualTo(2)); // level + error
    });

    test('timestamp is dimmed', () async {
      final logger = const DefaultLogger(color: true);

      final output = await captureOutput(() async {
        logger.info('message');
      });

      expect(output.stdout, contains('\x1B[2m')); // dim
    });
  });
}
