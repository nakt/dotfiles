# CLAUDE.md

このファイルは、このリポジトリで作業する際の Claude Code へのガイダンスを提供します。

## コミュニケーションルール

- 常に日本語で会話する

## 構造

- Rules (`~/.claude/rules/`): 各ルールの質的な定義。下表の「常時参照」列で `@` import されたもののみが実際に読み込まれ、それ以外はスキル呼び出し用のポインタ中間ファイル
- Skills (`~/.claude/skills/`): YAML frontmatter の description でトリガー判定、`/name` で手動呼び出しも可能。一覧は `~/.claude/skills/` の実体を正典とし、CLAUDE.md 側に台帳は置かない

## 利用可能な Rules

| Rule                 | 対象                    | 説明                                          | 常時参照                                |
| -------------------- | ----------------------- | --------------------------------------------- | ----------------------------------------- |
| workspace-management | All files               | .workspace ディレクトリの運用ルール            | @~/.claude/rules/workspace-management.md  |
| git-workflow         | All files               | コミット規約、ブランチ戦略、PR ガイドライン    | @~/.claude/rules/git-workflow.md          |
| markdown-style       | `**/*.md`               | Markdown 作成時のスタイルガイド                | @~/.claude/rules/markdown-style.md        |
| plan-files           | `**/.claude/plans/*.md` | プラン作成後の検証ワークフロー                  | @~/.claude/rules/plan-files.md            |
| python-development   | `**/*.py`               | → `/python-dev-guide` スキルへのポインタ       | —                                         |
| react-coding         | `**/*.tsx`, `**/*.jsx`  | → `/react-dev-guide` スキルへのポインタ        | —                                         |
| typescript-coding    | `**/*.ts`, `**/*.tsx`   | → `/typescript-dev-guide` スキルへのポインタ   | —                                         |
