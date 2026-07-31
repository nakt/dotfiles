---
id: 20260731-design-memo-storage-location
title: 設計メモの保存先を揃えるか
created: 20260731
updated: 20260731
priority:
tags: []
related: []
sources:
  - .claude/skills/brainstorm/SKILL.md
  - .claude/skills/write-plan/SKILL.md
  - docs/workflow/memo/
  - .claude/plans/
---

<!-- タイトルは frontmatter の title が単一の真実。本文 H1 は置かない（MD025 回避） -->

## TL;DR

今回の棚卸しでプランファイルの保存先を `.claude/plans` に一本化した（git 管理外、実装後は破棄してよい扱い）。一方 brainstorm の設計メモは `docs/workflow/memo/` のままで、git 管理下に入る。両者は寿命が同じ（実装まで必要、実装後は破棄してよい）という整理をしており、保存先が揃っていない状態が残っている。

## 背景 / 問い

Claude Code 設定群の棚卸しで、プランの保存先を `.claude/plans` に統一する判断を行った際に気づいた。設計メモも同じ寿命の考え方に従うなら、保存先の非対称性をどう扱うかが未決着のまま残る。

## 調査結果

- プランファイル: `.claude/plans/` に保存。git 管理外。実装後は破棄してよい運用に揃えた
- 設計メモ（brainstorm の確定判断）: `docs/workflow/memo/` に保存。git 管理下
- ユーザーの整理では、設計メモ・合意事項は「実装まで必要、実装後は破棄してよい」もので、寿命はプランと同じ
- 寿命が同じなら保存先の扱い（git 管理下か否か、ディレクトリ階層）も揃えるのが自然だが、今回の棚卸しでは brainstorm 側の保存先変更までは着手していない

## 結論 / プラン

- [ ] 保存先を揃える（`docs/workflow/memo/` を `.claude/` 配下に移すか、`.claude/plans` を `docs/` 配下の git 管理下に戻すか）か、据え置くかを決める
- [ ] 据え置く場合は「プランは git 管理外・設計メモは管理下」の非対称性を説明できる理由を明文化する

## 未解決の論点 / リスク

- 揃える場合、`docs/workflow/memo/` を `.claude/` 配下に移すか、逆に `.claude/plans` を git 管理下の `docs/` 配下に戻すかで判断が割れる
- 揃えない場合、「なぜプランは git 管理外で設計メモは管理下なのか」を説明できる理由が要る（例: 設計メモは意思決定の記録として残す価値がある、など）
- 据え置く選択肢もあり、その場合は理由を明文化しておくと今回の判断が再度掘り返されずに済む

## ログ

<!-- 追記専用。日付つきで状態変化を記録。 -->

- 20260731 created
- 20260731 結論/プランに次アクションを追記
- 20260731 done: 現状維持と判断（設計メモは `docs/workflow/memo/` のまま据え置き）
  - 経緯: プランは git 管理外の `.claude/plans` だが、設計メモは検討の経緯として git 管理下に残す価値があると判断した。あわせて write-plan 側に設計メモを読む手順を追加し、引き渡しの受け手側が存在しなかった問題を解消した。
