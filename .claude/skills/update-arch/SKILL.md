---
name: update-arch
description: アーキテクチャドキュメント(docs/arch)の更新・初期化スキル。コード変更時に処理概要・処理フロー・データフローのドキュメント更新要否を判断し、必要に応じて更新する。docs/arch が存在しないプロジェクトでは初期化を行う。ユーザーがアーキテクチャドキュメントの作成・更新を求めたとき、または手動 `/update-arch` で呼び出されたときに使用する。
argument-hint: "[target directory]"
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(git:*), Bash(test:*), Bash(echo:*)
---

# Update Architecture Docs

docs/arch の処理概要・処理フロー・データフローを、過度に詳細にならない粒度で初期化・更新する。

## Current state

- docs/arch exists: !`test -d docs/arch && echo 'yes' || echo 'no'`
- Staged changes: !`git diff --cached --stat 2>/dev/null || true`

## モード判定

上記 Current state の docs/arch exists で判断する。

- 初期化モード: `no` の場合
- 更新モード: `yes` の場合

## 初期化モード

新規プロジェクトに docs/arch を導入する。

1. 対象ディレクトリを確認する
   - 引数が渡された場合（`$ARGUMENTS`）はそれを対象ディレクトリとして使用する
   - 引数がない場合はユーザーに確認する:「docs/arch を初期化します。どのディレクトリを対象にしますか？（例: src/, app/, .）」
2. 指定ディレクトリの構造を分析する
3. 以下の構成でテンプレートを Read してコピー生成する。各テンプレートの `[...]` 箇所は分析結果で埋める

```text
docs/arch/
├── README.md        # 目次・更新ポリシー
├── overview.md      # 処理概要
├── data-flow.md     # データフロー
└── flows/           # 処理フロー詳細
    └── main.md      # メイン処理フロー
```

- `~/.claude/skills/update-arch/templates/readme.md` → `docs/arch/README.md`
- `~/.claude/skills/update-arch/templates/overview.md` → `docs/arch/overview.md`
- `~/.claude/skills/update-arch/templates/data-flow.md` → `docs/arch/data-flow.md`
- `~/.claude/skills/update-arch/templates/flows-main.md` → `docs/arch/flows/main.md`

## 更新モード

コード変更に伴うドキュメント更新を判断・実行する。

1. `git diff --cached` で変更内容を確認する
2. 変更に関連する docs/arch 内のドキュメントを特定する
3. 更新要否を判断する
4. 必要な場合はドキュメントを更新する。ファイル参照は `file_path:line_number` 形式で記載する
5. 判断結果を報告する。更新不要と判断した場合は理由を明確に説明する

## Decision Guide

### 更新要否の判断

| 変更内容 | 判断 | 理由 |
|---|---|---|
| 新規機能追加 | 更新必要 | 処理フロー追加 |
| 処理フロー変更 | 更新必要 | フロー文書と乖離 |
| データ構造変更 | 更新必要 | データフロー影響 |
| API 変更 | 更新必要 | 外部連携影響 |
| バグ修正（フロー同一） | 更新不要 | 振る舞い変更なし |
| リファクタリング | 更新不要 | 振る舞い変更なし |
| テスト追加 | 更新不要 | 本体コード影響なし |

### 更新対象の判断

| 変更の性質 | 更新対象 |
|---|---|
| 全体構成に影響 | overview.md |
| 特定機能の処理変更 | flows/[該当機能].md |
| データ構造・流れの変更 | data-flow.md |
| 新機能追加 | flows/[新機能].md（新規作成） |
