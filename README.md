# zlogger

[![日本語](https://img.shields.io/badge/lang-日本語-blue.svg)](README_ja.md)

A lightweight, zone-based structured logger for Dart with propagation.

## Features

- **Simple API** - `log.info('message')` just works
- **Named Loggers** - `Log.named('UserService')` for class-specific logging
- **Zone Context** - Automatic context propagation (like Java's MDC)
- **Structured Logging** - Add fields to any log message
- **JSON Output** - Machine-readable log format
- **Colored Output** - Beautiful terminal output
- **Zero Dependencies** - Only uses `dart:async`, `dart:convert`, `dart:io`

## Quick Start

```dart
import 'package:zlogger/zlogger.dart';

void main() {
  // Simple logging
  log.info('Application started');
  log.debug('Debug info', {'version': '1.0.0'});
  log.warn('Warning message');
  log.error('Error occurred', {'code': 500}, error, stackTrace);
}
```

## Named Loggers

For classes, use `Log.named()` to include the class name in logs:

```dart
class UserService {
  static final log = Log.named('UserService');

  Future<User> findUser(String id) async {
    log.info('Finding user', {'userId': id});
    // Output: 2025-01-01T12:00:00.000 [INFO] Finding user logger=UserService userId=123

    return await repository.find(id);
  }
}
```

## Zone Context (MDC-style)

Propagate context (like `request_id`) through your entire call stack:

```dart
// In your HTTP middleware
Future<void> handleRequest(Request request) async {
  final requestId = generateRequestId();

  await Log.scope({'request_id': requestId}, () async {
    log.info('Request started');

    // All logs in services automatically include request_id!
    await userService.findUser(request.userId);
    await orderService.getOrders(request.userId);

    log.info('Request completed');
  });
}
```

All log calls within the zone automatically include the context:

```
2025-01-01T12:00:00.000 [INFO] Request started request_id=abc-123
2025-01-01T12:00:00.010 [INFO] Finding user logger=UserService request_id=abc-123 userId=42
2025-01-01T12:00:00.020 [INFO] Getting orders logger=OrderService request_id=abc-123 userId=42
2025-01-01T12:00:00.030 [INFO] Request completed request_id=abc-123
```

## Configuration

### Log Level

```dart
LogConfig.global = DefaultLogger(minLevel: LogLevel.info);
```

### JSON Output

```dart
LogConfig.global = DefaultLogger(json: true);
// Output: {"time":"2025-01-01T12:00:00.000","level":"info","msg":"Hello","userId":123}
```

### Disable Colors

```dart
LogConfig.global = DefaultLogger(color: false);
```

### Custom Formatter

```dart
LogConfig.global = DefaultLogger(
  formatter: (record) {
    return '[${record.level.name.toUpperCase()}] ${record.message}';
  },
);
// Output: [INFO] Application started
```

### Custom Handler

```dart
LogConfig.global = DefaultLogger(
  handler: (record) {
    // Send to external service, file, etc.
    myLogService.send(record.toJson());
  },
);
```

## API Reference

### Log Levels

| Level | Method | Description |
|-------|--------|-------------|
| debug | `log.debug()` | Detailed debugging information |
| info | `log.info()` | General information |
| warn | `log.warn()` | Warning conditions |
| error | `log.error()` | Error conditions |

### Top-level `log`

```dart
log.info('message');
log.info('message', {'key': 'value'});
log.error('failed', {'op': 'test'}, error, stackTrace);
```

### Named Logger

```dart
final log = Log.named('MyClass');
log.info('message');  // includes logger=MyClass
```

### Zone Context

```dart
// Sync
Log.scope({'request_id': 'abc'}, () {
  log.info('includes request_id');
});

// Async
await Log.scope({'request_id': 'abc'}, () async {
  await someAsyncWork();
  log.info('still includes request_id');
});

// Access current context
final ctx = Log.currentContext;
print(ctx['request_id']);
```

## Comparison with Other Loggers

| Feature | zlogger | logger | logging |
|---------|---------|--------|---------|
| Simple API | `log.info()` | `logger.i()` | `log.info()` |
| Named Loggers | ✅ | ❌ | ✅ |
| Zone/MDC Context | ✅ | ❌ | ❌ |
| Structured Fields | ✅ | ❌ | ❌ |
| JSON Output | ✅ | ❌ | ❌ |
| Zero Dependencies | ✅ | ❌ | ✅ |

## License

MIT
