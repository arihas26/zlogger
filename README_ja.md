# zlogger

[![English](https://img.shields.io/badge/lang-English-blue.svg)](README.md)

Dart向けの軽量なZoneベース構造化ロガー。MDCスタイルのコンテキスト伝播機能付き。

## 特徴

- **シンプルなAPI** - `log.info('message')` ですぐ使える
- **名前付きロガー** - `Log.named('UserService')` でクラス名をログに含める
- **Zoneコンテキスト** - JavaのMDCのような自動コンテキスト伝播
- **構造化ログ** - 任意のフィールドをログに追加
- **JSON出力** - 機械可読なログフォーマット
- **カラー出力** - ターミナルでの見やすい表示
- **依存ゼロ** - `dart:async`, `dart:convert`, `dart:io` のみ使用

## クイックスタート

```dart
import 'package:zlogger/zlogger.dart';

void main() {
  // シンプルなログ出力
  log.info('アプリケーション開始');
  log.debug('デバッグ情報', {'version': '1.0.0'});
  log.warn('警告メッセージ');
  log.error('エラー発生', {'code': 500}, error, stackTrace);
}
```

## 名前付きロガー

クラスでは `Log.named()` を使ってクラス名をログに含める：

```dart
class UserService {
  static final log = Log.named('UserService');

  Future<User> findUser(String id) async {
    log.info('ユーザー検索', {'userId': id});
    // 出力: 2025-01-01T12:00:00.000 [INFO] ユーザー検索 logger=UserService userId=123

    return await repository.find(id);
  }
}
```

## Zoneコンテキスト（MDCスタイル）

`request_id` などのコンテキストをコールスタック全体に伝播：

```dart
// HTTPミドルウェア内で
Future<void> handleRequest(Request request) async {
  final requestId = generateRequestId();

  await Log.scope({'request_id': requestId}, () async {
    log.info('リクエスト開始');

    // サービス内の全てのログに自動でrequest_idが含まれる！
    await userService.findUser(request.userId);
    await orderService.getOrders(request.userId);

    log.info('リクエスト完了');
  });
}
```

Zone内の全てのログ呼び出しにコンテキストが自動で含まれる：

```
2025-01-01T12:00:00.000 [INFO] リクエスト開始 request_id=abc-123
2025-01-01T12:00:00.010 [INFO] ユーザー検索 logger=UserService request_id=abc-123 userId=42
2025-01-01T12:00:00.020 [INFO] 注文取得 logger=OrderService request_id=abc-123 userId=42
2025-01-01T12:00:00.030 [INFO] リクエスト完了 request_id=abc-123
```

## 設定

### ログレベル

```dart
LogConfig.global = DefaultLogger(minLevel: LogLevel.info);
```

### JSON出力

```dart
LogConfig.global = DefaultLogger(json: true);
// 出力: {"time":"2025-01-01T12:00:00.000","level":"info","msg":"Hello","userId":123}
```

### カラー無効化

```dart
LogConfig.global = DefaultLogger(color: false);
```

### カスタムフォーマッタ

```dart
LogConfig.global = DefaultLogger(
  formatter: (record) {
    return '[${record.level.name.toUpperCase()}] ${record.message}';
  },
);
// 出力: [INFO] アプリケーション開始
```

### カスタムハンドラ

```dart
LogConfig.global = DefaultLogger(
  handler: (record) {
    // 外部サービス、ファイルなどに送信
    myLogService.send(record.toJson());
  },
);
```

## APIリファレンス

### ログレベル

| レベル | メソッド | 説明 |
|-------|--------|------|
| debug | `log.debug()` | 詳細なデバッグ情報 |
| info | `log.info()` | 一般的な情報 |
| warn | `log.warn()` | 警告 |
| error | `log.error()` | エラー |

### トップレベル `log`

```dart
log.info('メッセージ');
log.info('メッセージ', {'key': 'value'});
log.error('失敗', {'op': 'test'}, error, stackTrace);
```

### 名前付きロガー

```dart
final log = Log.named('MyClass');
log.info('メッセージ');  // logger=MyClass が含まれる
```

### Zoneコンテキスト

```dart
// 同期
Log.scope({'request_id': 'abc'}, () {
  log.info('request_idが含まれる');
});

// 非同期
await Log.scope({'request_id': 'abc'}, () async {
  await someAsyncWork();
  log.info('まだrequest_idが含まれる');
});

// 現在のコンテキストを取得
final ctx = Log.currentContext;
print(ctx['request_id']);
```

## 他のロガーとの比較

| 機能 | zlogger | logger | logging |
|------|---------|--------|---------|
| シンプルAPI | `log.info()` | `logger.i()` | `log.info()` |
| 名前付きロガー | ✅ | ❌ | ✅ |
| Zone/MDCコンテキスト | ✅ | ❌ | ❌ |
| 構造化フィールド | ✅ | ❌ | ❌ |
| JSON出力 | ✅ | ❌ | ❌ |
| 依存ゼロ | ✅ | ❌ | ✅ |

## ライセンス

MIT
