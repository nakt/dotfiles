---
name: release-hotfix
description: >-
  デフォルトブランチが develop のリポジトリ (Git Flow) で、本番の版だけを直す hotfix、
  本番ブランチから develop への back-merge、develop から本番ブランチへのリリースを手作業の手順で進めるスキル。
  引数 hotfix / backmerge / release で場面を選ぶ。
  手動起動をユーザーの要求とみなし、back-merge のコミット、タグ作成、push、リリース PR のマージを行う。
  GitHub Flow のリポジトリ (デフォルトブランチが develop 以外) は対象外。
argument-hint: "[hotfix|backmerge|release]"
disable-model-invocation: true
allowed-tools:
  - Bash(git:*)
  - Bash(gh:*)
  - Bash(grep:*)
  - Bash(cat:*)
  - Bash(awk:*)
  - Bash(head:*)
  - Bash(echo:*)
  - Bash(uv run --script ~/.claude/skills/issue-tracker/scripts/it.py:*)
  - AskUserQuestion
  - EnterWorktree
  - ExitWorktree
---

# Release Hotfix

デフォルトブランチが `develop` のリポジトリ (Git Flow) で、hotfix・back-merge・リリースを手作業の手順として進めるスキル。
スクリプトは持たず、この手順を上から順に辿る。

このスキルはユーザーが `/release-hotfix` を手動で起動したときだけ動く。
起動をコミット・タグ作成・push・マージの要求とみなし、手順内のこれらを実行する。
ただし、タグ打ち・push・マージの前には、必ず何を実行するかを示してユーザーの承認を得る (`AskUserQuestion`)。

## 場面

| 引数 | 場面 | 行うこと |
| ---- | ---- | -------- |
| `hotfix` | 本番の版だけを直す | 本番ブランチを起点にした hotfix 用 worktree の作成まで |
| `backmerge` | hotfix のマージ後 | 本番ブランチへのパッチ版タグと、develop への back-merge 用 worktree の作成 |
| `release` | develop の変更を本番に出す | develop → 本番ブランチのマージとタグ |

引数が無い、または上記以外のときは、`AskUserQuestion` で場面 (`hotfix` / `backmerge` / `release`) を尋ねる。

## 共通: Git Flow の判定

どの場面でも、最初に次を実行して判定する。

```bash
git remote set-head origin -a
git fetch origin
default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); default=${default#origin/}
echo "default=$default"
git branch -r --list origin/main origin/master --format='%(refname:short)'
```

`origin/HEAD` はクローン時の値のキャッシュで、リモートのデフォルトを変えても自動では更新されない。
`set-head` と `fetch` で、`origin/HEAD` と各ブランチの参照をリモートの最新の値にそろえてから判定する。

- `default` が `develop` でない場合: GitHub Flow のリポジトリである。「このリポジトリは Git Flow (デフォルトブランチが develop) ではないため、`/release-hotfix` の対象外です」と伝えて終了する
- 本番ブランチを決める: `origin/main` があれば `main`、無ければ `master`。どちらも無い場合は「本番ブランチ (main / master) が無いため対象外です」と伝えて終了する。以降この名前を `<prod>` と書く
- 本番ブランチの先端 (`origin/<prod>`) は、常に本番で稼働している版であることを前提とする
- GitHub 側で、`<prod>` と develop の PR に merge commit でのマージが許可されていることを前提とする
- 本番ブランチと develop にはレビューの承認が必須な場合がある。承認待ちでマージできないときの扱いは「レビュー待ちで止まったとき」を参照する

以降の手順で `main` の作業ツリーと書く箇所は、主チェックアウト (最初の worktree) を指す。
主チェックアウトのパスは次で得る。

```bash
git worktree list --porcelain | awk 'NR==1{print $2}'
```

Bash の cwd は毎回プロジェクトディレクトリに戻るため、worktree での作業は `EnterWorktree` で入ってから行い、他の場所のコマンドは `git -C <パス>` で実行する。

## 共通: タグの形式と版番号

タグの形式は、既存のタグに合わせる。

```bash
git tag --sort=-v:refname | head -10
```

- 最新のタグが本番にデプロイ済みとは限らないため、本番に出ているタグはユーザーに確認する (`AskUserQuestion`。候補に最新のタグ数件を挙げ、「その他」で自由入力を受ける)
- 既存のタグが無いとき、およびリリースの版番号は、ユーザーに確認して決める
- パッチ版は、本番に出ているタグのパッチ番号を 1 上げる (例: 本番が `v1.4.2` なら `v1.4.3`)。`v` の有無などの形式は既存のタグに合わせる
- タグは注釈なしの git タグだけを作る。GitHub Release は作らない
- `package.json` や `pyproject.toml` などのバージョンファイルは更新しない (この手順の対象外)

