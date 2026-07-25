# CLAUDE.md

このファイルは、このリポジトリで作業する際の Claude Code へのガイダンスを提供します。

## 構造

- Rules (`~/.claude/rules/`): 各ルールの質的な定義。frontmatter に `paths` がないルールは起動時に常時ロードされ CLAUDE.md と同格に常駐する。`paths` があるルールは該当パターンのファイルを扱うときにロードされる。CLAUDE.md からの `@` import は、それとは独立に起動時ロードする別経路（下表「常時参照」列）
- Skills (`~/.claude/skills/`): YAML frontmatter の description でトリガー判定、`/name` で手動呼び出しも可能。一覧は `~/.claude/skills/` の実体を正典とし、CLAUDE.md 側に台帳は置かない

## 利用可能な Rules

| Rule                 | 対象                    | 説明                                          | 常時参照                                |
| -------------------- | ----------------------- | --------------------------------------------- | ----------------------------------------- |
| workspace-management | All files               | .workspace ディレクトリの運用ルール            | —（paths スコープでロード）              |
| git-workflow         | All files               | コミット規約、ブランチ戦略、PR ガイドライン    | —（paths スコープでロード）              |
| markdown-style       | `**/*.md`               | Markdown 作成時のスタイルガイド                | —（paths スコープでロード）              |
| plan-files           | `**/.claude/plans/*.md` | プランの承認用構成と検証ワークフロー            | —（paths スコープでロード）              |
| python-development   | `**/*.py`               | → `/python-dev-guide` スキルへのポインタ       | —                                         |
| react-coding         | `**/*.tsx`, `**/*.jsx`  | → `/react-dev-guide` スキルへのポインタ        | —                                         |
| typescript-coding    | `**/*.ts`, `**/*.tsx`   | → `/typescript-dev-guide` スキルへのポインタ   | —                                         |
