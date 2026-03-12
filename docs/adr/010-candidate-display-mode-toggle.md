# ADR-010: 候補ウィンドウ表示モード切り替え

## Status

Accepted

## Decision

候補ウィンドウにリスト表示（縦、番号付き、最大9候補）とクラシック表示（横並び、candwin.png背景、番号なし、最大11候補）の2モードを導入し、設定画面のNSSegmentedControlで切り替え可能にする。

## Context

- 現行の候補ウィンドウはGoogle IME風の縦リスト表示のみ
- オリジナルGyaim（RubyMotion版）では`candwin.png`背景の横並びスタイルを使用していた
- 両方のスタイルにファンがいるため、ユーザーが選択できるようにしたい

## Consideration

### 案A: 設定で完全に切り替え（採用）
- `CandidateDisplayMode` enumをUserDefaultsで永続化
- 設定変更時に即時反映（`applyDisplayMode()`）
- 既存のリストモードはそのまま維持、クラシックモードを追加

### 案B: 別ウィンドウクラスとして実装
- `ClassicCandidateWindow`を新規作成
- コード分離は良いが、切り替え時にウィンドウインスタンスの管理が複雑になる

### 案C: 設定なし、常にクラシック
- 既存ユーザーに影響が大きい

## Consequences

### 良い点
- ユーザーが好みの表示スタイルを選択可能
- デフォルトはクラシック表示（オリジナルGyaimの操作感を優先）
- クラシック表示は`candwin.png`を活用し、オリジナルGyaimの雰囲気を再現

### 悪い点
- `CandidateWindow`の複雑度が増加（2モード分のUI管理）
- クラシックモードの最大候補数(11)とリストモード(9)の差異をControllerが意識する必要がある

## 追加設計: CandidateWindowPositioner

ウィンドウ位置計算を `CandidateWindowPositioner.calculate()` 純粋関数として抽出。lineRect・winSize・screenFrame・modeを入力、NSPointを返す。画面端でのフリップ・クランプ処理をユニットテストでカバー。

## References

- ADR-003: 縦候補ウィンドウ
- ADR-006: NSPanel化
- Resources/candwin.png: オリジナルGyaimの候補ウィンドウ背景画像
