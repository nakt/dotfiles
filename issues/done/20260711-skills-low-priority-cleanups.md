---
id: 20260711-skills-low-priority-cleanups
title: スキル棚卸しで見送った低優先改善のまとめ
created: 2026-07-11
updated: 2026-07-18
priority: low
tags:
  - hold
  - skills
  - cleanup
related: []
sources:
  - .claude/plans/rosy-bouncing-whisper.md
  - .claude/skills/playwright-cli/SKILL.md
  - .claude/skills/cleanup-files/SKILL.md
  - .claude/skills/refactor-code/SKILL.md
---

## TL;DR

2026-07-11 のスキル棚卸し（25 スキル）で検出したが、是正プランで意図的に見送った低優先の改善候補 3 点をまとめて記録する。いずれも実害は小さく、次回の claude-config-audit 実行時に再評価すればよい。

## 背景 / 問い

是正プラン（rosy-bouncing-whisper）の「スコープ外」節からの持ち越し。忘却防止のため 1 件に束ねて起票。

## 調査結果

1. playwright-cli 本文の外出し（プラン D5 で見送り）
   - 事実: 本文 406 行の大半が汎用 CLI コマンドリファレンスの列挙で、references/ 10 ファイルへのリンク集も持つ
   - 事実: 公式推奨の 500 行以内には収まっており実害なし
2. prompting 双子・dev-guide 三つ子の共通フォーマット規約化
   - 事実: fable5-prompting / gpt5-prompting は章立て（モード判定 / Review Checklist / Quick Reference / References）が完全に同型。python / react / typescript-dev-guide も共通テンプレ構造（Tech Stack / Quick Start / Decision Guide 等）
   - 解釈: フォーマット規約を 1 箇所に持たせると保守が楽になるが、現状破綻はしていない
3. cleanup-files / refactor-code の旧書式統一
   - 事実: 両スキルは本文がほぼ英語 + 末尾にのみ日本語出力指定を置く旧書式。他スキルは Constraints 等に日本語指定を織り込む新書式
   - 解釈: 表現統一の余地（軽微）

## 結論 / プラン

- [x] 次回 claude-config-audit 実行時に 3 点を再評価し、着手するものだけ個別 issue に切り出す

## 未解決の論点 / リスク

- なし（低優先の改善候補の記録が目的）

## ログ

- 2026-07-11 created
- 2026-07-11 hold: 次回 claude-config-audit 実行時の再評価待ち（実害なしの見送り 3 点、単独で動かす目処なし）
- 2026-07-18 done: cleanup-files/refactor-code の新書式化と dev-guide 三つ子(python + typescript)の章順揃えを実施。prompting 双子の章名統一は本文とのズレを避けるため見送り、playwright-cli 本文外出しはオフィシャルスキル差し替え予定のため対象外
