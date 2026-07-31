# CLAUDE.md

このファイルは、このリポジトリで作業する際の Claude Code へのガイダンスを提供します。

## コミュニケーションルール

- 常に日本語で会話する

## 構造

- Rules (`~/.claude/rules/`): 各ルールの質的な定義。frontmatter に `paths` を持たないルールは起動時に常時ロードされ、`paths` を持つルールはパターンに一致するファイルを読んだ時点でロードされる
- Skills (`~/.claude/skills/`): YAML frontmatter の description でトリガー判定、`/name` で手動呼び出しも可能。一覧は `~/.claude/skills/` の実体を唯一の情報源とし、CLAUDE.md 側に台帳は置かない

## 利用可能な Rules

| Rule                 | 対象                    | 説明                                          | ロード方式    |
| -------------------- | ----------------------- | --------------------------------------------- | ------------- |
| workspace-management | All files               | .workspace ディレクトリの運用ルール            | 常時ロード    |
| git-workflow         | All files               | コミット規約、ブランチ戦略、worktree 運用、PR ガイドライン、禁止事項 | 常時ロード    |
| markdown-style       | `**/*.md`               | Markdown 作成時のスタイルガイド                | 常時ロード    |
| plan-workflow        | All files               | プラン必須の原則と brainstorm / write-plan / execute-plan への振り分け | 常時ロード    |
| python-development   | `**/*.py`               | → `/python-dev-guide` スキルへのポインタ       | path-scoped   |
| react-coding         | `**/*.tsx`, `**/*.jsx`  | → `/react-dev-guide` スキルへのポインタ        | path-scoped   |
| typescript-coding    | `**/*.ts`, `**/*.tsx`   | → `/typescript-dev-guide` スキルへのポインタ   | path-scoped   |
