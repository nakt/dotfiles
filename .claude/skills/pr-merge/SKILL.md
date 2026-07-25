---
name: pr-merge
description: >-
  フィーチャーブランチの変更をプッシュし、PR を作成・マージするスキル。
  ユーザーが「PRを作って」「プルリクエスト」「マージして」「PRお願い」「pr-merge」と言ったときに使用する。
  コミット済みの前提で動作する（未コミットなら /commit を案内）。
  PR 作成後、マージするか確認する。「ドラフトで」と指定された場合はマージしない。
disable-model-invocation: true
effort: low
allowed-tools:
  - Bash(git:*)
  - Bash(gh:*)
  - Bash(cat:*)
  - AskUserQuestion
---

# PR Merge

フィーチャーブランチから PR を作成し、オプションでマージまで行うスキル。

## Current state

- Branch: !`git branch --show-current`
- Uncommitted changes: !`git status --porcelain`
- Commits ahead of main: !`git log main..HEAD --oneline 2>/dev/null || true`
- Diff stats: !`git diff main..HEAD --stat 2>/dev/null || true`

## ワークフロー

### Phase 1: 事前チェック

上記の Current state を確認し、以下の条件に該当する場合は終了する:

- Branch が `main` の場合: 「`/commit` を先に実行するとブランチが自動作成されます」と案内
- Uncommitted changes がある場合: 「`/commit` を先に実行してください」と案内
- Commits ahead of main が空の場合: 「main に対する新しいコミットがありません」と報告
- 既存 PR を確認: `gh pr list --head {branch} --json number,url,title`
  - 既存 PR がある場合: PR 作成をスキップし、push のみ実行する旨を報告

### Phase 2: PR 情報の生成

上記の Commits ahead of main と Diff stats を分析して PR のタイトルと本文を自動生成する。タイトル形式・本文構成（Summary / Test plan / `Closes #123`）は git-workflow の「PR ガイドライン」に従う。

- タイトル: コミットメッセージから type を集約、scope はブランチ名や変更ファイルのディレクトリから推定、description はコミット群の要約（英語、簡潔に）
- 本文: 各コミットの要約から Summary を、変更に応じた Test plan を生成。ブランチ名やコミットメッセージに Issue 番号があれば `Closes #123` を付す
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

`git push origin --delete` が非ゼロ終了した場合は「リモート削除に失敗しました」と報告して Phase 4 を中止する。`git ls-remote` による確認はステップ 4 の子 worktree ケースで付加表示するのみ。

#### ステップ 4: ローカル cleanup

`git rev-parse --git-dir` の出力に `worktrees/` を含むかで子 worktree か親 worktree かを判定し、cleanup 手順を分岐する。以下の bash をそのまま実行する（`$branch` はステップ 3 の `{branch}` と同一値。ここで再取得しているのは bash ブロックを閉じた形にするため）:

```bash
branch=$(git branch --show-current)
parent_worktree=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')
current_worktree=$(git rev-parse --show-toplevel)

if git rev-parse --git-dir | grep -q 'worktrees/'; then
  # 子 worktree: リモート削除の付加確認 + cleanup 案内
  echo "リモート残存チェック（出力があれば削除失敗の可能性）:"
  git ls-remote --heads origin "$branch"
  cat <<EOM

ローカル cleanup は親 worktree 側で後日実行してください:

    cd $parent_worktree
    git worktree remove $current_worktree
    git branch -D $branch
    git fetch --prune
EOM
else
  # 親 worktree: 従来通り cleanup
  git checkout main
  git pull origin main
  git branch -d "$branch"
fi
```

#### ステップ 5: 完了報告

PR URL とマージ結果をユーザーに報告する。子 worktree の場合はステップ 4 で出力された cleanup 案内文を最終メッセージに含めて報告する。

## エラーハンドリング

| シナリオ | 対応 |
|---------|------|
| main ブランチ上 | `/commit` を先に案内して終了 |
| 未コミット変更あり | `/commit` を先に案内して終了 |
| push 失敗（コンフリクト） | `git pull --rebase origin {branch}` を案内 |
| マージコンフリクト | ローカル解決を案内して終了 |
| CI 失敗 | 報告して終了、修正後に `/pr-merge` を再実行 |
| 既存 PR あり | push のみ実行し、PR 作成スキップ |
| `fatal: 'X' is already used by worktree at ...` | 本設計では発生しない（`--delete-branch` を使わず、`git checkout <base>` を子 worktree では実行しないため）。旧手順を手動で試して発生した場合は、リモートを `git push origin --delete <branch>` で削除し、ローカルは親 worktree で cleanup する |

## Constraints

- main からは実行不可（フィーチャーブランチ必須）
- push・コミットの禁止事項（`--force` / `--no-verify` 等）は git-workflow に従う
- マージ方式は `--merge`（merge commit）固定
- マージ後のリモート削除・ローカル cleanup は `gh pr merge --delete-branch` に委ねず、明示的に分離して実行する（`--delete-branch` が内部で走らせる `git checkout <base>` が worktree 環境で fatal 停止するのを回避するため）
- 前提として、親 worktree が base ブランチ（通常 main）を checkout している標準配置を想定する。逆パターン（親が feature ブランチを持ち、子が base ブランチを持つ配置）は想定外
- マージ前にユーザーに確認を取る（ドラフト PR の場合はスキップ）
- ユーザーへの確認は `AskUserQuestion` ツールを使用する（PR タイトル/本文の承認、CI 待機の判断、マージ可否など）
- コミットログ・PR タイトルは英語
- その他の会話は日本語
