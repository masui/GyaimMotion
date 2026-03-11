# ADR-009: routeEvent抽出によるテスト戦略

## Status

Accepted

## Decision

`GyaimController.handle(_:client:)` のキー入力分岐ロジックを `routeEvent` 静的メソッドとして抽出し、副作用なしでユニットテスト可能にする。E2Eテストは CGEvent ベースで実装し、インストール済みGyaimをTextEdit上で操作する。

## Context

GyaimControllerの `handle(_:client:)` は30以上の分岐を持つIMEの中核メソッドだが、IMKInputControllerに強く依存しておりユニットテストが困難だった。テストなしでの変更はリグレッションリスクが高い。

## Consideration

### handle() のテスト方法

| 方式 | メリット | デメリット |
|------|---------|-----------|
| handle() を直接テスト | 実際の動作を検証 | IMKServer, IMKTextInputの初期化が必要。IMEプロセス外では動作しない |
| **routeEvent 静的メソッド抽出（採用）** | 純粋関数としてテスト可能。全分岐を網羅できる | handle() 本体との乖離リスク |
| プロトコル抽象化 | 依存注入で柔軟 | IMKInputControllerの制約上、大規模なリファクタリングが必要 |

routeEvent は全ての判定に必要な値をパラメータとして受け取り、`HandleResult`（handled: Bool, action: HandleAction）を返す。handle() 本体は routeEvent の結果に基づいて副作用（insertText, setMarkedText等）を実行する。

### E2Eテスト方式

| 方式 | メリット | デメリット |
|------|---------|-----------|
| XCUITest | Apple公式 | IMEプロセスのテストには非対応 |
| **CGEvent（採用）** | カーネルレベルのキーイベント生成。実際のIME動作を検証 | アクセシビリティ権限が必要。CI環境では実行困難 |
| AppleScript | 高レベルAPI | キー入力の細かい制御が困難 |

### UIテスト方式

| 方式 | メリット | デメリット |
|------|---------|-----------|
| XCUITest | 標準的 | IMEプロセスのウィンドウには使えない |
| **直接インスタンス化 + subview走査（採用）** | シンプル。NSButtonのtitleで検索し、sendActionでクリックをシミュレート | レイアウト変更に弱い |

## Consequences

### 良い点
- handle() の全分岐（36テスト）をユニットテストで網羅
- routeEvent は純粋関数のため、テストが高速で安定
- E2Eテストで実際のIME動作（入力→変換→確定）を検証可能
- PreferencesWindowのトグル操作をUIテストで検証可能

### 悪い点
- routeEvent と handle() 本体の同期を手動で維持する必要がある
- E2Eテストはアクセシビリティ権限が必要で、CI環境では実行が難しい
- CGEventテストはThread.sleepに依存しており、環境によってflakyになる可能性

## References

- Apple: [CGEvent](https://developer.apple.com/documentation/coregraphics/cgevent)
- Apple: [IMKInputController](https://developer.apple.com/documentation/inputmethodkit/imkinputcontroller)
