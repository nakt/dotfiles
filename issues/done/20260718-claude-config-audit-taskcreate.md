---
id: 20260718-claude-config-audit-taskcreate
title: claude-config-audit スキルに TaskCreate を導入して是正項目の進捗を可視化する
created: 20260718
updated: 20260724
priority: high
tags: [skill-improvement, taskcreate]
related: [20260718-plan-audit-taskcreate]
sources:
  - ~/.claude/skills/claude-config-audit/SKILL.md
  - ~/.claude/skills/execute-plan/SKILL.md
---

## TL;DR

`claude-config-audit` は「棚卸し → 報告 → 承認 → 是正 → 検証」の多段構成だが、TaskCreate を使っていない。是正対象が複数出るケースで進捗が見えないため、TaskCreate に是正項目を登録して in_progress / completed を回すのが有効。

## 背景 / 問い

- Claude Code のスキル群を見渡した結果、TaskCreate を使っているのは `execute-plan` のみ（25 スキル中 1 件）。
- `claude-config-audit` は description に「証拠付き報告 → ユーザー承認 → 是正 → 検証」と多段が明示されていて、対象も CLAUDE.md / rules / skills / agents を横断する。
- 是正項目が複数出るのが常態なのに、ユーザー側から「何が残っているか」を追う手段が無い。

## 調査結果

### スキル構造の事実

- `~/.claude/skills/claude-config-audit/SKILL.md`: 206 行、`## / ### / Phase / Step` 相当のセクションが 25 個。
- 中身は「棚卸し → 分析 → 報告 → 承認 → 是正 → 検証」で、是正フェーズが列挙的な作業になりやすい。
- 現状は tools 宣言に TaskCreate 系が入っていない（未使用）。

### `execute-plan` の先行事例

- Phase 2「タスク抽出と TaskList 作成」で `### Task N: ...` 見出しを抽出して `TaskCreate` に登録。
- 各タスクを `TaskUpdate(status=in_progress)` → 完了で `completed`、スキップは `deleted`。
- ここで確立された「プラン → TaskCreate 転写 → 状態遷移」というパターンをそのまま流用できる。

### 解釈

- claude-config-audit の「是正項目リスト」を TaskCreate に載せると、`execute-plan` と同型の UX になる（プラン相当の是正計画 + ランタイム進捗）。
- 追加の外部依存は無く、既存の Claude Code 内蔵ツールで完結する。

## 結論 / プラン

- [ ] `claude-config-audit/SKILL.md` の tools 宣言に `TaskCreate` / `TaskUpdate` / `TaskList` / `TaskGet` を追加
- [ ] 「是正」フェーズの手順に、承認済み是正項目を `TaskCreate` で登録するステップを追加
- [ ] 各是正項目着手時に `TaskUpdate(status=in_progress)`、完了時に `completed` を回す手順を明記
- [ ] スキップ / 却下時の `TaskUpdate(status=deleted)` パスも定義
- [ ] `execute-plan` の Phase 2 実装を参考実装として references から参照させる（重複記述を避ける）

## 未解決の論点 / リスク

- 是正が 1 件だけのケースで TaskCreate が過剰にならないか（閾値を設けるか、常に登録するか）。
- 是正の一部を `execute-plan` に委譲するパスと併存するか、それとも本スキル内で完結させるか（役割分担の設計判断）。
- SKILL.md の分量が既に多い（206 行）ため、TaskCreate 節を references に切り出す構成にするか。

## ログ

- 20260718 created
- 20260724 done: SKILL.md に TaskCreate 系ツール宣言と Phase 4/5/6 の追記を反映し PR #123 で完了
  - 経緯: プラン `.claude/plans/steady-baking-beacon.md` を作成 → plan-reviewer で 4 論点確認 → ExitPlanMode → execute-plan で 4 タスク (frontmatter allowed-tools / Phase 4 却下メモ + TaskCreate 登録 / Phase 5 状態遷移・粒度・委譲時保持ルール / Phase 6 完了条件追加) を逐次実装。各タスクとも初回レビューで APPROVED、修正ループなし。合計 11 行の追記 (見積もり通り)、PR #123 で main へ
  - 学び: (1) 既存フローに対称構造を残す追記 (「0 件なら完了 / 1 件以上なら TaskCreate」) は判断コストが最小。(2) ツール名と総称の字面衝突 (`TaskList` vs 「タスクリスト」) はプラン段階で用語表を分離しておくと実装時の迷いがなくなる。(3) 既存語彙 (「進捗報告の規律」) に接続する形で新概念を定義すると独立した新用語を増やさずに済む
