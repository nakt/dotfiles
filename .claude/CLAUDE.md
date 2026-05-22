# CLAUDE.md

このファイルは、このリポジトリで作業する際の Claude Code へのガイダンスを提供します。

## コミュニケーションルール

- 常に日本語で会話する

## 構造

- Rules (`~/.claude/rules/`): 各ルールの質的な定義。下表の「常時参照」列で `@` import されたもののみが実際に読み込まれ、それ以外はスキル呼び出し用のポインタ中間ファイル
- Skills (`~/.claude/skills/`): YAML frontmatter の description でトリガー判定、`/name` で手動呼び出しも可能

## 利用可能な Rules

常時参照列に `@path` が書かれているルールは、Claude Code の `@` import でグローバルメモリに取り込まれる。専用スキルへのポインタに留めるルールは空欄 (—)。

| Rule                 | 対象                    | 説明                                          | 常時参照                                |
| -------------------- | ----------------------- | --------------------------------------------- | ----------------------------------------- |
| workspace-management | All files               | .workspace ディレクトリの運用ルール            | @~/.claude/rules/workspace-management.md  |
| git-workflow         | All files               | コミット規約、ブランチ戦略、PR ガイドライン    | @~/.claude/rules/git-workflow.md          |
| markdown-style       | `**/*.md`               | Markdown 作成時のスタイルガイド                | @~/.claude/rules/markdown-style.md        |
| plan-files           | `**/.claude/plans/*.md` | プラン作成後の検証ワークフロー                  | @~/.claude/rules/plan-files.md            |
| python-development   | `**/*.py`               | → `/python-dev-guide` スキルへのポインタ       | —                                         |
| react-coding         | `**/*.tsx`, `**/*.jsx`  | → `/react-dev-guide` スキルへのポインタ        | —                                         |
| typescript-coding    | `**/*.ts`, `**/*.tsx`   | → `/typescript-dev-guide` スキルへのポインタ   | —                                         |

## 利用可能な Skills

| Skill                | 用途                                               |
| -------------------- | -------------------------------------------------- |
| commit               | 変更を分析し適切な粒度でコミット                   |
| github-repo-create   | GitHub リポジトリの新規作成（ヒアリング→作成→検証） |
| pr-merge             | PR 作成・マージ（push→PR→マージ→ブランチ掃除）     |
| cleanup-files        | 実験ワークスペースとプロジェクト全体の不要ファイル整理 |
| gemini-research      | Gemini CLI を活用した意見取得・リサーチ             |
| gpt5-prompting       | GPT-5系モデル向けプロンプト設計のベストプラクティス |
| react-dev-guide      | React 開発ガイド                                   |
| refactor-code        | コード品質改善のためのリファクタリング             |
| typescript-dev-guide | TypeScript 開発ガイド                              |
| python-dev-guide     | Python 開発ガイド                                  |
| python-refactor      | Python の計測駆動リファクタリング（複雑性削減・コード健全性・共通化・マジックナンバー定数化） |
| update-arch          | アーキテクチャドキュメント(docs/arch)の更新・初期化 |
| update-readme        | プロジェクト構造分析による README.md 生成・更新     |
| humanize             | AI 生成文章から AI らしさを取り除き自然な日本語に書き換える |
| marp-style           | Marp Markdown 構造スタイル規約 (見出し階層・スライド構成等、変換ツール非依存・文体非干渉) |
