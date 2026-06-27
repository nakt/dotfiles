---
name: update-readme
description: プロジェクト構造とコードベースを分析して README.md を自動生成・更新するスキル。ユーザーが README の作成・更新を求めたとき、「README を書いて」「README を更新して」「ドキュメントを整備して」と言ったとき、またはプロジェクトの初期セットアップ後にドキュメント整備が必要なときに使用する。
allowed-tools: Read(*), Glob(*), Grep(*), Write(*), Bash(find:*), Bash(head:*), Bash(ls:*)
---

# Update README

プロジェクト構造とコードベースを分析し、統一フォーマットで README.md を生成・更新する。

## Current state

- Top-level files: !`ls -1`
- Config files: !`ls pyproject.toml package.json Cargo.toml go.mod composer.json Gemfile 2>/dev/null || true`
- Directory structure: !`find . -maxdepth 2 -type d -not -path '*/\.*' -not -path './node_modules/*' | head -30`
- Existing README: !`head -20 README.md 2>/dev/null || true`

## 分析対象

1. 設定ファイル: pyproject.toml, package.json, Cargo.toml, requirements.txt, setup.py など
2. プロジェクト構造: `src/`, `lib/`, `tests/`
3. メインファイル: エントリーポイント、設定ファイル
4. 既存 README: 現在の内容と実装の整合性チェック

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

README の章構成は [references/template.md](references/template.md) に従う。必須/条件付きセクションの判定基準は同ファイルのコメントを参照する。出力する README の見出しは英語にする。

## タスク

1. 既存の README.md の内容を分析する（存在する場合）
2. 「プロジェクトタイプ検出」のシグナルからリポジトリ種別を判定する
3. 設定ファイルから依存関係と基本情報を抽出する
4. プロジェクト構造を分析してモジュール構成を把握する
5. エントリーポイントを特定する
6. テスト設定を確認する
7. 既存の内容と実装の差異を特定し、整合性を確保する
8. 現在の実装状態に基づいて統一フォーマットで README.md を生成・更新する
9. 既存 README を大幅に書き換える場合は、Write 前に差分の要点を提示してから書き込む

## 制約

- 既存の README.md がある場合は、実装との比較に基づいて内容を保持しつつ更新する
- README は英語で生成する
- プロジェクトタイプに応じた適切な設定ファイルから情報を抽出する
- 手動で追加されたセクション（コントリビューションガイドラインなど）はできる限り保持する
- 現在の実装状態の記述に専念し、変更履歴や機能アナウンスは含めない
- コードが実際に何をするかを記述し、何が追加・更新されたかは書かない
- 絵文字はできる限り使用しない
- 強調（太字）の使用を最小限にする
- トラブルシューティングや FAQ セクションは含めない
- スクリーンショットや図は自動生成しない（必要なら手動追加を促す）
- コードのロジックから機能を推測せず、設定・構造・既存記述から判断できる範囲を記述する
- Markdown スタイルは `~/.claude/rules/markdown-style.md` に従う。
