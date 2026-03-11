# ADR-007: Unified Logging導入

## Status

Accepted

## Context

Gyaim IMEをドッグフーディング中だが、ログ出力が一切なく、全エラーが `try?` で握りつぶされている。不具合発生時の原因調査が不可能な状態。

## Decision

- **os.Logger（Unified Logging）** をメインに採用
- **~/.gyaim/gyaim.log** にもinfo以上を書き出し、`tail -f` で手軽に確認可能に
- **デフォルト無効** — UserDefaults `loggingEnabled`（デフォルトfalse）で制御
- 設定画面のトグルでユーザーが明示的に有効化/無効化できる
- `@autoclosure` により、ログ無効時は文字列生成コストもゼロ
- カテゴリ別ログ: input, dict, conversion, ui, config

## Alternatives Considered

1. **NSLog**: 古く、パフォーマンスが悪い。フィルタリングも困難。
2. **print + stderr**: Console.appで見えない。構造化ログ不可。
3. **CocoaLumberjack等のサードパーティ**: 依存を増やしたくない。os.Loggerで十分。

## Consequences

- Console.app または `log stream` コマンドでリアルタイム診断可能
- `tail -f ~/.gyaim/gyaim.log` でも確認可能
- デフォルト無効のため、通常使用時のパフォーマンス影響なし
- `try?` → `do/catch` 変換により、エラーの可視化が実現
