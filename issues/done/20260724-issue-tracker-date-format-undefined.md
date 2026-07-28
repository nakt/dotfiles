---
id: 20260724-issue-tracker-date-format-undefined
title: issue-tracker skill の frontmatter 日付フォーマットが未定義で混在している
created: 20260724
updated: 20260724
priority: med
tags: []
related: []
sources:
  - ~/.claude/skills/issue-tracker/SKILL.md
  - ~/.claude/skills/issue-tracker/templates/issue-template.md
---

## TL;DR

`issue-template.md` の `created: {created}` / `updated: {updated}` に入れる日付フォーマットが SKILL.md で定義されていない。結果として実際の issue で `20260718` 形式と `2026-07-11` 形式が混在しており、エージェントが triage や日付比較を行うときに解釈揺れを起こす。SKILL.md 側でフォーマットを 1 つに固定する。

## 背景 / 問い

- SKILL.md の create 手順には「`created` と `updated` は Today」としか書かれていない。Today のフォーマットは指定されていない。
- id 側は `YYYYMMDD-slug`（ハイフンなし 8 桁）で規約が明文化されている。
- そのため実装時に「id と揃える (`YYYYMMDD`)」派と「ISO 8601 の可読性 (`YYYY-MM-DD`)」派に分かれて、同一 skill 内で両フォーマットが生成されている。
- `## ログ` の追記書式（`- <date> done: ...` / `- <Today> hold: ...` など）でも `<date>` のフォーマットが定義されていない。

## 調査結果

### 事実: 既存 issue の混在状況

`grep '^created:\|^updated:' issues/inbox/*.md issues/done/*.md` で確認した結果、次のように 2 形式が混在していた。

- YYYYMMDD 形式（ハイフンなし）:
  - `20260717-commit-slash-fails-on-empty-repo.md`: `created: 20260717` / `updated: 20260718`
  - `20260718-okf-format-taskcreate.md`: `created: 20260718` / `updated: 20260724`
  - `20260718-claude-config-audit-taskcreate.md`: `created: 20260718` / `updated: 20260724`
  - `20260718-plan-audit-taskcreate.md`: `created: 20260718` / `updated: 20260724`
  - `20260724-pr-merge-worktree-support.md`: `created: 20260724` / `updated: 20260724`
- YYYY-MM-DD 形式（ISO 8601）:
  - `20260711-commit-workspace-knowledge-mismatch.md`: `created: 2026-07-11` / `updated: 2026-07-11`
  - `20260711-execute-plan-commit-doc-conflict.md`: `created: 2026-07-11` / `updated: 2026-07-11`
  - `20260711-execute-plan-edit-permission-interrupt.md`: `created: 2026-07-11` / `updated: 2026-07-11`
  - `20260711-skills-low-priority-cleanups.md`: `created: 2026-07-11` / `updated: 2026-07-18`
  - `20260715-execute-plan-implementer-self-check-gaps.md`: `created: 2026-07-15` / `updated: 2026-07-15`

7 月序盤の issue が ISO 形式、7 月半ば以降が YYYYMMDD 形式に寄っており、途中でエージェントの解釈が切り替わったと推測される。

### 事実: SKILL.md 内の関連記述

- id 規約: 「`id = YYYYMMDD-slug`。日付は Current state の Today から `YYYYMMDD`。」（明文化されている）
- create 手順 4: 「`created` と `updated` は Today。」（フォーマット指定なし）
- ログ書式: `- <Today> hold: ...` / `- <date> done: ...` / `- <Today> progress: ...` / `- <Today> unhold: ...` などが登場するが、`<Today>` `<date>` のフォーマットは未指定。
- テンプレートの初期ログ行: `- {created} created`（frontmatter と同じ値が入る前提だが、その値のフォーマットが未定義）

### 解釈: どちらに寄せるべきか

- 整合性: id は `YYYYMMDD` で固定。frontmatter・ログも `YYYYMMDD` に揃えれば skill 内で表記が一意になる。
- 可読性: `2026-07-24` の方が人間には読みやすい。ただし triage 時にエージェントが読むのが主で、人間が閲覧する頻度は高くない。
- ソート: 両形式とも文字列ソートで時系列順になるため差は無い。
- 実装コスト: SKILL.md の 1 箇所に「日付は `YYYYMMDD` 形式で書く（id と同じ）」と定義するだけで済む。既存 issue の一括変換は任意（frontmatter を読むエージェントが両形式を許容できるなら後回しでもよい）。

## 結論 / プラン

- [ ] SKILL.md の create 手順に「`created` / `updated` は `YYYYMMDD` 形式で書く（id の日付部分と同じ表記）」を明記する。
- [ ] 同じく `## ログ` 節の書式説明で `<Today>` / `<date>` のフォーマットが `YYYYMMDD` であることを明記する。
- [ ] テンプレート `issue-template.md` の該当箇所にコメントで「YYYYMMDD 形式」の注釈を入れるかを検討する（SKILL.md だけで十分か、テンプレート側にも冗長に書くか）。
- [ ] 既存の ISO 形式で書かれた issue（`done/` に 5 件）を一括変換するかは別途判断する。done 済みなので放置してもよい。

## 未解決の論点 / リスク

- フォーマットを `YYYYMMDD` と `YYYY-MM-DD` のどちらに寄せるか。上記の通り `YYYYMMDD` 推奨だが、Front matter を機械処理する外部ツール（例: GitHub Pages, Obsidian など）が ISO 8601 を要求する可能性は要確認。現状はエージェント内で完結しているため影響は無い想定。
- 既存 issue の遡及変換をやるか。done は履歴なので触らない方が安全という考え方もある。
- `related:` に id を書く規約と、`sources:` にファイルパスを書く規約は既に明文化されている。日付フォーマットもそれらと同じ扱いで規約化する。

## ログ

- 20260724 created
- 20260724 done: SKILL.md 側で日付フォーマットを `YYYYMMDD` に規約化して単一の真実に集約した
  - 経緯: `docs/issue-tracker-date-format` ブランチで SKILL.md の 3 箇所を修正（Current state の Today 表示コマンドを `date +%Y%m%d` に、create 手順 4 に「`YYYYMMDD` 形式、id の日付部分と同じ表記」を追記、Key Principles 4 に frontmatter と `## ログ` の日付表記も `YYYYMMDD` で統一する規約を統合）。既存 issue の inbox は全件 `YYYYMMDD` 済み、`done/` に残る ISO 形式 5 件は遡及変換しない方針で確定。
  - 学び: 規約は SKILL.md の Key Principles に集約して単一の真実にする方が、テンプレートや各手順箇所に冗長化するより保守しやすい（更新漏れが起きない）。history 側は触らず、今後の新規起票から統一していけば十分。
