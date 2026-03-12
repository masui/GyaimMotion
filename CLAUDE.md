# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Gyaim is a Japanese Input Method Editor (IME) for macOS. Originally created by Toshiyuki Masui (2011) in RubyMotion, migrated to Swift (GyaimSwift/).

- **App identifier**: `com.pitecan.inputmethod.Gyaim`
- **Language**: Swift
- **Frameworks**: InputMethodKit, Security
- **Project management**: XcodeGen (project.yml)

## Build & Development Commands

```bash
# Generate Xcode project
xcodegen generate

# Build
xcodebuild -project Gyaim.xcodeproj -scheme Gyaim -configuration Debug -derivedDataPath .build build

# Install
killall Gyaim
rm -rf ~/Library/Input\ Methods/Gyaim.app
cp -r .build/Build/Products/Debug/Gyaim.app ~/Library/Input\ Methods/
```

Working directory for build commands: `GyaimSwift/`

## Architecture

### Core Input Flow

`GyaimController.swift` is the central IME controller implementing the InputMethodKit protocol. It handles keyboard events via `handle(_:client:)`, manages input state (`inputPat`, `candidates`, `nthCand`, `searchMode`), and coordinates dictionary lookups and candidate display.

### Three-Tier Dictionary System (WordSearch.swift + ConnectionDict.swift)

1. **Connection Dictionary** (`resources/dict.txt`) — Fixed morphological dictionary with conjugation support. Tab-separated format: `romaji[TAB]surface[TAB]input_connection[TAB]output_connection`.
2. **Local Dictionary** (`~/.gyaim/localdict.txt`) — User-registered words, highest priority. Hot reload via mtime check.
3. **Study Dictionary** (`~/.gyaim/studydict.txt`) — Frequency-based learning (max 1000 entries, MRU ordering).

Search modes: 0 = prefix matching (incremental), 1 = exact matching + auto-add kana variants.

### Text Conversion (RomaKana.swift)

Bidirectional romaji-kana conversion with 350+ rules in `rklist`. Includes full-width symbol mappings (`?`->`？`, `!`->`！`, etc.).

### UI Components

| File | Purpose |
|------|---------|
| CandidateWindow.swift | 候補ウィンドウ。リスト表示（縦、番号1-9、最大9候補）とクラシック表示（横並び、candwin.png背景、最大11候補）の2モード対応。`CandidateDisplayMode` enumで切り替え |
| PreferencesWindow.swift | キーボードショートカット設定、候補表示スタイル切り替え（NSSegmentedControl）、候補トグル（クリップボード/選択テキスト）、ログ管理UI。動的ウィンドウリサイズ対応 |
| DictEditorWindow.swift | User dictionary editor (NSTableView), add/delete/save/reload |
| KeyBindings.swift | Configurable shortcuts, UserDefaults persistence, single-key kana confirm |

### Key Constraints

- **IME runs as LSBackgroundOnly** — `NSApp.unhide(nil)` causes focus loss, use `orderFront(nil)` only
- **Ctrl+key in terminals** — Terminal apps intercept Ctrl+key independently of IME; use single-key shortcuts as alternative
- **NSApp.setActivationPolicy** — Use `.accessory` temporarily when opening settings/dict editor windows, revert to `.prohibited` on close
- **Icon must be 20x20 PDF** for Retina-compatible menu bar display
- **User data directory**: `~/.gyaim/` (localdict.txt, studydict.txt)

## Testing

### テスト実行

```bash
# ユニットテスト（118テスト）
xcodebuild -project Gyaim.xcodeproj -scheme GyaimTests -derivedDataPath .build test

# E2Eテスト（アクセシビリティ権限必要、Gyaimインストール済みの状態で実行）
xcodebuild -project Gyaim.xcodeproj -scheme GyaimE2ETests -derivedDataPath .build test
```

### テスト構成

