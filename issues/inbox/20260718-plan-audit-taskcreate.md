---
id: 20260718-plan-audit-taskcreate
title: plan-audit スキルに TaskCreate を導入して 3 部監査の指摘進捗を追えるようにする
created: 20260718
updated: 20260724
priority: med
tags: [skill-improvement, taskcreate]
related: [20260718-claude-config-audit-taskcreate]
sources:
  - ~/.claude/skills/plan-audit/SKILL.md
  - ~/.claude/skills/execute-plan/SKILL.md
---

## TL;DR

`plan-audit` は「プロセス監査 / 構造監査 / 手法監査」の 3 部構成で、指摘が複数出るのが前提の作りだが、TaskCreate を使っていない。3 部それぞれ、あるいは指摘単位で TaskCreate に載せると、レビュー進捗と対応状況が可視化される。

## 背景 / 問い

- Claude Code のスキル群を見渡した結果、TaskCreate を使っているのは `execute-plan` のみ。
- `plan-audit` は description に「プロセス監査(決め方の妥当性)、構造監査(パイプライン・ロジックの整合性)、手法監査(手法選定の妥当性と代替手法の web 探索)の三部で構成する」と明記。
- 3 部監査で複数指摘が出るが、監査中の進捗も、監査後の対応状況も、UI に載らない。

## 調査結果

### スキル構造の事実

- `~/.claude/skills/plan-audit/SKILL.md`: 152 行、セクションマーカ 16 個。
- 手動起動専用（`/plan-audit` のみ）で、内容は独立した批判的レビュー。
- 現状 tools 宣言に TaskCreate 系は無い。

### 使い所の候補

1. 監査自体のフェーズ進捗: 「プロセス監査」「構造監査」「手法監査」の 3 タスクを最初に切って、部の完了ごとに TaskUpdate。
2. 指摘単位の追跡: 各部で出た指摘を子タスク相当として TaskCreate に登録し、対応済みかを追う。

案 1 は軽量で常に有効。案 2 は指摘件数が多いときに効くが、監査は「読み手に対する報告」が主目的なので、指摘を Task 化すると `plan-audit` の責務を超えて `execute-plan` 側に近づく。

### 解釈

- 案 1（3 部の進捗表示）は導入コスト小・効果小〜中で常に入れてよい。
- 案 2（指摘単位）は、`plan-audit` の指摘を plan ファイル化して `execute-plan` に流すパスを別途整備するのが本筋。ここは別 issue で扱うほうが綺麗。

## 結論 / プラン

- [ ] `plan-audit/SKILL.md` の tools 宣言に `TaskCreate` / `TaskUpdate` / `TaskList` / `TaskGet` を追加
- [ ] 監査開始時に 3 部（プロセス / 構造 / 手法）を `TaskCreate` で登録する手順を追加
- [ ] 部の着手時に `TaskUpdate(status=in_progress)`、完了時に `completed` を回す手順を明記
- [ ] 指摘単位の Task 化は本 issue のスコープ外とし、「plan-audit の指摘を plan → execute-plan に流す」パス整備は別 issue で扱う（未起票）

## 未解決の論点 / リスク

- 3 部監査の進捗表示は過剰演出にならないか（軽量な手動起動スキルなので、UI ノイズになる可能性）。
- 「指摘の Task 化」を別ルートに委ねる方針で本当に困らないか。
- SKILL.md 側に監査ワークフロー全体の Phase 番号を導入するかどうか（現状は 3 部を並列的に扱っている印象で、順序性は明示されていない）。

## ログ

- 20260718 created
