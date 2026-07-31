---
id: 20260731-python-refactor-markdownlint
title: python-refactor の markdownlint 指摘 3 件
created: 20260731
updated: 20260731
priority:
tags: []
related: []
sources:
  - .claude/skills/python-refactor/SKILL.md
---

<!-- タイトルは frontmatter の title が単一の真実。本文 H1 は置かない（MD025 回避） -->

## TL;DR

`.claude/skills/python-refactor/SKILL.md` に既存の markdownlint 指摘が 3 件残っている。MD040（フェンスコードブロックの言語未指定）が 2 件、MD031（フェンス前後の空行不足）が 1 件。Claude Code 設定群の棚卸しの承認範囲外だったため据え置いた。

## 背景 / 問い

Claude Code 設定群の棚卸し作業中、`.claude/skills/python-refactor/SKILL.md` を確認した際に markdownlint 指摘が既存で残っていることに気づいたが、今回のプランの承認範囲（棚卸し対象）に含まれていなかったため修正しなかった。

## 調査結果

- 対象ファイル: `.claude/skills/python-refactor/SKILL.md`
- 指摘内容:
  - MD040（フェンスコードブロックの言語未指定）: 2 件
  - MD031（フェンス前後の空行不足）: 1 件
- 実測（`markdownlint-cli2 --config ~/.config/markdown-cli2/.markdownlint-cli2.jsonc .claude/skills/python-refactor/SKILL.md`、20260731 時点）:

  ````text
  .claude/skills/python-refactor/SKILL.md:46 MD040/fenced-code-language Fenced code blocks should have a language specified [Context: "```"]
  .claude/skills/python-refactor/SKILL.md:58 MD040/fenced-code-language Fenced code blocks should have a language specified [Context: "```"]
  .claude/skills/python-refactor/SKILL.md:61 MD031/blanks-around-fences Fenced code blocks should be surrounded by blank lines [Context: "```"]
  ````

- 上記の行番号は実測時点のもの。同ファイルは並行タスクが編集中で行番号が動くため、着手時は再度 markdownlint-cli2 を実行して行番号を取り直すこと

## 結論 / プラン

- [ ] 着手時に markdownlint-cli2 を再実行して行番号を取り直し、MD040 x2 / MD031 x1 を Edit で修正する

## 未解決の論点 / リスク

- 修正時は PostToolUse hook の markdownlint 実行結果を見ながら Edit で直すのが確実
- 該当箇所を特定するには改めて `.claude/skills/python-refactor/SKILL.md` を対象に markdownlint を走らせる必要がある

## ログ

<!-- 追記専用。日付つきで状態変化を記録。 -->

- 20260731 created
- 20260731 markdownlint-cli2 実測結果（行番号）と結論/プランの次アクションを追記
- 20260731 done: markdownlint 指摘（MD040 x2 / MD031 x1）をすべて解消
  - 経緯: python-refactor の SKILL.md と references の markdownlint 指摘を修正した。あわせて references の構成も整理し、コマンドと閾値を tools.md に集約した。
