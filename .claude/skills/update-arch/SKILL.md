---
name: update-arch
description: アーキテクチャドキュメント(docs/arch)の更新・初期化スキル。コード変更時に処理概要・処理フロー・データフローのドキュメント更新要否を判断し、必要に応じて更新する。docs/arch が存在しないプロジェクトでは初期化を行う。ユーザーがアーキテクチャドキュメントの作成・更新を求めたとき、または手動 `/update-arch` で呼び出されたときに使用する。
argument-hint: "[target directory]"
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(git diff:*), Bash(git log:*), Bash(git merge-base:*), Bash(git rev-parse:*), Bash(git symbolic-ref:*), Bash(test:*), Bash(echo:*)
---

# Update Architecture Docs

docs/arch の処理概要・処理フロー・データフローを、過度に詳細にならない粒度で初期化・更新する。

## Current state

Default branch は `origin/HEAD` から解決する（取得できなければ `main` / `master` の存在で決める）。

- docs/arch exists: !`test -d docs/arch && echo 'yes' || echo 'no'`
- Staged changes: !`git diff --cached --stat 2>/dev/null || true`
- Unstaged changes: !`git diff --stat 2>/dev/null || true`
- Recent commits: !`git log --oneline -10 2>/dev/null || echo '(none)'`
- Current branch: !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '(none)'`
- Default branch: !`b=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); b=${b#origin/}; echo "${b:-$(git rev-parse --verify -q main >/dev/null 2>&1 && echo main || echo master)}"`

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
    └── main.md      # メイン処理フロー（初期化で作るのはこれ 1 つ。機能別への分割は Decision Guide「flows/ の分割基準とファイル名」に従う）
```

- `~/.claude/skills/update-arch/templates/readme.md` → `docs/arch/README.md`
- `~/.claude/skills/update-arch/templates/overview.md` → `docs/arch/overview.md`
- `~/.claude/skills/update-arch/templates/data-flow.md` → `docs/arch/data-flow.md`
- `~/.claude/skills/update-arch/templates/flows-main.md` → `docs/arch/flows/main.md`

## 更新モード

コード変更に伴うドキュメント更新を判断・実行する。

1. 対象の差分を決める。 staged 変更は空であることが多い（execute-plan はタスクごとにコミットし、wrapup-dispatch はセッション終盤に呼ぶため）。下記を上から順に見て、最初に中身のあるものを対象にする
   1. Current state の Staged changes が空でなければ `git diff --cached` を対象にする
   2. 空なら Unstaged changes を見て、空でなければ `git diff` を対象にする
   3. どちらも空なら、このブランチで積んだコミット群を対象にする。`git merge-base HEAD <Current state の Default branch>` で分岐点を求め `git diff <分岐点>..HEAD` を使う。Current branch が Default branch と同じ場合、または分岐点が求まらない場合は Recent commits から対象コミット範囲をユーザーに確認する
   4. 上記いずれでも差分が取れない場合は、更新要否を判断できないので「対象の変更が特定できない」と伝えて対象範囲をユーザーに確認する。差分が空であることを根拠に「更新不要」とは報告しない
2. 変更に関連する docs/arch 内のドキュメントを特定する（対応表は下記 Decision Guide「更新対象の判断」）
3. 更新要否を判断する
4. 必要な場合はドキュメントを更新する。ファイル参照は `file_path:line_number` 形式で記載する。新規に `flows/<name>.md` を起こす場合は `~/.claude/skills/update-arch/templates/flows-main.md` を Read してテンプレートとして使い、H1 をその機能名に差し替える
5. 判断結果を報告する。手順 1 で選んだ差分の取得元（staged / unstaged / コミット範囲）も添える。更新不要と判断した場合は理由を明確に説明する

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
| 特定機能の処理変更 | 該当する `flows/<name>.md`。無ければ flows/main.md の該当ステップ |
| データ構造・流れの変更 | data-flow.md |
| 新機能追加 | flows/main.md に追記。下記の分割基準を満たすときだけ `flows/<name>.md` を新規作成 |

### flows/ の分割基準とファイル名

- `flows/main.md` はエントリーポイントから主要処理までを通しで書く既定の置き場。初期化モードが必ず作るのはこれだけで、機能が増えても原則ここに追記する
- 次のどちらかを満たしたときだけ別ファイルに切り出す
  - 独立したエントリーポイントを持つ（CLI サブコマンド、API のエンドポイント群、バッチ / ジョブ、常駐プロセスなど）
  - main.md の該当ステップが 1 セクションに収まらなくなり、通しの流れが読めなくなっている（目安 30 行超）
- ファイル名は機能単位 1 ファイルで、コード上の呼称に合わせた kebab-case（英小文字・ハイフン）にする。ディレクトリ名・コマンド名・エンドポイント名がそのまま使えるならそれを使う（例: `flows/auth.md`, `flows/batch-import.md`）。日本語名や連番は使わない
- 切り出したら main.md の該当ステップを 1〜2 行の要約に置き換え、切り出し先へリンクする（main.md から全機能に辿れる状態を保つ）
- 迷う規模なら切り出さず main.md に書く。ファイルを増やすより main.md の見通しを優先する
