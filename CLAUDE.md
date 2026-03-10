# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GyaimMotion is a Japanese Input Method Editor (IME) for macOS, built with RubyMotion and InputMethodKit. Originally created by Toshiyuki Masui (2011), last successfully built for macOS Catalina (April 2020).

- **App identifier**: `com.pitecan.inputmethod.Gyaim`
- **Ruby version**: 2.5.5
- **Frameworks**: InputMethodKit, Security

## Build & Development Commands

```bash
# Build
rake                    # Full build
rake clean              # Clean build artifacts
rake ib                 # Regenerate Interface Builder project (ib.xcodeproj)
make all                # clean + ib + build

# Install & Run
make cp                 # Copy built app to ~/Library/Input Methods/
make kill               # Kill running Gyaim process
make update             # kill + cp (reinstall)

# Test
rake spec               # Run all RSpec tests
make test               # Same as rake spec

# Distribution
make dmg                # Create DMG (requires macOS 10.14+)
```

## Architecture

### Core Input Flow

`GyaimController.rb` is the central IME controller implementing the InputMethodKit protocol. It handles keyboard events via `handleEvent`, manages input state (`@inputPat`, `@candidates`, `@nthCand`, `@searchmode`), and coordinates dictionary lookups and candidate display.

### Three-Tier Dictionary System (WordSearch.rb + ConnectionDict.rb)

1. **Connection Dictionary** (`resources/dict.txt`) — Fixed morphological dictionary with conjugation support. Tab-separated format: `romaji[TAB]surface[TAB]input_connection[TAB]output_connection`. Enables compound word matching (e.g., "taberaremasen" → "食べられません").
2. **Local Dictionary** (`~/.gyaim/localdict.txt`) — User-registered words, highest priority.
3. **Study Dictionary** (`~/.gyaim/studydict.txt`) — Frequency-based learning (max 1000 entries, MRU ordering).

Search modes: 0 = prefix matching (incremental), 1 = exact matching + auto-add kana variants.

### Text Conversion (Romakana.rb)

Bidirectional romaji↔kana conversion with 353+ rules in `RKLIST`. Exposed as String methods: `"masui".roma2hiragana` → `"ますい"`, `"ますい".hiragana2roma` → `"masui"`, `"masui".roma2katakana` → `"マスイ"`.

### UI Components

- **CandWindow.rb** — Borderless transparent popup for candidate display, positioned near text cursor.
- **CandTextView.rb** — Renders candidate words (singleton via `awakeFromNib`).
- **CandView.rb** — Background drawing with candwin.png.

### Utilities

| File | Purpose |
|------|---------|
| Config.rb | `~/.gyaim/` directory management, file paths |
| Crypt.rb | MD5 salt-based encryption for sensitive words |
| Emulation.rb | Keyboard emulation via JXA/osascript |
| Files.rb | File copy/move/touch, HTTP download via AFMotion |
| Image.rb | Image resize (sips), Gyazo integration |
| Google.rb | Google transliteration API (async) |
| CopyText.rb | Clipboard monitoring (~60s polling) |
| AppDelegate.rb | IMKServer init, clipboard background thread |

## Key Constraints

- **afmotion must be pinned to 2.5** — version 2.6+ breaks builds.
- **`require` does not work in RubyMotion** — all gems go through Gemfile/Bundler.
- **XIB binding quirks** — use `awakeFromNib` for retrieving Interface Builder objects.
- **Icon must be 20×20 PDF** for Retina-compatible menu bar display.
- **User data directory**: `~/.gyaim/` (localdict.txt, studydict.txt, copytext, cacheimages/, images/)
