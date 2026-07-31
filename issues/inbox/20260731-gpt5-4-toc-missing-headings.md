---
id: 20260731-gpt5-4-toc-missing-headings
title: gpt-5-4.md の目次に見出しが載っていない
created: 20260731
updated: 20260731
priority:
tags: []
related: []
sources:
  - .claude/skills/gpt5-prompting/references/gpt-5-4.md
---

<!-- タイトルは frontmatter の title が単一の真実。本文 H1 は置かない（MD025 回避） -->

## TL;DR

`.claude/skills/gpt5-prompting/references/gpt-5-4.md` で、インライン見出し（`**Strengths**:` 形式）6 箇所を `###` 見出しに置き換えた。その結果「見出しなのに目次に載っていない項目」が 6 件生まれ、目次の完全性が下がっている。目次に 6 行追加する必要がある。

## 背景 / 問い

Claude Code 設定群の棚卸し作業中、`.claude/skills/gpt5-prompting/references/gpt-5-4.md` のインライン見出し（太字によるなんちゃって見出し）を正規の Markdown 見出しに置き換えるタスクが実施された。その副作用として目次との不整合が生じたが、目次自体の更新は今回のタスク範囲外だったため据え置いた。

## 調査結果

- 対象ファイル: `.claude/skills/gpt5-prompting/references/gpt-5-4.md`
- 変更内容: `**Strengths**:` のようなインライン見出し形式を `### Strengths` 相当の正規見出しに置き換えた（6 箇所）
- 副作用: 既存の目次にはこの 6 見出しへのリンク・項目が存在しないため、目次を見ても該当セクションの存在が分からない状態になった
- 実測（20260731 時点、`grep -n '^#' .claude/skills/gpt5-prompting/references/gpt-5-4.md` と目次の突き合わせ）で特定した目次未掲載の 6 見出し:
  - `### Strengths`（49 行目「## 1. 強み・弱みの概要」配下）
  - `### Areas needing explicit prompting`（同上「## 1. 強み・弱みの概要」配下）
  - `### gpt-5.4-mini の特性`（410 行目「## 26. Small Model Guidance（gpt-5.4-mini / nano）」配下）
  - `### mini プロンプティングの 7 原則`（同上「## 26. Small Model Guidance」配下）
  - `### gpt-5.4-nano`（同上「## 26. Small Model Guidance」配下）
  - `### 小型モデル向けの良いパターン`（同上「## 26. Small Model Guidance」配下）
  - 「## 20. Coding Tasks」「## 22. Personality & Customer-Facing Workflows」「## 24. Reasoning Effort 推奨」配下の `###` 見出しは既に目次に掲載済みのため対象外

## 結論 / プラン

- [ ] 目次の「1. 強み・弱みの概要」配下に Strengths / Areas needing explicit prompting を、「26. Small Model Guidance」配下に残り 4 見出しを追記する

## 未解決の論点 / リスク

- 目次の更新方式（手動追記か、目次生成ツールの利用か）は未検討
- 6 箇所の見出しが目次のどの階層・位置に入るべきかは、ファイル全体の構成を見た上で判断する必要がある

## ログ

<!-- 追記専用。日付つきで状態変化を記録。 -->

- 20260731 created
- 20260731 目次未掲載の 6 見出し名を実測して追記し、結論/プランの次アクションを追記
