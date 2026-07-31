---
name: finish-branch
description: >-
  実装完了後の後片付け(検証 → 統合方法の選択 → ブランチ整理)を行うスキル。
  ユーザーが「作業を締めて」「ブランチを仕上げて」「PR にして」「finish-branch」と言ったときに使用する。
  実装完了時の入口として、テスト・lint の検証結果を提示したうえで PR 作成 / 保留 / 破棄を選んでもらう。
  コミットの作成は commit スキル、作成済み PR のマージは pr-merge スキルに委ねる(本スキルはどちらも行わない)。
  手動 `/finish-branch` でも呼べる。
disable-model-invocation: true
effort: low
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(git:*)
  - Bash(gh:*)
  - Bash(ls:*)
  - AskUserQuestion
  - ExitWorktree
---

# Finish Branch

実装が完了したフィーチャーブランチの後片付けを行う。検証 → 統合方法の選択 → 選択に応じた実行、の順に進める。

## Current state

- Branch: !`git branch --show-current`
- Uncommitted changes: !`git status --porcelain`
- Commits ahead of main: !`git log main..HEAD --oneline 2>/dev/null || true`
- Worktree: !`git rev-parse --git-dir 2>/dev/null | grep -q 'worktrees/' && echo '子 worktree' || echo '通常'`
- Project files: !`ls package.json Makefile pyproject.toml Cargo.toml go.mod 2>/dev/null || true`

## ワークフロー

### Phase 1: 事前チェック

Branch が `main` の場合、後片付け対象のフィーチャーブランチがない旨を報告して終了する。

### Phase 2: 検証

上記 Project files やリポジトリの慣例(package.json の scripts、Makefile のターゲット、CI 設定など)からテスト・lint の実行方法を判断する。ルート直下に見つからない場合は Glob でも探索し、見つかった設定ファイルは Read で内容を確認する。

- 実行方法が見つかれば実行し、結果(成功/失敗と出力の要点)を提示する
- 見つからなければその旨を提示して次に進む
- 失敗していても処理をブロックしない。失敗している旨を明確に伝えたうえで Phase 3 に進み、続行するかどうかの判断はユーザーに委ねる
- 検証コマンドの実行時は権限確認が出ることがある。権限の拒否を検証失敗と誤認しない

### Phase 3: 統合方法の選択

`AskUserQuestion` で以下の3択を提示する。

- PR 作成: 変更を PR にして提出する
- 保留: 今は何もしない。あとで対応する
- 破棄: ブランチと変更を破棄する

選択肢はこの3つに限定する。ローカルでベースブランチへ直接マージする選択肢は提供しない(`.claude/rules/git-workflow.md` の PR 必須規律に従う)。

### Phase 4: 選択に応じた実行

#### PR 作成を選んだ場合

1. Uncommitted changes がある場合は commit スキル(`/commit`)の実行を案内して終了する。本スキルはコミットを作成しない。
2. 既存 PR を確認する: `gh pr list --head {branch} --json number,url,title`
   - 既存 PR があれば作成をスキップし、その URL を報告して終了する。マージは pr-merge スキル(`/pr-merge`)に委ねる。
3. `.claude/rules/git-workflow.md` の PR ガイドラインに従い、コミット履歴と diff からタイトル(`type(scope): description` 形式)と本文(Summary / Test plan / 関連 Issue)を生成する。
4. `AskUserQuestion` でタイトル・本文の承認を求める。
5. 承認後、以下を実行する。

   ```bash
   git push -u origin {branch}
   gh pr create --title "{title}" --body-file <(cat <<'EOF'
   {body}
   EOF
   )
   ```

6. 作成した PR の URL を報告する。マージが必要な場合は pr-merge スキル(`/pr-merge`)を案内する(本スキルはマージを行わない)。

#### 保留を選んだ場合

何も実行しない。ブランチと変更をそのまま残す旨を報告して終了する。

#### 破棄を選んだ場合

1. 破棄対象(ブランチ名、未コミット変更の有無、コミット数、worktree かどうか)と、未コミット変更を含めて復元不可であることを提示し、`AskUserQuestion` で最終確認を取る(選択肢例:「破棄を実行する」「中止する」)。中止が選ばれたら何もせず終了する。
2. 子 worktree の場合: `ExitWorktree` を `action: "remove"`, `discard_changes: true` で呼ぶ。
   ExitWorktree は同一セッションの `EnterWorktree` で作成した worktree のみを対象とし、
   それ以外では何もせず終了する(no-op)。no-op が返った場合は成功として報告せず、
   親 worktree 側での cleanup 手順を案内して終了する。

   ```bash
   parent_worktree=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')
   current_worktree=$(git rev-parse --show-toplevel)
   branch=$(git branch --show-current)
   cat <<EOM
   ローカル cleanup は親 worktree 側で実行してください:

       cd $parent_worktree
       git worktree remove --force $current_worktree
       git branch -D $branch
   EOM
   ```

3. 子 worktree でない場合: ステップ1の明示確認を経てからのみ以下を実行する。未コミット変更があれば先に破棄し、そのあと main へ切り替えてフィーチャーブランチを削除する。

   ```bash
   git reset --hard   # 未コミット変更がある場合のみ
   git clean -fd      # 未追跡ファイルがある場合のみ
   git checkout main
   git branch -D {branch}
   ```

## エラーハンドリング

| シナリオ | 対応 |
|---------|------|
| main ブランチ上で実行 | 後片付け対象がない旨を報告して終了 |
| PR 作成時に未コミット変更あり | commit スキルを案内して終了 |
| PR 作成時に既存 PR あり | 作成をスキップし URL を報告 |
| push 失敗(コンフリクト) | `git pull --rebase origin {branch}` を案内 |
| 破棄の最終確認で中止を選択 | 何もせず終了 |

## Constraints

- ローカルでベースブランチへ直接マージする選択肢は提供しない(PR 必須。`.claude/rules/git-workflow.md`)
- 破棄はユーザーの明示確認を経てからのみ実行する
- `--force` push、`--no-verify`、確認なしの `reset --hard` は使用しない(`.claude/rules/git-workflow.md` 禁止事項)
- コミットの作成は行わない(commit スキルに委ねる)
- PR のマージは行わない(pr-merge スキルに委ねる)
- 前提として、親 worktree が base ブランチ(通常 main)を checkout している標準配置を想定する(pr-merge スキルと同じ前提)
- コミットログ・PR タイトルは英語、その他の会話は日本語
