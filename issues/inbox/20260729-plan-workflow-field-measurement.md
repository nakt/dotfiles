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
- 改訂 1 回あたりの出力トークンが改訂範囲に見合っていること(数行の修正に全文 Write をしていないか)
- プラン策定の壁時計時間が 20 分以下(ユーザー回答待ちを除く)
- プラン本文が 20KB 以下

### 2026-07-29 実施分

対象: swc-voc-analyzer-v3 セッション b36b1451、プラン humble-questing-pillow。比較対象は改修前のセッション e7a67126、プラン channel-quadrant-csv-split。

| 確認項目 | 結果 |
| --- | --- |
| reviewer / auditor の並列起動 | 達成。同一メッセージで 3 秒差 |
| 改訂 1 回あたりの出力トークン | 初版 11,054 / 改訂 12,239。改訂は初版の 74% に及ぶ全面改訂で、範囲に見合う |
| 壁時計時間 | 達成。初版完成後の実働 17 分(ユーザー回答待ちを除く)。改修前は 27 分 |
| プラン本文 20KB 以下 | 未達。23.8KB |

改修前との差分:

- プラン本体の全文 Write: 4 回 48,293 トークン → 2 回 23,293 トークン
- レビュー + 監査: 直列 15 分 06 秒 → 並列 6 分 27 秒
- plan mode 用の別ファイル再生成: 13,252 トークン → 0(参照スタブのルールで消滅)
- プラン内の棄却案記述: 21 箇所 → 0(監査レポートへ 11 件移動)

計測の物差し: プラン・監査レポートの生成コストは、Write を含む assistant メッセージの `output_tokens` を合計する。この物差しは改修前の実測値(48k トークン)を再現できる。

## 結論 / プラン

- [x] 1 回目の計測を実施(2026-07-29、上記)
- [ ] 20KB 基準が妥当か次回計測時に再考する。本文の大きさはプランの対象範囲によるもので、ワークフロー改修で下がる指標ではない

## 未解決の論点 / リスク

- マージ後にしか実行できないため、本 issue はプラン(rosy-drifting-dove)の完了条件ではない
- timeline.py は .workspace 配下(gitignore)にあり、消えた場合は過去セッションのタイムライン解析スクリプトとして再作成が必要

## ログ

<!-- 追記専用。日付つきで状態変化を記録。 -->

- 20260729 created
- 20260729 1 回目の計測を実施。全文 Write を禁じていた確認項目は、実測で Edit の差分適用のほうが高コストと判明したため plan-workflow 側のルールごと削除し、「改訂 1 回あたりの出力トークン」に差し替えた
