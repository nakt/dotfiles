# CLAUDE.md

このファイルは、このリポジトリで作業する際の Claude Code へのガイダンスを提供します。

## コミュニケーションルール

- 常に日本語で会話する

## 構造

- Rules (`~/.claude/rules/`): ファイルパスに基づいて自動的に読み込まれる
- Skills (`~/.claude/skills/`): YAML frontmatter の description でトリガー判定、`/name` で手動呼び出しも可能

## 利用可能な Rules

| Rule         | 対象                    | 説明                                     |
| ------------ | ----------------------- | ---------------------------------------- |
| git-workflow | All files               | コミット規約、ブランチ戦略、PR ガイドライン |
| markdown     | `**/*.md`               | Markdown 作成時のスタイルガイド           |
| plan-files   | `**/.claude/plans/*.md` | プラン作成後の検証ワークフロー             |
| python       | `**/*.py`               | Python 開発ガイド                         |
| react        | `**/*.tsx`, `**/*.jsx`  | → `/react` スキルへのポインタ             |
| typescript   | `**/*.ts`, `**/*.tsx`   | → `/typescript` スキルへのポインタ        |

## 利用可能な Skills

| Skill          | 用途                                           |
| -------------- | ---------------------------------------------- |
| gemini         | Gemini CLI を活用した意見取得・リサーチ         |
| gpt5-prompting | GPT-5系モデル向けプロンプト設計のベストプラクティス |
| react          | React 開発ガイド                               |
| typescript     | TypeScript 開発ガイド                          |
