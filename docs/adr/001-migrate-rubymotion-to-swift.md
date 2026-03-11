# ADR-001: RubyMotion から Swift への移行

## Status

Accepted

## Decision

GyaimMotion の実装言語を RubyMotion から Swift に移行する。

## Context

- RubyMotion は開発が停滞しており、最新の macOS (Catalina 以降) でのビルドが困難
- Ruby 2.5.5 に固定されており、依存ライブラリ (afmotion 2.5 ピン留め等) の制約が大きい
- InputMethodKit の Swift サポートは Apple 公式であり、長期的に安定している

## Consideration

| 選択肢 | メリット | デメリット |
|--------|---------|-----------|
| RubyMotion を維持 | 既存コードそのまま | ビルド不可、将来性なし |
| Objective-C へ移行 | InputMethodKit との親和性高 | 言語として古い |
| Swift へ移行 | Apple 公式、モダン、型安全 | 全コード書き直し |

## Consequences

- 全ソースコードの書き直しが必要（GyaimSwift/ ディレクトリに新規構築）
- XcodeGen (project.yml) によるプロジェクト管理を採用
- RubyMotion 固有の制約（require 不可、XIB binding 等）から解放される
- 辞書フォーマット、ユーザーデータディレクトリ (~/.gyaim/) は互換性を維持

## References

- 元リポジトリ: https://github.com/masui/GyaimMotion
