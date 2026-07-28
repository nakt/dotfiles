---
id: 20260711-execute-plan-commit-doc-conflict
title: execute-plan の implementer-prompt.md が SKILL.md のコミット方針と矛盾
created: 2026-07-11
updated: 2026-07-11
priority: med
tags: [skills, consistency]
related: []
sources:
  - .claude/skills/execute-plan/SKILL.md
  - .claude/skills/execute-plan/references/implementer-prompt.md
---

## TL;DR

execute-plan の `references/implementer-prompt.md:35` は「コミットは controller 側が `/commit` スキル経由で行います」と記載するが、SKILL.md 本文は「コミットは controller が直接 `git add` + `git commit` で行う」と定めており矛盾している。棚卸しで検出対象とした「二重管理の乖離」の実例。

## 背景 / 問い

2026-07-11 の execute-plan 実行（スキル棚卸し是正プラン）中に、controller がテンプレートを使用する際に発見。SKILL.md 側が後から直接コミット方式に更新され、references 側が追従していないと推測される。

## 調査結果

- 事実: `implementer-prompt.md:35`「コミットはしないでください。 コミットは controller 側が `/commit` スキル経由で行います。」
- 事実: SKILL.md の Constraints「implementer はコミットしない。コミットは controller が直接 `git add` + `git commit` で行う」および Phase 3 step 8 に直接コミット手順の詳細あり
- 事実: 実運用（今回の実行）では SKILL.md 通り controller が直接コミットした。テンプレート文言は実害こそ小さいが、implementer への指示文としてそのまま貼られるため誤情報が subagent に渡る
- 解釈: 正は SKILL.md 側。テンプレートの当該文を「コミットは controller が行います」に揃えるだけの小修正で解消する

## 結論 / プラン

- [ ] implementer-prompt.md:35 の「`/commit` スキル経由」を SKILL.md の直接コミット方式の記述に揃える

## 未解決の論点 / リスク

- なし（1 行の文言修正）

## ログ

- 2026-07-11 created
- 2026-07-11 done: implementer-prompt.md:35 を SKILL.md の直接コミット方式（controller が `git add` + `git commit`）に揃えて解消
  - 経緯: triage で即決案件としてピックアップ。SKILL.md の Constraints「コミットは controller が直接 `git add` + `git commit` で行う」を正とし、テンプレート側の「`/commit` スキル経由」の文言を 1 行修正した
  - 学び: SKILL.md 本文と references/ テンプレートの二重管理箇所は、本文更新時に references 側への追従漏れが起きやすい
