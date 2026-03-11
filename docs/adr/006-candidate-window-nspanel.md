# ADR-006: 候補ウィンドウを NSPanel (nonactivatingPanel) に変更

## Status

Accepted

## Decision

CandidateWindow を NSWindow から NSPanel に変更し、`nonactivatingPanel` スタイルと `becomesKeyOnlyIfNeeded = true` を設定する。

## Context

- 候補ウィンドウ表示中に入力フォーカスが奪われ、キー入力が効かなくなるバグが発生
- macOS の「入力を受け付けない」警告音が鳴る
- マウスでカーソルをクリックすると復活する
- Ghostty (ターミナル) で再現確認済み
- ADR-005 で `NSApp.unhide(nil)` を削除したが解消せず、`orderFront(nil)` 自体が原因

## Consideration

| 選択肢 | メリット | デメリット |
|--------|---------|-----------|
| NSWindow + orderFront | シンプル | フォーカスを奪う場合がある |
| NSPanel + nonactivatingPanel | フォーカスを奪わない設計 | NSPanel は NSWindow のサブクラスなので大きな変更不要 |
| NSWindow + canBecomeKey=false override | フォーカス防止可能 | nonactivatingPanel の方が意図が明確 |

## Consequences

- CandidateWindow は NSPanel を継承
- styleMask に `.nonactivatingPanel` を追加
- `becomesKeyOnlyIfNeeded = true` でキーウィンドウにならない
- IME の候補表示としては標準的なアプローチ（Apple の IME もパネルを使用）

## References

- Apple Documentation: NSPanel, nonactivatingPanel
