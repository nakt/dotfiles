# CLAUDE.md

このファイルは全プロジェクト共通のユーザー設定であり、どのリポジトリで作業していても適用されます。

## コミュニケーションルール

- 常に日本語で会話する
- 比喩表現を避け、状態は素直に記述する (例: 「凍る」ではなく「応答が返らない」)

## 利用可能な Rules

Rules は 7 件で固定的なので下表を台帳として置く。Skills は追加・改廃が頻繁なので台帳を置かず、`~/.claude/skills/` の実体を唯一の情報源とする（手動呼び出し名はスキルのディレクトリ名で、`/<ディレクトリ名>` で起動する）。

「内容の適用先」はルールの中身が対象とするファイル、「ロード方式」はルール本文が読み込まれるタイミング。

| Rule                 | 内容の適用先            | 説明                                          | ロード方式    |
| -------------------- | ----------------------- | --------------------------------------------- | ------------- |
| workspace-management | All files               | .workspace ディレクトリの運用ルール            | 常時ロード    |
| git-workflow         | All files               | コミット規約、ブランチ戦略、worktree 運用、PR ガイドライン、禁止事項 | 常時ロード    |
| markdown-style       | `**/*.md`               | Markdown 作成時のスタイルガイド                | path-scoped   |
| plan-workflow        | All files               | プラン必須の原則と brainstorm / write-plan / execute-plan への振り分け | 常時ロード    |
| python-development   | `**/*.py`               | → `/python-dev-guide` スキルへのポインタ       | path-scoped   |
| react-coding         | `**/*.tsx`, `**/*.jsx`  | → `/react-dev-guide` スキルへのポインタ        | path-scoped   |
| typescript-coding    | `**/*.ts`, `**/*.tsx`   | → `/typescript-dev-guide` スキルへのポインタ   | path-scoped   |
