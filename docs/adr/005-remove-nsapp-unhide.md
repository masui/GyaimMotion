# ADR-005: showWindow から NSApp.unhide(nil) を削除

## Status

Accepted

## Decision

候補ウィンドウ表示時の `NSApp.unhide(nil)` 呼び出しを削除する。

## Context

- `showWindow()` は変換中の毎キー入力で呼ばれる
- `NSApp.unhide(nil)` はアプリの全ウィンドウを表示可能にする API
- IME プロセス (LSBackgroundOnly) でこれを毎回呼ぶと、入力中にフォーカスが外れたかのように入力不能になるバグが発生
- マウスでカーソルをクリックすると復活する症状

## Consideration

- `NSApp.unhide(nil)` の元の意図: バックグラウンドアプリのウィンドウを確実に表示するため
- しかし `orderFront(nil)` だけで候補ウィンドウは表示可能
- `unhide` が IME のキーイベントハンドリングに干渉している

## Consequences

- フォーカスが外れるバグが解消される（見込み）
- 候補ウィンドウは `orderFront(nil)` のみで表示
- 万が一ウィンドウが表示されないケースが発生したら別の手段を検討する

## References

- なし
