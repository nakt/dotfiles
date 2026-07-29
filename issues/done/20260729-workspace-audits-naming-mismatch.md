---
id: 20260729-workspace-audits-naming-mismatch
title: .workspace/audits/ が workspace-management の NN_作業名 命名規則に合っていない
created: 20260729
updated: 20260729
priority: low
tags: []
related: []
sources:
  - .claude/rules/workspace-management.md
  - .claude/skills/plan-audit/SKILL.md
---

<!-- タイトルは frontmatter の title が単一の真実。本文 H1 は置かない（MD025 回避） -->

## TL;DR

plan-audit の監査レポート保存先 `.workspace/audits/` は、workspace-management ルールの `NN_作業名/` 命名規則に従っていない。既存の齟齬で実害は未発生。2026-07-29 の plan-audit 監査で指摘された。

## 背景 / 問い

workspace-management ルールは `.workspace/` 直下のサブディレクトリを `NN_作業名/` 形式(例: `01_api-test/`)と定めるが、plan-audit SKILL.md は保存先を `.workspace/audits/` と規定しており、番号プレフィックスがない。どちらかの正典を直すべきか。

## 調査結果

- `audits/` は作業単位ではなく恒常的な蓄積先で、`NN_` の「作業ごとに採番」という意味論に合わない
- 選択肢: (a) workspace-management に恒常ディレクトリの例外を 1 行足す、(b) SKILL の保存先を `NN_audits/` 形式に変える、(c) 放置

## 結論 / プラン

- [x] (a) を採用。workspace-management の「ディレクトリ構造」節に、恒常的に蓄積するディレクトリは数値プレフィックスを付けない旨を 1 行追加した

## 未解決の論点 / リスク

- なし(実害未発生の既知齟齬)

## ログ

<!-- 追記専用。日付つきで状態変化を記録。 -->

- 20260729 created
- 20260729 done: 恒常ディレクトリは数値プレフィックスを付けない、を workspace-management に追記した
  - 経緯: 先送りの判定を PR のまとまりに変えた直後の見直しで、1 行で済み同じ PR に収まると判断して片付けた
  - 学び: 起票時は「別の関心事」と見て先送りにしたが、同じ日に .workspace/audits/ を 2 回使っており、実際には同じ作業の一部だった
