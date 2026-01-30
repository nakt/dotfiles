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

## 開発フロー

1. フィーチャーブランチを作成

   ```bash
   git checkout -b feature/機能名
   ```

2. 変更を実装

3. 変更を確認

   ```bash
   git status
   git diff
   ```

4. main ブランチの最新の変更を取り込む

   ```bash
   git pull origin main --rebase
   ```

5. 変更をステージング

   ```bash
   git add -p  # 選択的にステージング
   ```

6. コミットを作成

   ```bash
   git commit -m "feat: 変更内容の説明"
   ```

7. リモートにプッシュ

   ```bash
   git push -u origin feature/機能名
   ```

8. PR を作成

   ```bash
   gh pr create
   ```

## コミット戦略

### 基本原則

- ユーザーから明示的に要求されるまでコミットしない
- 細かく意味のある単位でコミット
- `git add -p` で関連する変更のみをステージング

### コミットメッセージ形式

```text
<type>: <description>
```

タイプ:

- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメント
- `refactor`: リファクタリング
- `test`: テスト
- `chore`: その他の変更
- `ci`: CI/CD 関連
- `perf`: パフォーマンス改善

ルール:

- メッセージは英語で記述
- 何をしたかではなく、なぜ変更したかを説明

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
