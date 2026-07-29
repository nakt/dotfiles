---
id: 20260729-plan-workflow-field-measurement
title: plan-workflow 軽量化の効果を次回プラン策定で実地計測する
created: 20260729
updated: 20260729
priority: med
tags: []
related: []
sources:
  - .workspace/11_plan-workflow-timing/timeline.py
  - .claude/plans/rosy-drifting-dove.md
---

<!-- タイトルは frontmatter の title が単一の真実。本文 H1 は置かない（MD025 回避） -->

## TL;DR

plan-workflow 軽量化(PR: refactor/plan-workflow-lightweight)の効果は次回のプラン策定 1 回でしか計測できない。次回策定後にセッションログを timeline.py で計測し、目標達成を確認する。

## 背景 / 問い

2026-07-29 の実測(swc-voc-analyzer-v3 セッション e7a67126)でプラン策定に 33〜52 分を要し、plan-workflow / plan-reviewer / plan-audit / execute-plan の 4 定義ファイルを軽量化した。効果見積り(策定 20 分以下)は n=1 の実測に依存しており、監査でも未検証事項として指摘された。

## 調査結果

計測手順: 対象セッションの `~/.claude/projects/<project>/<session-id>.jsonl` に対して `.workspace/11_plan-workflow-timing/timeline.py` を実行する。

確認項目:

- reviewer / auditor が同一メッセージで並列起動されていること
- プラン全文の Write 再生成が発生していないこと(改訂はすべて Edit)
- プラン策定の壁時計時間が 20 分以下(ユーザー回答待ちを除く)
- プラン本文が 20KB 以下

## 結論 / プラン

- [ ] 次回の監査該当プラン策定後、上記 4 項目を計測して結果をこの issue に追記する

## 未解決の論点 / リスク

- マージ後にしか実行できないため、本 issue はプラン(rosy-drifting-dove)の完了条件ではない
- timeline.py は .workspace 配下(gitignore)にあり、消えた場合は過去セッションのタイムライン解析スクリプトとして再作成が必要

## ログ

<!-- 追記専用。日付つきで状態変化を記録。 -->

- 20260729 created
