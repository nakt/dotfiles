---
id: 20260718-plan-audit-taskcreate
title: plan-audit スキルに TaskCreate を導入して 3 部監査の指摘進捗を追えるようにする
created: 20260718
updated: 20260729
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
- 20260729 done: 前提とした 3 部構成が 98f2c15 で廃止され深掘り方式に変わったため、TaskCreate 導入は不要と判断して打ち切り
  - 経緯: triage で本件を推しとして取り上げた直後、リモートの修正 (58cd34e) を取り込んだところ、plan-audit が「4 部固定マトリクスを毎回消化する」方式から「観点メニュー (決め方 / 整合 / 手法 / 設計) から 2〜3 角度を選んで深掘りする」方式に変わっていた。3 部を固定タスクとして最初に登録する案 1 が成立しなくなり、選んだ角度は出力形式の `## 選んだ角度` 節で既に宣言される。案 2 (指摘単位の Task 化) は元々スコープ外。残していた「plan-audit の指摘を plan → execute-plan に流すパス」の別 issue 起票も、plan-workflow.md に合流手順が明記済みのため見送った
  - 学び: (1) TaskCreate の横展開が効くのは是正・実装フェーズを持つスキルに限る。claude-config-audit は是正作業があったから効いたが、報告して終わる plan-audit には追跡すべき作業単位が無い。同型に見えるスキルでも「複数の作業単位が残るか」で要否が分かれる。(2) スキルの構成 (何部構成か) に依存した issue は、スキル本体の改修で前提ごと消える。起票から日が経った issue は着手前に対象ファイルの現状を確認する。(3) 本 issue 自身が「未解決の論点」の 1 番目に書いた過剰演出の懸念が、結論を先取りしていた。論点欄は着手判断の材料として読み直す価値がある
