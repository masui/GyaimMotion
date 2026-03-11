# Gyaim — macOS用 日本語IME

[masui/GyaimMotion](https://github.com/masui/GyaimMotion) のフォークです。
オリジナルは増井俊之氏が RubyMotion で開発した日本語入力システムで、本フォークでは **Swift へ全面移行** しています。

## オリジナルとの主な違い

- RubyMotion コードを全て削除し、**Swift (InputMethodKit)** で再実装
- XcodeGen によるプロジェクト管理
- 候補ウィンドウを NSPanel ベースの縦型リストに刷新
- キーボードショートカットの設定UI追加
- ユーザー辞書エディタ追加
- os.Logger ベースのロギング基盤（デフォルト無効）

## 動作環境

- macOS 13.0 (Ventura) 以降

## ビルド & インストール

```bash
cd GyaimSwift

# Xcode プロジェクト生成
xcodegen generate

# ビルド
xcodebuild -project Gyaim.xcodeproj -scheme Gyaim -configuration Debug -derivedDataPath .build build

# インストール
killall Gyaim
rm -rf ~/Library/Input\ Methods/Gyaim.app
cp -r .build/Build/Products/Debug/Gyaim.app ~/Library/Input\ Methods/
```

## 辞書

3層構成の辞書システム:

1. **接続辞書** (`GyaimSwift/resources/dict.txt`) — 形態素接続ルール付きの固定辞書
2. **ユーザー辞書** (`~/.gyaim/localdict.txt`) — ユーザー登録語（最優先）
3. **学習辞書** (`~/.gyaim/studydict.txt`) — 使用頻度に基づく学習（最大1000件）

## ライセンス

[MIT License](LICENSE) - Copyright (c) 2015-2026 Toshiyuki Masui

オリジナルの [masui/GyaimMotion](https://github.com/masui/GyaimMotion) に由来するライセンスです。

## クレジット

- オリジナル作者: [増井俊之](http://masui.github.io/GyaimMotion/) (2011-2015, RubyMotion)
- Swift移行: tanabe1478
