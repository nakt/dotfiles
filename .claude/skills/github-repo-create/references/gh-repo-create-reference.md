# gh repo create リファレンス

## Table of Contents

- [フラグ一覧](#フラグ一覧)
- [gitignore テンプレート（主要なもの）](#gitignore-テンプレート主要なもの)
  - [Web フロントエンド](#web-フロントエンド)
  - [Web バックエンド](#web-バックエンド)
  - [モバイル](#モバイル)
  - [システム/低レイヤ](#システム低レイヤ)
  - [スクリプト/データサイエンス](#スクリプトデータサイエンス)
  - [JVM 系](#jvm-系)
  - [ゲーム開発](#ゲーム開発)
  - [インフラ/DevOps](#インフラdevops)
  - [ドキュメント/静的サイト](#ドキュメント静的サイト)
  - [IDE/エディタ](#ideエディタ)
  - [よくある間違い](#よくある間違い)
- [Owner 情報の取得](#owner-情報の取得)
- [gitignore テンプレートの検証](#gitignore-テンプレートの検証)
- [検証コマンド](#検証コマンド)
  - [JSON フィールド](#json-フィールド)
  - [gitignore / README の存在確認](#gitignore--readme-の存在確認)

## フラグ一覧

| フラグ | 短縮 | 説明 |
|--------|------|------|
| `--add-readme` | | README ファイルを追加 |
| `--clone` | `-c` | 作成後にローカルにクローン |
| `--description` | `-d` | リポジトリの説明文 |
| `--disable-issues` | | Issue 機能を無効化 |
| `--disable-wiki` | | Wiki 機能を無効化 |
| `--gitignore` | `-g` | gitignore テンプレートを指定 |
| `--homepage` | `-h` | ホームページ URL |
| `--include-all-branches` | | テンプレートの全ブランチを含める |
| `--internal` | | 内部リポジトリとして作成 |
| `--license` | `-l` | OSS ライセンスを指定 |
| `--private` | | プライベートリポジトリ |
| `--public` | | パブリックリポジトリ |
| `--push` | | ローカルコミットをプッシュ |
| `--remote` | `-r` | リモート名を指定 |
| `--source` | `-s` | ローカルリポジトリのパス |
| `--template` | `-p` | テンプレートリポジトリを指定 |
| `--team` | `-t` | アクセスを付与する org チーム |

このスキルでは `--clone` の代わりに `ghq get` を使用する。
`--license` は使用しない。

## gitignore テンプレート（主要なもの）

テンプレート名は大文字小文字を正確に指定する必要がある。
完全なリストは `gh api /gitignore/templates` で取得できる。

### Web フロントエンド

| テンプレート名 | 用途 |
|---------------|------|
| `Node` | Node.js / React / Vue / Next.js / Nest.js 等 |
| `Angular` | Angular |
| `Elm` | Elm |

### Web バックエンド

| テンプレート名 | 用途 |
|---------------|------|
| `Go` | Go |
| `Java` | Java |
| `Kotlin` | Kotlin |
| `Rails` | Ruby on Rails |
| `Laravel` | Laravel (PHP) |
| `Django` | Django は `Python` テンプレートを使用 |

### モバイル

| テンプレート名 | 用途 |
|---------------|------|
| `Android` | Android (Java/Kotlin) |
| `Flutter` | Flutter (Dart) |
| `Swift` | Swift / iOS |
| `Objective-C` | Objective-C / iOS |

### システム/低レイヤ

| テンプレート名 | 用途 |
|---------------|------|
| `C` | C |
| `C++` | C++ |
| `Rust` | Rust |
| `Zig` | Zig |
| `Go` | Go |

### スクリプト/データサイエンス

| テンプレート名 | 用途 |
|---------------|------|
| `Python` | Python / Django / FastAPI / データサイエンス |
| `Ruby` | Ruby |
| `Julia` | Julia |
| `R` | R |
| `Perl` | Perl |
| `Lua` | Lua |
| `Elixir` | Elixir |

### JVM 系

| テンプレート名 | 用途 |
|---------------|------|
| `Java` | Java |
| `Kotlin` | Kotlin |
| `Scala` | Scala |
| `Gradle` | Gradle ビルドシステム |
| `Maven` | Maven ビルドシステム |

### ゲーム開発

| テンプレート名 | 用途 |
|---------------|------|
| `Unity` | Unity |
| `UnrealEngine` | Unreal Engine |
| `Godot` | Godot |

### インフラ/DevOps

| テンプレート名 | 用途 |
|---------------|------|
| `Terraform` | Terraform |
| `Nix` | Nix |

### ドキュメント/静的サイト

| テンプレート名 | 用途 |
|---------------|------|
| `Jekyll` | Jekyll |
| `TeX` | LaTeX |

### IDE/エディタ

| テンプレート名 | 用途 |
|---------------|------|
| `VisualStudio` | Visual Studio |

### よくある間違い

| 間違い | 正しい名前 |
|--------|-----------|
| `python` | `Python` |
| `node`, `nodejs` | `Node` |
| `golang` | `Go` |
| `go` | `Go` |
| `c++`, `cpp` | `C++` |
| `objective-c` | `Objective-C` |
| `rust` | `Rust` |
| `typescript` | `Node`（TypeScript 専用はない） |
| `react`, `vue`, `nextjs` | `Node`（フレームワーク専用はない） |

## Owner 情報の取得

```bash
# 現在ログインしているユーザーの GitHub ログイン名を取得
gh api user --jq .login
# 出力例: nakt
```

## gitignore テンプレートの検証

```bash
# 利用可能なテンプレート一覧を取得（JSON 配列）
gh api /gitignore/templates
# 出力例: ["Actionscript","Android","Angular",...,"Python",...,"Zig"]

# 特定のテンプレートが存在するか確認（大文字小文字を無視して検索、正確な名前を返す）
gh api /gitignore/templates | jq -r '.[]' | grep -ix "python"
# 出力: Python

gh api /gitignore/templates | jq -r '.[]' | grep -ix "node"
# 出力: Node
```

## 検証コマンド

```bash
gh repo view {owner}/{repo} --json visibility,defaultBranchRef,description,isPrivate
```

### JSON フィールド

| フィールド | 型 | 説明 |
|-----------|-----|------|
| `isPrivate` | boolean | true ならプライベート |
| `visibility` | string | `PUBLIC`, `PRIVATE`, `INTERNAL` |
| `defaultBranchRef.name` | string | デフォルトブランチ名 |
| `description` | string | リポジトリの説明 |

### gitignore / README の存在確認

```bash
# .gitignore の存在確認（404 なら存在しない）
gh api /repos/{owner}/{repo}/contents/.gitignore --jq .name 2>/dev/null

# README の存在確認
gh api /repos/{owner}/{repo}/contents/README.md --jq .name 2>/dev/null
```
