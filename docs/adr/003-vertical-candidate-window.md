# ADR-003: 候補ウィンドウを縦型リスト表示に変更

## Status

Accepted

## Decision

候補ウィンドウを Google IME 風の縦型リスト表示に変更し、番号キー(1-9)による直接選択を可能にする。

## Context

- 元の実装は candwin.png を背景にした横一列表示で、候補が増えると見づらい
- Google IME や ATOK など主要な日本語 IME は縦型リスト表示が標準
- ユーザーから縦型表示の要望があった

## Consideration

| 選択肢 | メリット | デメリット |
|--------|---------|-----------|
| 横型表示を維持 | 変更不要 | 候補が見づらい、選択しにくい |
| 縦型リスト (NSStackView) | 視認性高、番号選択可能 | CandidateWindow 全面書き直し |
| NSTableView ベース | スクロール対応が容易 | 候補数が少ないので過剰 |

## Consequences

- CandidateWindow.swift を NSStackView ベースで全面書き直し
- candwin.png 依存を排除し、セミ透明背景 + 角丸デザインに
- 番号キー 1-9 で候補リストから直接選択・確定が可能
- 最大9件表示（maxVisible = 9）
- 画面下部での入力時はカーソルの上に候補ウィンドウを表示

## References

- なし
