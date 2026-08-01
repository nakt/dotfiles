---
name: pr-merge
description: >-
  フィーチャーブランチの変更をプッシュし、PR を作成・マージするスキル。
  コミット済みの前提で動作する（未コミットなら /commit を案内）。
  PR 作成後、マージするか確認する。「ドラフトで」と指定された場合はマージしない。
disable-model-invocation: true
effort: low
allowed-tools:
  - Bash(git:*)
  - Bash(gh:*)
  - Bash(cat:*)
  - Bash(awk:*)
  - Bash(sed:*)
  - Bash(grep:*)
  - Bash(head:*)
  - Bash(echo:*)
  - AskUserQuestion
---

# PR Merge

フィーチャーブランチから PR を作成し、オプションでマージまで行うスキル。

## Current state

base ブランチは `origin/HEAD` から解決する (取得できなければ `main` / `master` の存在で決める)。各行は独立に解決するため、base 相対の比較は解決済みの名前ではなく `origin/HEAD` を直接使い、それが未設定のときだけ `main` / `master` へフォールバックする。

- Branch: !`git branch --show-current | grep . || echo '(detached HEAD)'`
- Base branch: !`git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' | grep . || git branch --list --format='%(refname:short)' main master | head -1`
- Uncommitted changes: !`git status --porcelain`
- Commits ahead of base: !`git log --oneline origin/HEAD..HEAD 2>/dev/null || git log --oneline main..HEAD 2>/dev/null || git log --oneline master..HEAD 2>/dev/null || echo '(base unresolved)'`
- Diff stats: !`git diff origin/HEAD..HEAD --stat 2>/dev/null || git diff main..HEAD --stat 2>/dev/null || git diff master..HEAD --stat 2>/dev/null || echo '(base unresolved)'`

## ワークフロー

### Phase 1: 事前チェック

上記の Current state を確認し、以下の条件に該当する場合は終了する:

- Branch が Base branch と同じ場合: 「`/commit` を先に実行してください。未コミットの変更があればコミットし、base 上にコミットが積まれているだけなら、確認のうえフィーチャーブランチへ移します」と案内
- Uncommitted changes がある場合: 「`/commit` を先に実行してください」と案内
- Commits ahead of base が空の場合: 「base ブランチに対する新しいコミットがありません」と報告
- 既存 PR を確認: `gh pr list --head {branch} --json number,url,title`
  - 既存 PR がある場合: PR 作成をスキップし、push のみ実行する旨を報告

### Phase 2: PR 情報の生成

既存 PR がある場合はこの Phase を丸ごとスキップして Phase 3 の push へ進む (生成したタイトル・本文は Phase 3 で使われないため)。

上記の Commits ahead of base と Diff stats を分析して PR のタイトルと本文を自動生成する。

- タイトルの type はコミットメッセージから集約し、scope はブランチ名や変更ファイルのディレクトリから推定する
- 本文の Summary は各コミットの要約をベースに箇条書きする
- ブランチ名やコミットメッセージに Issue 番号が含まれていれば関連 Issue を本文に記載する
- `AskUserQuestion` でタイトル/本文の承認を求める（選択肢例:「この内容で進める」「修正する」）。「修正する」が選ばれた場合はユーザーの指示に従って再生成する

### Phase 3: Push + PR 作成

```bash
git push -u origin {branch}
```

既存 PR がない場合のみ PR を作成:

```bash
gh pr create --title "{title}" --body-file <(cat <<'EOF'
{body}
EOF
)
```

- 「ドラフトで」と指定された場合は `--draft` を追加
- 既存 PR がある場合は push のみ実行（追加コミットの反映）
- 作成した PR の URL をユーザーに報告

### Phase 4: マージ

ドラフト PR の場合はこの Phase をスキップする。Phase 4 の設計原則として、マージ・リモート削除・ローカル cleanup を分離する（`gh pr merge --delete-branch` は使わない。内部で走る `git checkout <base>` が worktree 環境で fatal 停止するため）。

#### ステップ 1: マージ可否確認

`AskUserQuestion` で「マージする／マージしない」を選んでもらう。

#### ステップ 2: CI ステータス確認

`gh pr checks {pr-number}` を実行し、以下で分岐する:

- CI が存在しない場合: スキップして次へ
- CI 実行中の場合: ステータスを報告し、`AskUserQuestion` で「完了を待つ／そのままマージ／中止」を選んでもらう
- CI 失敗の場合: 失敗内容を報告して終了。修正後に再度 `/pr-merge` を案内

#### ステップ 3: マージ + リモート削除

以下 2 コマンドを順に実行する:

```bash
gh pr merge {pr-number} --merge
git push origin --delete {branch}
```

`git push origin --delete` が非ゼロ終了した場合は「リモート削除に失敗しました」と報告して Phase 4 を中止する。

#### ステップ 4: ローカル cleanup

`git rev-parse --git-dir` の出力に `worktrees/` を含むかで子 worktree か親 worktree かを判定し、cleanup 手順を分岐する。親 worktree が base ブランチを checkout している標準配置を前提とする（親が feature ブランチ、子が base ブランチという逆パターンは想定外）。以下の bash をそのまま実行する（`$branch` はステップ 3 の `{branch}` と同一値。ここで再取得しているのは bash ブロックを閉じた形にするため）:

```bash
branch=$(git branch --show-current)
base=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); base=${base#origin/}
base=${base:-$(git rev-parse --verify -q main >/dev/null 2>&1 && echo main || echo master)}
parent_worktree=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')
current_worktree=$(git rev-parse --show-toplevel)

if git rev-parse --git-dir | grep -q 'worktrees/'; then
  # 子 worktree: cleanup 案内のみ（リモート削除はステップ 3 で成否を確認済み）
  cat <<EOM

ローカル cleanup は親 worktree 側で後日実行してください:

    cd $parent_worktree
    git worktree remove $current_worktree
    git branch -D $branch
    git fetch --prune
EOM
else
  # 親 worktree: 従来通り cleanup
  git checkout "$base"
  git pull origin "$base"
  git branch -d "$branch"
fi
```

#### ステップ 5: 完了報告

PR URL とマージ結果をユーザーに報告する。子 worktree の場合はステップ 4 で出力された cleanup 案内文を最終メッセージに含めて報告する。

## エラーハンドリング

Phase 1（base ブランチ上／未コミット変更あり／既存 PR あり）と Phase 4・ステップ 2（CI 失敗）で判定済みのシナリオは各 Phase の記述を参照。ここでは Phase の手順に明記のない復旧手順のみを扱う。

| シナリオ | 対応 |
|---------|------|
| push 失敗（コンフリクト） | `git pull --rebase origin {branch}` を案内 |
| マージコンフリクト | ローカル解決を案内して終了 |