## 共通: レビュー待ちで止まったとき

本番ブランチと develop の PR はレビューの承認が必須な場合がある。
`gh pr merge` が承認待ちで失敗したときは、先へ進まずに止める。
PR の URL を示し、「レビューの承認後に、同じ場面で `/release-hotfix <場面>` を再実行してください」と案内して終了する。
この再実行の案内は `release` の場面だけに当てはまる。
`hotfix` と `backmerge` の場面のマージは `/pr-merge` が行うので、承認後は `/release-hotfix` ではなく `/pr-merge` を再実行する。
`--admin` や `--auto` は使わない。

再実行したときは、各場面の「済んだ段階の検出」に従って、PR 作成済み・マージ済み・タグ作成済みの段階を飛ばして続きから進める。

## hotfix

本番ブランチを起点にした hotfix 用 worktree を作り、そこで修正する準備までを行う。
EnterWorktree は起点を指定できず、既定ではデフォルトブランチ (develop) から作るため、この場面だけは `git worktree add` で作った worktree に `EnterWorktree(path)` で入る。

### 済んだ段階の検出

最初に次を確認し、既存の hotfix 用 worktree があれば済んだ段階を飛ばす。
issue の claim より前に行う。

```bash
git fetch origin
git worktree list --porcelain
git branch --list 'worktree-hotfix+*'
```

- `branch refs/heads/worktree-hotfix+<desc>` の worktree がある: `AskUserQuestion` で、既存の worktree (`<desc>` ごとに 1 つ) と「新しい hotfix を始める」を選択肢に出す
- 既存の worktree が選ばれた: その `<desc>` を使う。手順 1 の 2 (claim) を行ってから、手順 2 を飛ばして `EnterWorktree(path: "<main-root>/.claude/worktrees/hotfix+<desc>")` で入る。次に `git log --oneline origin/<prod>..HEAD` を実行し、出力があれば手順 3 へ進む。出力が無ければ `gh pr list --head worktree-hotfix+<desc> --base <prod> --state merged --json number,url` を実行し、マージ済みの PR があれば「hotfix の次」へ、無ければ (まだコミットが無い) 手順 3 へ進む
- worktree は無いが `worktree-hotfix+<desc>` のブランチだけがある: 手順 1 の 2 (claim) を行ってから、手順 2 で `-b` と起点を付けずに既存のブランチで worktree を作る (`git -C <main-root> worktree add <main-root>/.claude/worktrees/hotfix+<desc> worktree-hotfix+<desc>`)
- どちらも無い、または「新しい hotfix を始める」が選ばれた: 手順 1 から進む

### hotfix 手順 1: 名前の決定と issue の claim

1. 新しく始める場合は、`AskUserQuestion` で hotfix の短い説明 `<desc>` (英小文字とハイフン。例: `fix-login-timeout`) を尋ねる。worktree は `.claude/worktrees/hotfix+<desc>`、ブランチは `worktree-hotfix+<desc>` になる
2. 対象の issue がある場合は、主チェックアウトで claim する。owner は `hotfix/<desc>` にする。EnterWorktree(name) が作る名前の形式と、issue の claim の owner 名をそろえるため

   ```bash
   uv run --script ~/.claude/skills/issue-tracker/scripts/it.py claim --id <id> --agent hotfix/<desc>
   ```

   claim の前に `grep -l '^owner: hotfix/<desc>$' <main-root>/issues/wip/*.md` を実行する。対象の issue が既に wip で owner が `hotfix/<desc>` なら (再実行)、claim を飛ばす

   claim は主チェックアウトで行う。`git rev-parse --git-dir` が `worktrees/` を含む worktree にいる場合は、先に `ExitWorktree(action: "keep")` で主チェックアウトに戻る (戻れない場合は、主チェックアウトでこの場面を起動し直すよう案内して終了する)

### hotfix 手順 2: worktree の作成

次を実行する (`<main-root>` は主チェックアウトのパス)。
`--no-track` を付けて、本番ブランチを upstream にしない。

```bash
git -C <main-root> worktree add --no-track -b worktree-hotfix+<desc> <main-root>/.claude/worktrees/hotfix+<desc> origin/<prod>
```

