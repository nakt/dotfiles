---
description: Git 操作に関するルール
---

# Git ワークフロールール

## ブランチ戦略

- main / master ブランチに直接コミットしない
- 全ての変更はフィーチャーブランチ（デフォルトブランチ以外）から PR 経由で行う
- 変更を伴う作業は常に worktree で行い、main の作業ツリーは常に `main` ブランチのまま保つ
- main の作業ツリーにいるなら `EnterWorktree` で worktree に入り、既に worktree にいるならそこで作業を続ける
- issue に着手する場合は issue-tracker の claim を main の作業ツリーで行ってから worktree に入る。マージ後の worktree の後片付けは `/pr-merge` が行う

## worktree での作業

worktree で作業する場合は `EnterWorktree` ツールを使い、`name` に `type/short-description` 形式の名前を必ず渡す（`name` はスラッシュ区切りのセグメントを許容するのでこの形式をそのまま渡せる）。省略するとランダムな 3 語名が生成され、ブランチ名が内容を表さなくなる。

- 1 worktree = 1 タスク = 1 PR
- `EnterWorktree(name="<type>/<short-description>")` で作ると、`/` が `+` に変換された `worktree-<type>+<short-description>` がブランチ名になる。これを正式なブランチ名とし、リネームや切り直しはしない

## コミット戦略

### 基本原則

- コミットはユーザーから要求されたときに行う。ユーザーが明示的に起動したスキル（`/commit` などコミットを行うことが description に明示されたもの）は、その起動をユーザーからの要求とみなす。モデルが自動起動したスキルは含まず、そのスキル内でユーザーの実行確認が取れた場合のみ要求とみなす
- 細かく意味のある単位でコミット
- 関連する変更のみをステージングする
- コミットメッセージは `type(scope): description` 形式で書く

### ファイル移動

ファイルを移動する場合は `git mv` コマンドを使用する。git が rename として正しく履歴を追跡できる。

```bash
git mv old-path new-path
```

## PR ガイドライン

### タイトル形式

```text
type(scope): description
```

### 本文に含める内容

- Summary: 変更内容の要約
- Test plan: テスト方法
- 関連 Issue: `Closes #123`

## コメント・メッセージ

- コミットメッセージ・PR タイトル・コード内コメントは英語で書く
- 一時コメントには `TODO` / `FIXME` ラベルを使用する

## 禁止事項

### 実行禁止コマンド

- `git push --force`（main/master へ）
- `git reset --hard`（ユーザー確認なしで）
- `git rebase -i`（対話モード非対応）
- `--no-verify` オプション

### コミット禁止ファイル

- `.env`（環境変数）
- 秘密鍵（`id_rsa`, `id_ed25519`）
- トークン・API キー

これらは `.gitignore` に追加して誤コミットを防止すること。
