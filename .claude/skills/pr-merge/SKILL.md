---
name: pr-merge
description: >-
  フィーチャーブランチの変更をプッシュし、PR を作成・マージするスキル。
  ユーザーが「PRを作って」「プルリクエスト」「マージして」「PRお願い」「pr-merge」と言ったときに使用する。
  コミット済みの前提で動作する（未コミットなら /commit を案内）。
  マージはオプションで、ユーザーが求めた場合のみ実行する。
allowed-tools:
  - Bash(git:*)
  - Bash(gh:*)
---

フィーチャーブランチから PR を作成し、オプションでマージまで行うスキル。

## Current state

- Branch: !`git branch --show-current`
- Uncommitted changes: !`git status --porcelain`
- Commits ahead of main: !`git log main..HEAD --oneline 2>/dev/null`
- Diff stats: !`git diff main..HEAD --stat 2>/dev/null`
- Existing PR: !`gh pr list --head $(git branch --show-current) --json number,url,title 2>/dev/null`

## ワークフロー

### Phase 1: 事前チェック

上記の Current state を確認し、以下の条件に該当する場合は終了する:

- Branch が `main` の場合: 「`/commit` を先に実行するとブランチが自動作成されます」と案内
- Uncommitted changes がある場合: 「`/commit` を先に実行してください」と案内
- Commits ahead of main が空の場合: 「main に対する新しいコミットがありません」と報告
- Existing PR にエントリがある場合: PR 作成をスキップし、push のみ実行する旨を報告

### Phase 2: PR 情報の生成

上記の Commits ahead of main と Diff stats を分析して PR のタイトルと本文を自動生成する。

タイトル: `type(scope): description` 形式

- コミットメッセージから type を集約
- scope はブランチ名や変更ファイルのディレクトリから推定
- description はコミット群の要約（英語、簡潔に）

本文:

```markdown
## Summary

- 変更内容の箇条書き（各コミットの要約ベース）

## Test plan

- テスト方法の記述
```

- ブランチ名やコミットメッセージに Issue 番号が含まれていれば `Closes #123` を追加
- ユーザーにタイトルと本文を提示して確認を取る

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

### Phase 4: マージ（オプション）

ユーザーが明示的に求めた場合のみ実行する。PR 作成がこのスキルのデフォルトのゴール。

1. CI ステータスを確認: `gh pr checks {pr-number}`
   - CI が存在しない場合: スキップしてマージへ
   - CI 実行中の場合: ステータスを報告し、待つか進むかユーザーに確認
   - CI 失敗の場合: 失敗内容を報告して終了。修正後に再度 `/pr-merge` を案内
1. マージ実行:

```bash
gh pr merge {pr-number} --merge --delete-branch
```

1. マージ後クリーンアップ:

```bash
git checkout main
git pull origin main
git branch -d {branch}
```

1. 完了報告: PR URL とマージ結果をユーザーに報告

## エラーハンドリング

| シナリオ | 対応 |
|---------|------|
| main ブランチ上 | `/commit` を先に案内して終了 |
| 未コミット変更あり | `/commit` を先に案内して終了 |
| push 失敗（コンフリクト） | `git pull --rebase origin {branch}` を案内 |
| マージコンフリクト | ローカル解決を案内して終了 |
| CI 失敗 | 報告して終了、修正後に `/pr-merge` を再実行 |
| 既存 PR あり | push のみ実行し、PR 作成スキップ |

## Constraints

- main からは実行不可（フィーチャーブランチ必須）
- `--force` push は使用しない
- `--no-verify` は使用しない
- マージ方式は `--merge`（merge commit）固定
- マージはユーザーが求めた場合のみ実行
- コミットログ・PR タイトルは英語
- その他の会話は日本語
