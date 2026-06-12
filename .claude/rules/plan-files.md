---
description: プランファイル作成時のワークフロー
paths:
  - "**/.claude/plans/*.md"
---

# プラン作成ルール

プランを作成・更新した後は、必ず以下を実行すること:

1. plan-reviewer サブエージェントを呼び出す
2. サブエージェントが曖昧な点を指摘した場合、ユーザーの回答を待つ
3. 回答を受けてプランを更新
4. 全ての曖昧さが解消されてから実装開始

## 実装タスクの記述形式 (execute-plan で実行する場合)

`/execute-plan` で実装フェーズを進めるプランには `## 実装タスク` セクションを設け、各タスクを以下の構造で書く。controller はこの形式を前提にタスクを抽出し、fresh subagent に Context を渡す。

````markdown
## 実装タスク

### Task 1: <短い動詞句のタスク名>

目的: <1 文>

対象ファイル:

- `path/to/file.ts` (新規 / 編集 / 削除)

依存: なし / Task 0 完了後

Acceptance criteria:

- [ ] <観測可能な完了条件>
- [ ] <テスト合格条件>

Context:

<scene-setting。このタスクがどこに位置するか、周辺の前提、関連既存実装>
````

### 抽出規則 (controller 側の前提)

- `### Task N:` 見出しでタスクを抽出
- セクション本文の全文を implementer prompt の `[FULL TEXT of task]` に貼る
- `Acceptance criteria` を reviewer prompt の検証基準に貼る
- `対象ファイル` `Context` を implementer prompt の `[Context]` に貼る

### `## 実装タスク` セクションがないプラン

調査メモや設計メモ等、実装を伴わないプランは `## 実装タスク` セクションを設けなくてよい。`/execute-plan` は起動時に `AskUserQuestion` で誘導するため、必須ではない。
