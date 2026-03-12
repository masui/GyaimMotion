# ADR-011: Google Transliterate API統合

## Status

Accepted

## Decision

Google Transliterate APIをフォールバック変換手段として統合する。トリガーはサフィックス文字（デフォルト`` ` ``）とキーボードショートカット（任意設定）の2方式を提供し、両方とも設定画面から変更可能にする。

## Context

- オリジナルGyaim（RubyMotion版）にはピリオド(`.`)でGoogle変換APIを呼ぶ機能があった
- 内蔵辞書が貧弱なため、固有名詞や辞書にない語の変換にウェブAPIが必要
- Swift版では`GoogleTransliterate.swift`にAPIコードが存在するが未接続だった
- Issue #14: 複数単語クエリ（例:「ますいとしゆき」→「増井俊之」）が単一セグメントしか処理されていなかった

## Consideration

### 非同期処理の設計

- **案A: WordSearchに非同期コールバックを追加** — WordSearchの同期インターフェースを壊す。テスト複雑化。
- **案B: Controllerで非同期を管理（採用）** — `searchAndShowCands()`でトリガー検知、`triggerGoogleTransliterate()`で非同期呼出し、既存の`showCands(_:)`静的メソッド（`searchMode = 2`）でUI更新。WordSearchは同期のまま維持。

### トリガーキーの選定

- `.`（ピリオド）: rklist で`。`にマップ済み → **衝突**
- `/`: rklist で`・`にマップ済み → **衝突**
- `` ` ``（バッククォート）: rklist未マップ、他IMEと衝突なし → **採用**
- `;`: Gyaimのひらがな確定single-keyに使用中 → 衝突
- ショートカット（Ctrl+何か）: 衝突を完全に避けられる → **追加方式として採用**

### 複数セグメント対応 (Issue #14)

Google Transliterate APIは`[["ますい",["増井","桝井"]],["としゆき",["俊之","敏之"]]]`のように複数セグメントを返す。各セグメントの候補を直積（cartesian product）で結合する。組み合わせ爆発を防ぐためlimit=20で制限。

## Consequences

### 良い点
- 内蔵辞書にない語（固有名詞等）をGoogle APIで変換可能
- サフィックスとショートカットの2方式でユーザーの好みに対応
- トリガー文字を設定変更可能（衝突回避）
- 複数単語の変換結果を組み合わせて候補表示（Issue #14解決）
- stale guardで非同期結果の整合性を保証
- 3秒タイムアウトでIMEハング防止

### 悪い点
- Google Transliterate APIの可用性・レート制限に依存
- ネットワーク遅延分のUXラグが発生しうる（タイムアウト最大3秒）
- デフォルトの`` ` ``キーは位置がやや遠い（ユーザーがショートカット設定で補完可能）

## References

- ADR-004: キーバインド設定
- [Original GyaimMotion Google.rb](https://github.com/masui/GyaimMotion)
- [gihyo.jp 増井氏記事: Gyaim](https://gihyo.jp/dev/serial/01/masui-columbus/0007)
- Issue #14: Google検索結果が複数単語になったとき、組合せたものを候補に表示する
