---
id: 20260731-claude-config-audit-wrapup-dispatch-blind
title: claude-config-audit と wrapup-dispatch が互いを知らない
created: 20260731
updated: 20260731
priority:
tags: []
related: []
sources:
  - .claude/skills/wrapup-dispatch/SKILL.md
  - .claude/skills/claude-config-audit/SKILL.md
  - .claude/skills/issue-tracker/SKILL.md
---

<!-- タイトルは frontmatter の title が単一の真実。本文 H1 は置かない（MD025 回避） -->

## TL;DR

`wrapup-dispatch` は反省・摩擦点（同じ修正の繰り返し / CLAUDE.md・rules 違反）を issue-tracker へ送り、再発防止のためのルール追加を促す出口を持つ。一方 `claude-config-audit` は設定群から重複・矛盾・陳腐化を削る出口を持つ。前者が生む issue が後者の削除対象を増やす循環になりうるが、両スキルは互いを一度も参照していない。

## 背景 / 問い

Claude Code 設定群の棚卸し作業中に気づいた。`grep -ln "claude-config-audit" .claude/skills/*/SKILL.md` は自スキルのみがヒットし、`wrapup-dispatch` からの参照が無い。逆方向も同様に無い。

## 調査結果

- `wrapup-dispatch` は会話履歴から反省・摩擦点を抽出し、再発防止のルール追加を issue-tracker への起票という形で提案する
- `claude-config-audit` は `.claude/` 配下の設定群（rules / skills / CLAUDE.md）を対象に、重複・矛盾・陳腐化した記述を洗い出して削る
- 両者は「ルール・設定を増やす方向の出口」と「減らす方向の出口」として対になりうるが、SKILL.md 同士に相互参照が無く、運用上つながっていない
- このままだと、wrapup-dispatch 経由で追加されたルールが増え続け、claude-config-audit の対象が肥大化する一方で、両者を結ぶ導線が無いため気づかれにくい

## 結論 / プラン

- [ ] 棲み分け（互いに独立させたまま）か、相互参照（片方の出力がもう片方の入力になることを明記する）かを決める
- [ ] 相互参照を採る場合は、循環呼び出しを避ける設計（例: 参照は文書内の言及のみに留め、スキル呼び出しの連鎖はしない）を先に固める

## 未解決の論点 / リスク

- 棲み分け（wrapup-dispatch は追加専任、claude-config-audit は削除専任のまま独立させる）か、相互参照（片方の出力がもう片方の入力になることを明記する）かは未検討
- 相互参照を持たせる場合、循環参照によるスキル呼び出しの複雑化を避ける設計が要る

## ログ

<!-- 追記専用。日付つきで状態変化を記録。 -->

- 20260731 created
- 20260731 結論/プランに次アクションを追記
- 20260731 done: 何もしないと判断
  - 経緯: `claude-config-audit`（rules を減らす出口）と `wrapup-dispatch`（rules を足す出口）が互いを参照しない件は、循環の存在は認識した上で、スキル間の結線を増やさない判断とした。
