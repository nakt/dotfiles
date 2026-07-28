---
id: 20260717-commit-slash-fails-on-empty-repo
title: /commit slash command が初回コミット前のリポジトリで fatal エラーになる
created: 20260717
updated: 20260718
priority: low
tags: []
related: []
sources: []
---

## TL;DR

`/commit` が `git diff HEAD --stat` を呼ぶため、まだ 1 コミットも無い (HEAD 未確立) リポジトリで `fatal: ambiguous argument 'HEAD'` が出てテンプレ生成が止まる。初回コミット時のみ発生する低頻度不具合。

## 背景 / 問い

agent-plugins リポジトリの初回セットアップ中に `/commit` を実行したところ、以下のエラーで失敗した:

```text
Error: Shell command failed for pattern "!`git diff HEAD --stat`": [stderr]
fatal: ambiguous argument 'HEAD': unknown revision or path not in the working tree.
```

slash command 定義側で HEAD の有無を前提にしているのが原因。空リポジトリでは HEAD がまだ指し先を持たないため、`HEAD` を含む rev 系コマンドが軒並み失敗する。

## 調査結果

### 事実

- 発生条件: `git init` 直後 (root commit 未作成) の状態で `/commit` を起動
- 失敗箇所: slash command テンプレ内の `!`git diff HEAD --stat`` バッククォート展開
- 影響範囲: 初回コミットを Claude Code 経由で作ろうとしたときのみ。1 コミットでも積んだ後は再現しない
- 手動回避: 一旦手で `git commit` してから `/commit` を使えば以降は問題無し

### 解釈

初回コミットは頻度としては極めて低いユースケースだが、Claude Code に「セットアップから任せる」フローが崩れる点は体験として気になる。特に「まず /commit → ブランチ自動生成」を想定したワークフロー案内 (pr-merge 等) と噛み合わない。

## 結論 / プラン

- [ ] `/commit` slash command の Shell 展開部で HEAD 有無を判定してから分岐する
  - 判定: `git rev-parse --verify HEAD >/dev/null 2>&1`
  - HEAD あり: 現状どおり `git diff HEAD --stat`
  - HEAD なし: `git diff --cached --stat` (staged が空なら) `git ls-files --others --exclude-standard` にフォールバック
- [ ] 同種の HEAD 依存が他の Shell 展開 (`git log` など) にも無いか slash command 定義を確認

## 未解決の論点 / リスク

- 修正対象の slash command 定義がどこに置かれているか (dotfiles 側 か Claude Code 本体側か) を確認する必要がある。dotfiles 側なら本 issue で対応、本体側なら upstream への feedback にとどめる
- HEAD 無しフォールバック時の生成コミットメッセージ品質 (diff が無く untracked list だけになるので、要約の作り方を変える必要があるかも)

## ログ

- 20260717 created
- 20260718 done: fixed via PR #119 (fallback guard + initial-commit branch in Your Tasks + Bash(echo:*) permission)
  - 経緯: プランを `.claude/plans/issues-inbox-20260717-commit-slash-fail-tidy-heron.md` に作成し、execute-plan スキルで T1 (17-18 行の HEAD ガードを `2>/dev/null || echo '(no commits yet)'` フォールバックで保護)、T2 (`## Your Tasks` に初回コミット分岐 Step 2 を挿入 + 旧 Step 2-5 を 3-6 にリナンバー)、T3 (`allowed-tools` に `Bash(echo:*)` を予防的追加) の 3 タスクを fresh implementer / reviewer で回して 3 コミット作成、PR #119 で main へ merge
  - 学び: 他 skill (`wrapup-dispatch`, `pr-merge`) の既存フォールバックパターンに揃えるだけで解決でき、issue Conclusion で言及されていた `git rev-parse --verify HEAD` 分岐案よりシンプル。ただし `echo` 実行のため `allowed-tools` への予防追加が同時に必要 (allowlist 判定コンテキストがシェル直打ちと異なり事後検出しづらいため予防で入れる)
