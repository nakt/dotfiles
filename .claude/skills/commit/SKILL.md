---
name: commit
description: 未コミットの変更を分析し、論理的なグループに分類して適切な粒度でコミットするスキル。
disable-model-invocation: true
effort: low
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git checkout:*), Bash(git branch:*), Bash(git diff:*), Bash(git log:*), Bash(git symbolic-ref:*), Bash(git rev-parse:*), Bash(pre-commit:*), Bash(uv:*), Bash(grep:*), Bash(echo:*), Bash(test:*)
---

# Git Commit

未コミットのファイルを分析し、論理的に関連する変更を適切な粒度でコミットする。

## Current state

base ブランチは `origin/HEAD` から解決する（取得できなければ `main` / `master` の存在で決める）。

- Branch: !`git branch --show-current`
- Base branch: !`b=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); b=${b#origin/}; echo "${b:-$(git rev-parse --verify -q main >/dev/null 2>&1 && echo main || echo master)}"`
- Status: !`git status --short`
- Diff summary: !`git diff HEAD --stat 2>/dev/null || echo '(no commits yet)'`
- Recent commits: !`git log --oneline -10 2>/dev/null || echo '(no commits yet)'`

## タスク

1. 上記の Current state を確認し、必要な作業をリストアップする
2. 初回コミットの処理（HEAD が未確立の場合）
   - Recent commits が `(no commits yet)` の場合:
     a. このリポジトリの最初のコミットである。ブランチ推定はスキップする（現在のブランチのまま作業する）
     b. `git status --short`（上記 Status）がこの状態で得られる唯一の一覧であり、Diff summary / Recent commits はプレースホルダーである。そこに表示された未追跡ファイルの一覧を確認し、該当するファイルを `git add` でステージする
     c. ルートコミットを作成する（通常は `chore: initial commit` などとする）
     d. その後 Step 6（`pre-commit フックの更新確認`）に進み、Step 3-5（ブランチ推定・分類・通常のコミット粒度）はスキップする
   - それ以外の場合: Step 3 に進む
3. フィーチャーブランチを確保する
   - Branch が Base branch と同じ場合: フィーチャーブランチを作成する。名前は上記の Status と Diff summary から推定し、作成後にブランチ名をユーザーに報告する
   - それ以外の場合: 何もせず進む
4. 変更を論理的なグループに分類する
5. 適切な粒度でコミットする
   - 何を変更したかではなく、なぜ変更したかを説明する
6. pre-commit フックの更新を確認する（`test -f .pre-commit-config.yaml` などでプロジェクトルートに `.pre-commit-config.yaml` が存在するか確認し、存在する場合のみ）
   - `pre-commit autoupdate` を実行する。ただし `test -f uv.lock` または `grep -q "^\[tool.uv" pyproject.toml` が真なら uv 管理リポなので `uv run pre-commit autoupdate` を実行する
   - 設定が更新された場合は、その変更を別コミットとして記録する:
     `git add .pre-commit-config.yaml && git commit -m "chore: update pre-commit hooks"`
   - 更新がなければ何も報告せずスキップする
