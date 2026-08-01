---
name: update-readme
description: プロジェクト構造とコードベースを分析して README.md を自動生成・更新するスキル。ユーザーが README の作成・更新を求めたとき、「README を書いて」「README を更新して」「ドキュメントを整備して」と言ったとき、またはプロジェクトの初期セットアップ後にドキュメント整備が必要なときに使用する。
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - Bash(find:*)
  - Bash(head:*)
  - Bash(ls:*)
---

# Update README

プロジェクト構造とコードベースを分析し、統一フォーマットで README.md を生成・更新する。

## Current state

- Top-level files: !`ls -1`
- Config files: !`ls pyproject.toml package.json Cargo.toml go.mod composer.json Gemfile 2>/dev/null || true`
- Directory structure: !`find . -maxdepth 2 -type d -not -path '*/\.*' -not -path './node_modules/*' | head -30`
- Existing README: !`head -20 README.md 2>/dev/null || true`

## プロジェクトタイプ検出

設定ファイルの有無だけでなく、以下のシグナルからリポジトリの種別を判定し、生成する章構成を調整する。アプリ開発リポジトリに限定しない。

| タイプ            | 検出シグナル                                       |
| ----------------- | -------------------------------------------------- |
| アプリ/ライブラリ | package.json, pyproject.toml, Cargo.toml, go.mod   |
| CLI ツール        | bin/, エントリーポイントの実行権限                 |
| 設定リポジトリ    | dotfiles, install.sh, シンボリックリンク群         |
| ドキュメント集    | docs/, `*.md` 主体でコードが少ない構成             |
| モノレポ          | packages/*, workspaces 設定                        |

## 生成・更新する README の構造

README の章構成は [references/template.md](references/template.md) に従う。必須/条件付きセクションの判定基準は同ファイルのコメントを参照する。README は見出しを含め英語で生成する。トラブルシューティングや FAQ のセクションは含めない。スクリーンショットや図は自動生成せず、必要な場合は手動追加を促すに留める。コードのロジックから機能を推測せず、設定・構造・既存記述から判断できる範囲に留める。

## タスク

1. 既存の README.md の内容を分析する（存在する場合）
2. 「プロジェクトタイプ検出」のシグナルからリポジトリ種別を判定する
3. 設定ファイル（pyproject.toml, package.json, Cargo.toml, requirements.txt, setup.py など）から依存関係と基本情報を抽出する
4. プロジェクト構造（`src/`, `lib/`, `tests/` など）を分析してモジュール構成を把握する
5. エントリーポイントを特定する
6. テスト設定を確認する
7. 既存の内容と実装の差異を特定し、整合性を確保する（手動で追加されたセクション、例: コントリビューションガイドラインは可能な限り保持する）
8. 現在の実装状態に基づいて統一フォーマットで README.md を生成・更新する（変更履歴や機能アナウンスは含めず、コードが実際に何をするかを記述する。何が追加・更新されたかは書かない）
   - 既存 README の一部セクションだけを直す場合は Edit で部分更新し、手動追加されたセクションをそのまま残す
   - 新規作成、または章構成ごと入れ替える全面刷新のときだけ Write で全文書き込む
9. 全面刷新で既存 README を大幅に書き換える場合は、Write 前に差分の要点を提示してから書き込む
