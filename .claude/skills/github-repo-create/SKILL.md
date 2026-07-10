---
name: github-repo-create
description: >-
  GitHub リポジトリの新規作成スキル。プロジェクト内容をヒアリングしてリポジトリ名・description を提案し、
  gitignore を選択して gh repo create で作成する。作成後に verify-repo.sh で visibility と default branch の検証を行う。
  `/github-repo-create` で手動起動する。
disable-model-invocation: true
allowed-tools:
  - Bash(gh:*)
  - Bash(ghq:*)
  - Bash(git:*)
  - Bash(bash:*)
  - Bash(ls:*)
  - Bash(jq:*)
  - Bash(grep:*)
  - Read
---

# GitHub Repository Creator

GitHub リポジトリを対話的に作成するスキル。ヒアリングから検証まで5フェーズで進める。

## Current state

- Owner: !`gh api user --jq .login 2>/dev/null || true`

## ワークフロー

### Phase 1: プロジェクト内容のヒアリング

ユーザーに以下を確認する。既に会話の中で分かっている情報はスキップしてよい。

- 何を作るか（目的・概要）
- 使用言語/フレームワーク（gitignore テンプレート選択に使う）
- 公開/非公開の希望（デフォルト: private。聞かれなければ private で進める）

owner は上記 Current state の Owner を使用する。

### Phase 2: リポジトリ名・description の提案

ヒアリング内容をもとに提案する:

- リポジトリ名を 2-3 案（小文字ケバブケース、簡潔で内容を表す名前）
- 各案に英語の description を添える（120文字以内が目安）

ユーザーの承認を得てから次のフェーズへ進む。

スキップ条件: ユーザーが「{名前} で作って」のようにリポジトリ名を明示的に指定した場合はこのフェーズをスキップする。ただし description が未指定なら提案する。

### Phase 3: 設定確認

作成前に最終設定一覧を提示して確認を取る:

| 項目 | 値 |
|------|-----|
| リポジトリ名 | `{repo_name}` |
| description | `{description}` |
| visibility | private（または public） |
| gitignore | `{template_name}` |
| README | 追加する（固定） |

gitignore テンプレート名は大文字小文字が重要。`gh api /gitignore/templates` で取得したリストと照合して正確な名前を使う。
主要なテンプレート名の対応は [references/gh-repo-create-reference.md](references/gh-repo-create-reference.md) を参照。

public を選択した場合、以下の警告を出して再確認する:

> public リポジトリはコード・コミット履歴が全世界に公開されます。
> シークレットや API キーが含まれていないか確認してください。
> 本当に public でよいですか？

### Phase 4: リポジトリ作成

```bash
# gitignore テンプレート名の検証
gh api /gitignore/templates | jq -r '.[]' | grep -ix "{template_name}"

# リポジトリ作成
gh repo create {repo_name} \
  --private \
  --description "{description}" \
  --gitignore "{template_name}" \
  --add-readme

# ghq で clone
ghq get {owner}/{repo_name}
```

- visibility が public の場合は `--private` を `--public` に変更
- gitignore 不要の場合は `--gitignore` フラグを省略
- `--license` は使用しない（ユーザー要件として常に不要）
- `--add-readme` は常に付与する（空リポジトリだと default branch が未設定になるため）

### Phase 5: 作成後検証

検証スクリプトを実行する:

```bash
# gitignore を指定した場合
bash ~/.claude/skills/github-repo-create/scripts/verify-repo.sh {owner}/{repo_name} {private|public} {gitignore_template}

# gitignore を指定しなかった場合
bash ~/.claude/skills/github-repo-create/scripts/verify-repo.sh {owner}/{repo_name} {private|public}
```

スクリプトが exit 1 を返した場合、FAIL 項目の内容をユーザーに報告し、以下の修正方法を提示する。

#### FAIL 時の復旧手順

visibility FAIL（最優先で対処）:

```bash
gh repo edit {owner}/{repo} --visibility private  # または --visibility public
```

default branch FAIL:

```bash
gh api -X PATCH /repos/{owner}/{repo} -f default_branch=main
```

description FAIL:

```bash
gh repo edit {owner}/{repo} --description "{description}"
```

README.md FAIL: clone 先で手動作成して push する。

.gitignore FAIL: clone 先で手動作成して push する。

local directory FAIL: `ghq get {owner}/{repo_name}` をリトライする。

### 完了報告

検証結果を報告し、使用言語に応じた初期化スキルを案内する:

| 言語 | スキル |
|------|--------|
| Python | `/python-dev-guide` でガイド参照可能 |
| React | `/react-dev-guide` でガイド参照可能 |
| TypeScript | `/typescript-dev-guide` でガイド参照可能 |

## Constraints

- デフォルトは必ず `--private`。public にする場合はユーザーの明示的な確認を取る
- visibility 検証が FAIL した場合は即座に警告する
- gitignore テンプレート名は `gh api /gitignore/templates` で毎回検証してから使用する
- ライセンスは指定しない（`--license` フラグは使わない）
- `--add-readme` は常に付与する（空リポジトリだと default branch が未設定になるため）
- owner は個人アカウントのみ対応（org は権限管理が複雑になるためスコープ外）
- コミュニケーションは日本語で行う