作成後、`EnterWorktree(path: "<main-root>/.claude/worktrees/hotfix+<desc>")` で入る。
`path` で入った worktree は ExitWorktree で削除されず、`action: "keep"` で元のディレクトリに戻る。

### hotfix 手順 3: 修正と PR

- 以降の修正は、この worktree の中で行う
- この worktree では `it done` を実行しない。hotfix の worktree は本番ブランチから作られ、develop にしか無い issue ファイルが無いため、ここで done にすると back-merge で `open` と `done` が二重になる。done 化は back-merge の手順で行う (`/execute-plan` も `worktree-hotfix+` のブランチでは done 化を見送る)
- コミット、push、PR 作成、マージは通常どおり `/commit` → `/pr-merge` で行う。`/pr-merge` はブランチ名が `worktree-hotfix+` で始まるとき、base を本番ブランチにして PR を作る
- hotfix の worktree は back-merge が develop に入るまで `cleanup-worktrees.sh` に残される。手で削除しない

### hotfix の次

hotfix を本番ブランチへマージしたら (レビュー待ちなら承認後に `/pr-merge` を再実行)、同じセッションのまま `/release-hotfix backmerge` を起動する。
修正が本番へデプロイされた後、タグの版番号は backmerge で決める。

## backmerge

本番ブランチに入った hotfix を、パッチ版のタグを打ったうえで develop に戻す。
`origin/develop..origin/<prod>` に含まれる hotfix は、複数あってもすべてまとめて扱い、パッチ版タグは本番ブランチの先端に 1 本だけ打つ。

### 済んだ段階の検出

最初に次を確認し、済んだ段階を飛ばす。
下の項目を上から順に判定し、最初に当てはまったものに従う。
3 番目の項目の判定で、`worktree-backmerge+*` の worktree はあるがその `<tag>` が先端のタグに含まれない (以前の back-merge の worktree が残っている) と分かった場合は、その項目には当てはめず `AskUserQuestion` で「残したまま次の項目から判定を続ける / 中止する」を尋ね、「続ける」が選ばれたら後続の項目 (先端にタグがあり push 済み → 先端にタグがあるが push 失敗 → いずれにも当てはまらない → 手順 1) の順に判定を続ける。

```bash
git fetch origin
git log --no-merges --oneline origin/develop..origin/<prod>
git tag --points-at origin/<prod>
git ls-remote --tags origin
git worktree list --porcelain
gh pr list --base develop --state open --json number,url,headRefName
```

- `origin/develop..origin/<prod>` が空: back-merge 待ちの hotfix が無い (未着手、またはマージ済み)。「back-merge の対象はありません」と報告して終了する
- `headRefName` が `worktree-backmerge+` で始まる open な PR がある: back-merge の PR は作成済み。その worktree (`<main-root>/.claude/worktrees/backmerge+<tag>`) に `EnterWorktree(path)` で入り、「backmerge の次」に進む
- `branch refs/heads/worktree-backmerge+<tag>` の worktree があり、その `<tag>` が `git tag --points-at origin/<prod>` の出力に含まれる (PR は未作成): 手順 1 と手順 2 は済んでいる。`<tag>` はブランチ名の `worktree-backmerge+` に続く部分を使い、該当する worktree が複数あるときは先端のタグと一致する `<tag>` の worktree を採る。手順 2 を飛ばして `EnterWorktree(path: "<main-root>/.claude/worktrees/backmerge+<tag>")` で入り、次で続きを決める
  - `git merge-base --is-ancestor origin/<prod> HEAD` が失敗する: 手順 3 から進む
  - 成功する: 手順 3 は済んでいる。`git log --oneline origin/develop..HEAD` に `chore(issues): close` のコミットが無ければ手順 4 を行い、あれば飛ばす。その後「backmerge の次」に進む
- 本番ブランチの先端 (`origin/<prod>`) にタグが付き、`git ls-remote --tags origin` にそのタグがある: タグ打ちは済んでいる。先端のタグを `<tag>` として使い、手順 1 を飛ばして手順 2 に進む。ただし先端のタグがリリースのタグではなくパッチ版であることを、`git log` の内容とあわせてユーザーに確認する
- 本番ブランチの先端にタグが付いているが、`git ls-remote --tags origin` にそのタグが無い: タグの作成後に push が失敗している。先端のタグを `<tag>` として使い、タグは作り直さない。`git push origin <tag>` を実行する、と示して `AskUserQuestion` で承認を得てから実行し、手順 2 に進む
- いずれにも当てはまらない: 手順 1 から進む

