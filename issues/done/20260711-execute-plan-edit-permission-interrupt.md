---
id: 20260711-execute-plan-edit-permission-interrupt
title: execute-plan 実行中の Edit 権限プロンプトで自律実行が中断する
created: 2026-07-11
updated: 2026-07-11
priority: med
tags: [workflow, permissions]
related: []
sources:
  - .claude/settings.json
  - .claude/skills/execute-plan/SKILL.md
---

## TL;DR

execute-plan の implementer subagent が `.claude/skills/` 配下のファイルを Edit した際、権限プロンプトで 2 件拒否され自律実行が中断した（Task 7、update-readme / humanize の書式統一）。ユーザー確認の往復が 1 回増え、連続実行というスキルの狙いが崩れる。再発防止策を検討したい。

## 背景 / 問い

2026-07-11 のスキル棚卸し是正プラン実行中に発生した摩擦点。wrapup-dispatch の反省点抽出から起票。

## 調査結果

- 事実: Task 7（19 ファイルの frontmatter 修正）で、implementer の Edit のうち update-readme / humanize への 2 件が権限プロンプトで拒否され、subagent が中断・controller へエスカレーションした
- 事実: ユーザーに確認したところ「適用して完遂させる」との回答で、拒否は意図的なブロックではなかった。最終的に controller が直接適用して解決
- 事実: `.claude/settings.json` の permissions.allow に Edit 系の許可ルールは無い（Bash 系と Read 系が中心）
- 解釈: 大量ファイルを並列 subagent で編集する execute-plan の設計と、Edit ごとの権限確認の相性が悪い。対策候補は複数ある

## 結論 / プラン

- [ ] 対策を選ぶ（候補: settings.json に `Edit(.claude/**)` 等の許可を追加 / execute-plan の SKILL.md に「実行前に acceptEdits モードを推奨」と明記 / implementer へのエスカレーション手順として現状を許容）
- [ ] 選んだ対策を実装する

## 未解決の論点 / リスク

- `.claude/` 配下への Edit を常時許可すると、設定ファイルの意図しない書き換えリスクが上がる。スコープ（skills のみ等）と安全性のバランスを要検討

## ログ

- 2026-07-11 created
- 2026-07-11 done: execute-plan SKILL.md の Phase 1 に acceptEdits モード切り替え案内のステップを追加して対策
  - 経緯: 対策 3 候補（settings.json への Edit 常設許可 / SKILL.md への acceptEdits 案内明記 / 現状許容）を AskUserQuestion で提示し、ユーザーが acceptEdits 案内を選択。Phase 1 事前チェックの step 8 として「実装開始前に acceptEdits モード (shift+tab) への切り替えを 1 度だけ案内し、返答は待たずに続行してよい」を追記した
  - 学び: execute-plan は任意パスのプランを扱うため、パス限定の Edit 常設許可では中断の再発を防げない。セッション限定の acceptEdits の方がスキルの自律実行設計と整合する
