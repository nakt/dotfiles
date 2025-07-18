# CLAUDE.md

## Communication Rules
- 常に日本語で会話する

## Basic Rules
- 一時ファイルは workspace/ ディレクトリを使用して、このディレクトリは git の管理対象からは除く
- むやみやたらと絵文字を使わない
- Markdownを生成する際にむやみやらたと強調(** **)を使わない

## Git戦略

### ブランチ運用
- `main`: 本番用（直接pushは禁止）
- `dev`: 開発用（ここで作業）

### Claude Codeの実行ルール

#### 自動実行OK
```bash
git status
git log --oneline -5
git diff
git branch
```

#### 避けるべき操作
- `git push --force`
- `git reset --hard`
- mainブランチへの直接push

### 基本ワークフロー

#### 作業開始
```bash
# 必ずdevブランチで作業開始
git checkout dev
git pull origin dev
```

#### 開発・コミット
```bash
git add .
git commit -m "feat: 変更内容"
git push origin dev
```

#### 本番反映
devブランチの内容をmainにマージ（PR経由）

### コミットメッセージ
```
feat: 新機能
fix: バグ修正
docs: ドキュメント更新
refactor: リファクタリング
```

### 注意事項
- **必ずdevブランチで作業**
- 機密情報をコミットしない
- mainブランチは触らない
- commit メッセージは英語で作成する