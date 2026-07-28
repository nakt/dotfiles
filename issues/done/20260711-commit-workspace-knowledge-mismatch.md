---
id: 20260711-commit-workspace-knowledge-mismatch
title: commit スキル step 6 の .workspace/knowledge/ が workspace-management ルールと不整合
created: 2026-07-11
updated: 2026-07-11
priority: med
tags: [skills, consistency]
related: []
sources:
  - .claude/skills/commit/SKILL.md
  - .claude/rules/workspace-management.md
  - .claude/plans/rosy-bouncing-whisper.md
---

## TL;DR

commit スキルの step 6 は project memory を `.workspace/knowledge/` に蓄積すると指示するが、workspace-management ルールは `.workspace/` 直下に `NN_作業名/` 形式のサブディレクトリを要求しており命名規則が食い違う。さらに `.workspace/` は gitignore 対象なので、永続ナレッジの置き場として適切かも要検討。

## 背景 / 問い

2026-07-11 のスキル棚卸しで検出。是正プラン（rosy-bouncing-whisper）では挙動設計の変更を伴うためスコープ外として持ち越した。

## 調査結果

- 事実: `.claude/skills/commit/SKILL.md` step 6 は「Consider adding important policy changes, technical challenges, and solutions to `.workspace/knowledge/`」と指示する
- 事実: `.claude/rules/workspace-management.md` は `.workspace/` 直下にファイルを置かず `NN_作業名/`（数値プレフィックス）のサブディレクトリを作る規則を定める。`knowledge/` はこの命名に合致しない
- 事実: `.workspace/` はバージョン管理対象外（.gitignore 済み）
- 解釈: 「一時作業ファイル置き場（.workspace）」に「将来も参照する永続ナレッジ」を置く設計自体に無理がある。issue-tracker（issues/）や record-adr（docs/adr）等の永続保存先ができた現在は役割が重複する

## 結論 / プラン

- [ ] step 6 の保存先方針を決める（候補: issue-tracker への起票提案に置き換え / workspace-management ルール側に knowledge/ の例外を明記 / step 6 自体を削除）
- [ ] 決定に沿って commit スキルまたは workspace-management ルールを修正する

## 未解決の論点 / リスク

- step 6 を削除する場合、コミット時のナレッジ蓄積という意図の受け皿をどうするか（wrapup-dispatch で代替可能か）

## ログ

- 2026-07-11 created
- 2026-07-11 done: commit スキル step 6 を削除し、ナレッジ蓄積は wrapup-dispatch / issue-tracker / record-adr の既存フローに委ねる方針を採用
  - 経緯: 3 候補（step 6 削除 / issue-tracker 等への起票提案に置き換え / workspace-management ルールに例外明記）を AskUserQuestion で提示し、ユーザーが削除を選択。commit SKILL.md から step 6（3 行）を削除した
  - 学び: gitignore 対象の一時ディレクトリに永続ナレッジを置く設計は、永続保存先スキル（issue-tracker / record-adr）が整備された時点で役割が破綻していた。保存先の矛盾はルール側の例外追認ではなく、指示自体の削除で根本解消する方が保守が軽い