### backmerge 手順 1: 本番ブランチへのパッチ版タグ

1. `git log --no-merges --oneline origin/develop..origin/<prod>` の出力を示し、back-merge 対象の hotfix をユーザーに見せる
2. 「共通: タグの形式と版番号」に従って、本番に出ているタグを確認し、パッチ版のタグ `<tag>` を決める
3. 次のコマンドを実行する、と示して `AskUserQuestion` で承認を得る

   ```bash
   git tag <tag> origin/<prod>
   git push origin <tag>
   ```

4. 承認されたら実行し、`git tag --points-at origin/<prod>` で本番ブランチの先端にタグが付いたことを確認する

### backmerge 手順 2: back-merge 用 worktree の作成

1. 主チェックアウトにいない場合 (`git rev-parse --git-dir` が `worktrees/` を含む場合) は、先に `ExitWorktree(action: "keep")` で主チェックアウトに戻る。worktree の中から別の新規 worktree を `name` で作ることはできないため。ExitWorktree は、このセッションが EnterWorktree で入った worktree でなければ何もしない。戻れない場合は、主チェックアウトでこの場面を起動し直すよう案内して終了する
2. `EnterWorktree(name: "backmerge/<tag>")` で worktree に入る。ブランチは `worktree-backmerge+<tag>` になり、起点はリモートのデフォルトブランチ (develop) になる
3. `git rev-parse HEAD origin/develop` で、起点が `origin/develop` の先端であることを確認する。異なる場合は理由を報告して止まる

### backmerge 手順 3: 本番ブランチのマージ

1. 次を実行する (`--no-ff` で merge commit を残す)

   ```bash
   git merge --no-ff origin/<prod> -m "chore: back-merge <prod> (<tag>) into develop"
   ```

2. コンフリクトした場合は、この worktree で解消する。`git status` で対象を確認し、hotfix の修正と develop の変更の双方の意図を残すように編集して `git add` し、`git commit` でマージを完了する。解消の判断に迷う箇所はユーザーに確認する
3. `git log --oneline origin/develop..HEAD` で back-merge の内容を確認する

### backmerge 手順 4: issue の done 化

hotfix で claim した issue がある場合は、この worktree で done にする。
done の差分は back-merge と同じ PR に含める。

1. 主チェックアウト側で対象の issue を探す。`issues/` を git 管理するリポジトリでは、この worktree の `issues/` に主チェックアウトでの未コミットの claim (wip) が含まれないため、`<main-root>` (「共通: Git Flow の判定」の `git worktree list --porcelain | awk` で得たパス) に対して実行する

   ```bash
   grep -l '^owner: hotfix/' <main-root>/issues/wip/*.md
   ```

2. 見つかった場合は、対象の issue をユーザーに確認する (`AskUserQuestion`)。見つからない場合も黙って飛ばさず、`AskUserQuestion` で done にする issue の id を尋ねる (選択肢に「done 化は不要」を含め、選ばれたらこの手順を飛ばす)
3. issue ごとに、この worktree で次を実行する

   ```bash
   uv run --script ~/.claude/skills/issue-tracker/scripts/it.py done <id> --note <<'EOF'
   <採用した結論を 1 行。hotfix の内容とタグ <tag>>
   EOF
   ```

4. `git status --porcelain issues/` を確認する。変更があれば `git add -A issues/` でステージし、`chore(issues): close <id>` でコミットする。変更が無ければ (`issues/` を gitignore しているリポジトリ) コミットしない

### backmerge の次

次の手順を案内して、この場面を終える。

- この worktree で `/pr-merge` を実行する。base は develop になり、back-merge の PR が作成・マージされる (レビュー待ちなら承認後に `/pr-merge` を再実行)
- マージ後の worktree の後片付けは `/pr-merge` が行う。hotfix の worktree は、back-merge が develop に入った後の `cleanup-worktrees.sh` で削除される。手で削除しない

## release

develop → 本番ブランチを merge commit でマージし、本番ブランチにタグを打つ。
develop を head にした PR は `/pr-merge` の Phase 1 で「Branch が Base と同じ」と判定されて止まり、またマージ後に head ブランチを削除するため、`/pr-merge` は使わず、この場面の中で `gh pr create` と `gh pr merge --merge` を実行する。
worktree は使わない。develop と本番ブランチの間のマージで squash は使わない (同じ変更が別コミットとして両ブランチに残り、次のマージで重複やコンフリクトを生むため)。

