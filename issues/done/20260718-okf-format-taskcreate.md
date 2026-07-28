---
id: 20260718-okf-format-taskcreate
title: okf-format のバンドルモードに TaskCreate を導入してファイル単位の進捗を可視化する
created: 20260718
updated: 20260724
priority: med
tags: [skill-improvement, taskcreate]
related: [20260718-claude-config-audit-taskcreate, 20260718-plan-audit-taskcreate]
sources:
  - ~/.claude/skills/okf-format/SKILL.md
---

## TL;DR

`okf-format` のバンドルモード（ディレクトリ全体を OKF バンドル化）は複数ファイルへの変換ループになるが、TaskCreate を使っていないため「どのファイルまで進んだか」がユーザーから見えない。ファイル単位で TaskCreate に登録すると、進捗と再開・スキップが扱いやすくなる。

## 背景 / 問い

- Claude Code のスキル群を見渡した結果、TaskCreate を使っているのは `execute-plan` のみ。
- `okf-format` は description に「単一の .md ファイルを OKF concept document に整形するモード」と「ディレクトリ全体を OKF バンドル（index.md / log.md / 概念ドキュメント群）に整理するモード」の 2 モードがあると明示。
- 後者はファイル数ぶんの変換が発生するが、単発モードと同じ実行モデルだと途中で止めた場合の再開が難しい。

## 調査結果

### スキル構造の事実

- `~/.claude/skills/okf-format/SKILL.md`: 210 行、セクションマーカ 19 個。
- 単一ファイルモードとバンドルモードの 2 系統がある。
- 現状 tools 宣言に TaskCreate 系は無い。

### バンドルモードで TaskCreate が効く理由

- ファイル単位のループなので、TaskCreate に登録すると:
  - 進捗が UI に出る（何件中何件完了か）。
  - 途中で止めても TaskList から未完了を拾って再開できる。
  - スキップ判断（既に OKF 準拠 / 変換対象外）を `TaskUpdate(status=deleted)` で残せる。
- 単一ファイルモードでは不要（1 タスクを立てるだけ過剰）。

### 解釈

- モードによって TaskCreate 適用を切り替えるのが自然。バンドルモードのみ導入する。
- 変換対象ファイルの列挙は、TaskCreate 登録前に一度スキャンして行う（`execute-plan` の Phase 2 と同型）。

## 結論 / プラン

- [ ] `okf-format/SKILL.md` の tools 宣言に `TaskCreate` / `TaskUpdate` / `TaskList` / `TaskGet` を追加
- [ ] バンドルモードの手順に、変換対象ファイルを列挙して `TaskCreate` に登録するステップを追加
- [ ] 各ファイル変換時に `TaskUpdate(status=in_progress)` → `completed`、スキップは `deleted` を回す手順を明記
- [ ] 単一ファイルモードでは TaskCreate を使わないことを明示（過剰運用防止）

## 未解決の論点 / リスク

- 変換対象ファイル数が多い（数十〜数百）場合、TaskCreate の一覧が肥大化しないか。
- 事前スキャンで対象を確定してから TaskCreate に登録するか、逐次登録するか。前者のほうが `execute-plan` 型で自然だが、対象決定が実行時に変わるモードなら後者になる。
- index.md / log.md の生成は「ファイル単位」ではないので、これらをどの粒度で Task 化するか。

## ログ

- 20260718 created
- 20260724 done: 対象スキル okf-format が公式スキル移行に伴い削除されたため、TaskCreate 導入の前提が消失
  - 経緯: 公式 okf 相当スキルがリリースされ、ローカルの okf-format スキルを削除する方針になった。改善対象が存在しなくなったため打ち切り
  - 学び: ローカル自作スキルは公式版が出ると陳腐化する。TaskCreate 系の類似 issue も、対象スキルの寿命を前提に着手優先度を判断すべき
