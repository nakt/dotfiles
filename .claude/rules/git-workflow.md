---
description: Git 操作に関するルール
paths:
  - "**/*"
---

# Git ワークフロールール

## ブランチ戦略

- main ブランチに直接コミットしない
- 全ての変更はフィーチャーブランチから PR 経由で行う
- ブランチ名は内容を表す明確な名前にする

## コミット戦略

### 基本原則

- ユーザーから明示的に要求されるまでコミットしない
- 細かく意味のある単位でコミット
- `git add -p` で関連する変更のみをステージング

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