| スイート | ファイル | テスト数 | 内容 |
|---------|---------|---------|------|
| HandleEventTests | Tests/GyaimTests/ | 36 | `routeEvent` 静的メソッドによるキー入力分岐の全網羅 |
| ExternalCandidateTests | Tests/GyaimTests/ | 22 | `isValidExternalCandidate` + `buildPrefixCandidates` |
| PreferencesWindowTests | Tests/GyaimTests/ | 13 | 設定画面UIテスト（トグル存在・初期状態・クリック操作・表示モード切替） |
| CandidateWindowTests | Tests/GyaimTests/ | 5 | 表示モード（リスト/クラシック）の切替・描画・最大候補数 |
| CopyTextTests | Tests/GyaimTests/ | 7 | CopyText ファイルI/O + NSPasteboard.changeCount |
| RomaKanaTests | Tests/GyaimTests/ | 18 | ローマ字⇔かな変換の双方向テスト |
| WordSearchTests | Tests/GyaimTests/ | 6 | 辞書検索（前方一致・完全一致・登録） |
| CryptTests | Tests/GyaimTests/ | 6 | 暗号化/復号のラウンドトリップ |
| ConnectionDictTests | Tests/GyaimTests/ | 3 | 連接辞書の検索 |
| GyaimE2ETests | Tests/E2ETests/ | 8 | CGEventによるIME統合テスト（TextEdit上で実操作） |

### テストインフラ

- **MockIMKTextInput** (`Tests/GyaimTests/MockIMKTextInput.swift`) — IMKTextInputプロトコル準拠のモック。`insertedTexts`/`markedTexts` 配列で挿入・マーク済みテキストを記録
- **NSEventFactory** (`Tests/GyaimTests/NSEventFactory.swift`) — テスト用NSEvent生成ヘルパー（`keyDown`, `backspace`, `enter`, `space`, `escape`）
- **E2EHelper** (`Tests/E2ETests/E2EHelper.swift`) — CGEventベースのキー入力シミュレーション。TextEditの起動/終了、Gyaim入力ソースの選択、テキスト取得

### テスト方針

- **キー入力ロジック**: `handle(_:client:)` の分岐ロジックを `routeEvent` 静的メソッドに抽出し、副作用なしでユニットテスト可能にしている
- **UI テスト**: PreferencesWindow を直接インスタンス化し、subview走査でチェックボックスを検索してクリック操作をシミュレート
- **E2E テスト**: CGEvent でキーボードイベントを生成し、インストール済みGyaimをTextEdit上で操作。アクセシビリティ権限が必要

## ADR (Architecture Decision Records)

設計上の重要な判断は `docs/adr/` に ADR として記録する。

- テンプレート: `docs/adr/000-template.md`
- 新規追加時は連番で `NNN-タイトル.md` を作成
- 既存 ADR の変更時は新規 ADR を作成し、旧版の Status を `Superseded by ADR-NNN` に更新

```
docs/adr/
├── 000-template.md
├── 001-migrate-rubymotion-to-swift.md
├── 002-remove-implicit-candidate-injection.md
├── 003-vertical-candidate-window.md
├── 004-configurable-keybindings.md
├── 005-remove-nsapp-unhide.md
├── 006-candidate-window-nspanel.md
├── 007-unified-logging.md
├── 008-clipboard-selected-text-candidates.md
├── 009-route-event-extraction-and-test-strategy.md
└── 010-candidate-display-mode-toggle.md
```

## Logging & Monitoring

`GyaimLogger.swift` に os.Logger ベースのロギング基盤を実装。デフォルト無効（UserDefaults `loggingEnabled`）。

### カテゴリ

| カテゴリ | 対象 |
|---------|------|
| `input` | キー入力、状態遷移、候補確定 |
| `dict` | 辞書読込、ホットリロード、学習 |
| `conversion` | ローマ字変換（debugのみ） |
| `ui` | ウィンドウ表示/非表示 |
| `config` | ファイルI/O、設定永続化、起動/終了 |

### ログ確認方法

```bash
# Console.app / ターミナル
log stream --predicate 'subsystem == "com.pitecan.inputmethod.Gyaim"' --level debug

# ファイルログ（info以上）
tail -f ~/.gyaim/gyaim.log
```

### 設定画面

Gyaim設定 > ログセクションで有効/無効切替、ログ削除、Finderで表示が可能。

### 候補設定

Gyaim設定 > 候補セクションで以下を切り替え可能（UserDefaults、即時反映）:
- **表示スタイル**: NSSegmentedControlでリスト表示（デフォルト）/ クラシック表示を切り替え。UserDefaultsキー `candidateDisplayMode`（Int, 0=list, 1=classic）
- **クリップボード候補**: コピーから5秒以内の入力時にクリップボード内容を候補に表示（デフォルトON）
- **選択テキスト候補**: アクティブアプリの選択テキストを候補に表示（デフォルトON、IMKTextInput経由で取得可能な範囲のみ）
