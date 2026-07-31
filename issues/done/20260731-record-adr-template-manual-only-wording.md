---
id: 20260731-record-adr-template-manual-only-wording
title: record-adr のテンプレートが手動専用に読める
created: 20260731
updated: 20260731
priority:
tags: []
related: []
sources:
  - .claude/skills/record-adr/SKILL.md
  - .claude/skills/record-adr/templates/readme.md
---

<!-- タイトルは frontmatter の title が単一の真実。本文 H1 は置かない（MD025 回避） -->

## TL;DR

`.claude/skills/record-adr/SKILL.md` の description は「重要な設計・ロジック判断が下された場面で使う。手動 `/record-adr [タイトル]` でも呼べる」に修正済みで、`disable-model-invocation: false` と整合している。しかし `templates/readme.md` には「起票は `/record-adr [タイトル]` で行う」という手動専用に読める記述が残っており、生成物（`docs/adr/README.md`）に不整合な説明が伝播する。

## 背景 / 問い

Claude Code 設定群の棚卸しで `record-adr/SKILL.md` の description を、自動発火も手動発火もあり得る書き方に修正した。しかし `templates/readme.md`（`docs/adr/README.md` として生成される雛形）側の文言は未修正のまま残った。

## 調査結果

- `SKILL.md` の description（修正後）: 「重要な設計・ロジック判断が下された場面で使う。手動 `/record-adr [タイトル]` でも呼べる」。`disable-model-invocation: false` であり、モデルからの自動起動を妨げない設定と整合している
- `templates/readme.md` の記述: 「起票は `/record-adr [タイトル]` で行う」。この書き方だと手動コマンド実行が唯一の起票手段であるかのように読める
- `templates/readme.md` は `docs/adr/README.md` として実プロジェクトに生成される文書のため、この記述のずれはユーザー向けドキュメントにそのまま伝播する

## 結論 / プラン

- [ ] `templates/readme.md` の「起票は `/record-adr [タイトル]` で行う」を、自動発火でも起票されうることが伝わる文言に書き換える

## 未解決の論点 / リスク

- 修正後の文言は「自動発火でも起票されうる」ことを README 読者に分かる形で伝える必要がある。単に手動コマンドの記述を削るだけでは、起票のトリガー条件が伝わらなくなる可能性がある

## ログ

<!-- 追記専用。日付つきで状態変化を記録。 -->

- 20260731 created
- 20260731 結論/プランに次アクションを追記
- 20260731 done: templates/readme.md の文言を修正し SKILL.md の description と整合
  - 経緯: record-adr/templates/readme.md の記述を「起票は record-adr スキルが行う。重要な設計・ロジック判断が下された場面では自動で起票が提案され、明示したいときは `/record-adr [タイトル]` で呼び出す」に変更した。