### 済んだ段階の検出

最初に次を確認し、済んだ段階を飛ばす。

```bash
git fetch origin
git log --no-merges --oneline origin/develop..origin/<prod>
git log --oneline origin/<prod>..origin/develop
git tag --points-at origin/<prod>
git ls-remote --tags origin
gh pr list --head develop --base <prod> --state open --json number,url
```

- `origin/develop..origin/<prod>` が空でない: back-merge 待ちの hotfix がある。リリースすると hotfix の修正が本番から消えるかコンフリクトするため、「先に `/release-hotfix backmerge` を実行してください」と案内して終了する
- `origin/<prod>..origin/develop` が空で、本番ブランチの先端にタグが付き、`git ls-remote --tags origin` にそのタグがある: リリース済み。「リリースするものはありません」と報告して終了する
- `origin/<prod>..origin/develop` が空で、本番ブランチの先端にタグが付いているが、`git ls-remote --tags origin` にそのタグが無い: タグの作成後に push が失敗している。先端のタグを `<version>` として使い、タグは作り直さない。`git push origin <version>` を実行する、と示して `AskUserQuestion` で承認を得てから実行し、手順 5 の 3 (完了の報告) に進む
- `origin/<prod>..origin/develop` が空で、本番ブランチの先端にタグが無い: マージ済みでタグが未作成。手順 2 (版番号の決定) の後、手順 5 に進む
- develop を head にした open な PR がある: PR は作成済み。手順 2 (版番号の確認) の後、手順 3 は飛ばして PR 番号を使い、手順 4 に進む

### release 手順 1: 内容の確認

`git log --oneline origin/<prod>..origin/develop` の出力を示し、リリースに含まれる変更をユーザーに見せる。

### release 手順 2: 版番号の決定

「共通: タグの形式と版番号」に従って、本番に出ているタグを確認し、リリースの版番号 `<version>` を決める。

### release 手順 3: PR の作成

次のコマンドを実行する、と示して `AskUserQuestion` で承認を得る。
承認されたら実行し、PR の URL を報告する。

```bash
gh pr create --base <prod> --head develop --title "chore(release): <version>" --body-file <(cat <<'EOF'
## Summary

Release <version>: merge develop into <prod>.

{手順 1 の変更の要約を箇条書き}

## Test plan

- CI passes on this PR
EOF
)
```

### release 手順 4: CI とマージ

1. CI の完了を待つ。Bash ツールの `timeout` を最大値 `600000` にして実行する。タイムアウトしたら同じコマンドを再実行して待ち続ける。`no checks reported` で終了した場合は CI が無いので次へ進む。失敗した場合は内容を報告して終了する

   ```bash
   gh pr checks <pr-number> --watch --fail-fast --interval 30
   ```

2. 次のコマンドを実行する、と示して `AskUserQuestion` で承認を得る。`--squash` と `--rebase` は使わず、`--delete-branch` も付けない (develop を削除しないため)

   ```bash
   gh pr merge <pr-number> --merge
   ```

3. 承認待ちで失敗した場合は「共通: レビュー待ちで止まったとき」に従って終了する
4. マージ後に `git fetch origin` を実行し、`git merge-base --is-ancestor origin/develop origin/<prod>` が成功することを確認する

### release 手順 5: タグ

1. 次のコマンドを実行する、と示して `AskUserQuestion` で承認を得る

   ```bash
   git tag <version> origin/<prod>
   git push origin <version>
   ```

2. 承認されたら実行し、`git tag --points-at origin/<prod>` でタグが付いたことを確認する
3. 完了を報告する。GitHub Release は作っていないこと、バージョンファイルは更新していないことを添える

### release の次

リリースの手順はここまでである。
本番へのデプロイはこのスキルの対象外で、各リポジトリの手順に従う。

## 次の操作の案内

各場面の末尾で、次にユーザーが起動するものを案内する。

| 場面 | 次の操作 |
| ---- | -------- |
| `hotfix` (worktree の作成後) | 修正後に `/commit` → `/pr-merge`。マージ後に `/release-hotfix backmerge` |
| `backmerge` (worktree の作成とマージ後) | この worktree で `/pr-merge` |
| `release` (タグ作成後) | なし (デプロイは各リポジトリの手順) |
| レビュー待ちで停止 (`release`) | 承認後に `/release-hotfix release` を再実行 |
| レビュー待ちで停止 (`hotfix` / `backmerge`) | 承認後に `/pr-merge` を再実行 |
