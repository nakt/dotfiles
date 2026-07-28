---
id: 20260724-pr-merge-worktree-support
title: pr-merge スキルに worktree 内実行の分岐を入れる
created: 20260724
updated: 20260724
priority: med
tags: [skill, pr-merge, git-worktree]
related: []
sources:
  - ~/.claude/skills/pr-merge/SKILL.md
---

<!-- タイトルは frontmatter の title が単一の真実。本文 H1 は置かない -->

## TL;DR

`/pr-merge` を子 worktree 内で実行すると、`gh pr merge --delete-branch` の cleanup が `git checkout <base>` で fatal 停止し、リモートブランチ削除まで到達しない不完全失敗を招く。worktree 検出 → 分岐でマージ手順を切り替え、リモート削除を明示化、ローカル cleanup は親 worktree 側に案内するようスキルを更新する。

## 背景 / 問い

swc-voc-analyzer-v3 の `.claude/worktrees/tender-jingling-anchor` で作業した PR #105 をマージする際、`/pr-merge` が生成した `gh pr merge 105 --merge --delete-branch` が fatal 停止した:

```text
failed to run git: fatal: 'main' is already used by worktree at '/Volumes/Data/.../swc-voc-analyzer-v3'
```

原因: `gh pr merge --delete-branch` は内部で以下を順に実行する。

1. GitHub API: PR マージ
2. `git checkout <base>` （ローカルで base ブランチに戻る）
3. `git branch -d <feature-branch>` （ローカルブランチ削除）
4. GitHub API: リモートブランチ削除

worktree 運用では base ブランチ（通常 main）が親クローンで既に checkout 済みのため、手順 2 で fatal 停止。手順 3・4 に到達せず、リモートブランチも残る不完全状態になる。実際、事後の `git ls-remote --heads origin <branch>` で残存確認し、`git push origin --delete <branch>` を手動実行して回避した。

## 調査結果

### 事実: git worktree の制約

`refs/heads/<branch>` は同一 `.git` を共有する worktree 群の中で 1 個のみ。「1 branch = 1 worktree」の 1:1 対応が git のロック機構として強制されている。base ブランチが親 worktree で checkout 済みの状態で、子 worktree から `git checkout <base>` は必ず fatal になる。

### 事実: `gh pr merge --delete-branch` の cleanup 手順

- 手順 2 の `git checkout <base>` は「今のブランチを消せる状態にするため」に走る
- 手順 2 が fatal になると、手順 3・4 は実行されない（gh はエラーで abort）
- リモート API 削除（手順 4）が「先」か「後」かに依らず、fatal で中断されると副作用が中途半端に残る（今回はリモートも残った）

### 事実: worktree 判定コマンド

```bash
git rev-parse --git-dir
```

- 親 worktree: `.git` を返す（相対パスで）
- 子 worktree: `/path/to/repo/.git/worktrees/<name>` の形の絶対パスを返す

または:

```bash
git rev-parse --git-common-dir
git rev-parse --git-dir
```

の 2 値が一致しない → 子 worktree。判定材料は複数あるが、`--git-dir` の出力に `worktrees/` が含まれるかで判定するのが最も簡潔。

### 解釈: 子 worktree 用の正しいマージ手順

```bash
# 1. マージだけ実行（--delete-branch を付けない）
gh pr merge <n> --merge

# 2. リモートブランチだけ手動で削除
git push origin --delete <branch>

# 3. ローカル cleanup は今の場所からできないので、親 worktree で後日:
#    cd <parent-worktree>
#    git fetch --prune
#    git worktree remove <this-worktree-path>
#    git branch -D <branch>
```

親 worktree で実行する場合は従来通り `gh pr merge <n> --merge --delete-branch` + `git checkout base && git pull && git branch -d` で問題なし。

## 結論 / プラン

- [ ] `~/.claude/skills/pr-merge/SKILL.md` の Phase 4 マージ手順に worktree 判定分岐を追加
  - `git rev-parse --git-dir` の出力に `worktrees/` が含まれるかで判定
  - 親 worktree の場合: 現行通り `gh pr merge <n> --merge --delete-branch` + ローカル cleanup
  - 子 worktree の場合:
    1. `gh pr merge <n> --merge`
    2. `git push origin --delete <branch>` （リモート削除）
    3. `git ls-remote --heads origin <branch>` で削除確認（空なら OK）
    4. ローカル cleanup 手順をユーザー案内に載せる（親 worktree 側で `git worktree remove` + `git branch -D` を促す）
- [ ] Constraints 節に「worktree 内では --delete-branch を使わない」旨を追記
- [ ] エラーハンドリング表に「fatal: 'X' is already used by worktree at ...」ケースを追加（→ worktree 分岐で回避される旨）

## 未解決の論点 / リスク

- worktree 判定コマンドの選定: `git rev-parse --git-dir` 経由か、`git worktree list` + 現在パス突き合わせか。前者の方がシンプル
- 「親 worktree で feature ブランチ / 子 worktree で main」の逆パターン（親が base ブランチを持たない配置）でも動くか。判定は「その worktree が base ブランチを checkout できるか」ではなく「その worktree が子か親か」だけを見れば十分だが、base ブランチが未 checkout な場合の cleanup 動作は要検討
- 検出コマンド `git rev-parse --git-dir` は `--git-dir` 環境変数がセットされていると挙動が変わる可能性がある（実運用では通常セットされないので許容）

## ログ

- 20260724 created（swc-voc-analyzer-v3 の worktree で PR #105 をマージした際に fatal 停止 → 手動リカバリした経験を元に起票）
- 20260724 done: `.claude/skills/pr-merge/SKILL.md` に worktree 対応を実装。Phase 4 を「マージ / リモート削除 / ローカル cleanup」の 3 段に構造分離
  - 経緯: プラン `issues-inbox-20260724-pr-merge-worktree-fizzy-heron` を作成、plan-reviewer と AskUserQuestion Q1〜Q9 で方針・実装粒度を確定。dotfiles 側の feat/pr-merge-worktree-split ブランチで 1 コミット（SKILL.md +52/-12 行）。ホーム側 `~/.claude/skills/pr-merge/SKILL.md` はスコープ外（ユーザーが別途手動反映）
  - 学び: (1) `gh pr merge --delete-branch` の暗黙 cleanup を分離することで、worktree 有無に依存しない構造にできる。ad-hoc な if 分岐より整合的。(2) SKILL.md 内で heredoc を使う場合、番号付きリスト内インデントに配置すると閉じ EOM が行頭にならず bash 構文エラーになる。見出しベース構造にして独立コードブロックで配置するのが安全
