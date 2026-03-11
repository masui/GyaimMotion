# ADR-004: キーバインドの設定可能化と単一キーかな確定

## Status

Accepted

## Decision

ひらがな/カタカナ確定のキーボードショートカットをユーザーが設定画面から変更可能にする。加えて、変換中の単一キー確定（AquaSKK 方式）を導入する。

## Context

- F6/F7 キーが物理的に存在しないキーボード (NuPhy等) がある
- Ctrl+U/I は macOS ネイティブキーバインド（kill line / tab）と競合する
- ターミナルアプリでは Ctrl+key の組み合わせが IME に到達しない場合がある
- AquaSKK は変換中に単一キー（`q` でカタカナ等）で確定できる

## Consideration

| 方式 | メリット | デメリット |
|------|---------|-----------|
| F6/F7 固定 | シンプル | キーがないキーボードで使えない |
| Ctrl+key 固定 | 多くのキーボードで使える | macOS/ターミナルと競合 |
| 設定可能 + 単一キー | 柔軟、競合回避可能 | 実装が複雑 |

## Consequences

- KeyBindings.swift: Codable な設定モデル、UserDefaults 永続化
- PreferencesWindow.swift: ショートカット記録・編集 UI
- デフォルト: F6/Ctrl+Shift+U (ひらがな), F7/Ctrl+Shift+I (カタカナ)
- 単一キーデフォルト: `;` (ひらがな), `q` (カタカナ) — 変換中のみ有効
- modifier flags は `.control`, `.option`, `.shift`, `.command` のみ比較（デバイス依存フラグを無視）

## References

- AquaSKK: https://github.com/codefirst/aquaskk
