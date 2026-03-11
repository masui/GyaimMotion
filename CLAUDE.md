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
| CandidateWindow.swift | Vertical candidate list (NSStackView), numbered 1-9, screen-edge aware positioning |
| PreferencesWindow.swift | Keyboard shortcut configuration UI |
| DictEditorWindow.swift | User dictionary editor (NSTableView), add/delete/save/reload |
| KeyBindings.swift | Configurable shortcuts, UserDefaults persistence, single-key kana confirm |

### Key Constraints

- **IME runs as LSBackgroundOnly** — `NSApp.unhide(nil)` causes focus loss, use `orderFront(nil)` only
- **Ctrl+key in terminals** — Terminal apps intercept Ctrl+key independently of IME; use single-key shortcuts as alternative
- **NSApp.setActivationPolicy** — Use `.accessory` temporarily when opening settings/dict editor windows, revert to `.prohibited` on close
- **Icon must be 20x20 PDF** for Retina-compatible menu bar display
- **User data directory**: `~/.gyaim/` (localdict.txt, studydict.txt)

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
└── 005-remove-nsapp-unhide.md
```
