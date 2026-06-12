---
name: record-adr
description: 設計・ロジック判断の決定記録(ADR)を docs/adr に起票するスキル。技術選定だけでなく処理フロー変更・アルゴリズム選択・データモデル・API 設計・検証や実験から得た方針の「決定とその理由」を記録する。docs/adr が存在しないプロジェクトでは初期化を行う。手動 `/record-adr [タイトル]` で呼び出す。
disable-model-invocation: true
argument-hint: "[decision title]"
allowed-tools: Read(*), Glob(*), Grep(*), Write(*), Edit(*), Bash(ls:*), Bash(grep:*), Bash(test:*), Bash(date:*)
---

# Record ADR

設計・ロジック判断の決定記録(ADR: Architecture Decision Record)を起票する。技術選定に限らず、処理フロー・アルゴリズム選択・データモデル・API 設計、および検証・実験から得た方針の「何を決めたか」と「なぜか」を append-only で残す。

## Current state

- docs/adr exists: !`test -d docs/adr && echo 'yes' || echo 'no'`
- Existing ADRs: !`ls docs/adr/[0-9]*.md 2>/dev/null || echo '(none)'`
- Today: !`date +%Y-%m-%d`

## モード判定

上記 Current state の docs/adr exists で判断する。

- 初期化モード: `no` の場合
- 追記モード: `yes` の場合

## 初期化モード

新規プロジェクトに docs/adr を導入する。

1. `docs/adr/` を作成する
2. テンプレートを Read してコピー生成する
   - `~/.claude/skills/record-adr/templates/readme.md` → `docs/adr/README.md`
   - `~/.claude/skills/record-adr/templates/0001-record-architecture-decisions.md` → `docs/adr/0001-record-architecture-decisions.md`(フロントマターの `date:` を Current state の Today で置換)

`docs/adr/` 直下に template.md は置かない(ADR 一覧のノイズを避ける)。

引数(`$ARGUMENTS`)でタイトルが渡されている場合は、初期化後そのまま追記モードへ進み 0002 を起票する。引数がなければ初期化のみで完了報告する。

## 追記モード

新しい決定を起票する。

1. タイトルを確定する
   - 引数(`$ARGUMENTS`)があればそれを使う
   - なければユーザーに確認する
2. 採番する: Current state の Existing ADRs で最大番号を確認し +1、4 桁ゼロ埋め
3. `~/.claude/skills/record-adr/templates/adr-template.md` を Read し、以下を埋めて `docs/adr/NNNN-kebab-title.md` として Write する
   - kebab-title はタイトルを小文字ハイフン区切りにしたもの
   - フロントマター `date:` を Current state の Today に置換
   - H1 `# NNNN: タイトル` を実際の番号とタイトルに置換
   - 対話で Context / Decision / Rationale / Consequences を埋める。検証・実験に基づく決定なら Rationale に実測値や比較を具体的に書く。Alternatives がなければ削除してよい
   - 本文の各段落は 1 段落 1 行で書く。途中でハードラップしない
4. `docs/adr/README.md` の一覧テーブルを再生成する
   - 既存の `docs/adr/README.md` を Read で読み込み、既存行の「サマリ」列の文言を把握する
   - 全 ADR のフロントマター status と H1 タイトルを以下で収集する

     ```bash
     grep -h '^status:' docs/adr/[0-9]*.md
     grep -h '^# [0-9]' docs/adr/[0-9]*.md
     ```

   - 既存行の「サマリ」列はそのまま使い、新規行のサマリのみ Claude が記入する
   - テーブル全体を書き直す(追記ではなく再生成)
5. 方針変更を伴う場合は、新旧 ADR のフロントマターを双方向に更新する
   - 新 ADR の `supersedes: "NNNN"` に旧 ADR 番号を設定する
   - 旧 ADR の `status: Superseded` に変更する
   - 旧 ADR の `superseded_by: "NNNN"` に新 ADR 番号を設定する
   - これはフロントマターのみの更新で、本文セクション(`##` 以降)は変更しない。append-only の例外として許可する
6. 起票結果を報告する

## Key Principles

1. append-only。本文は書き換えない。変更は新規 ADR で表現する
2. Status は `Accepted` または `Superseded` の 2 値のみ。置き換えの詳細は `supersedes` / `superseded_by` フィールドで管理する
3. Decision は「何を決めたか」、Rationale は「なぜか(検証・実験の根拠)」と役割を分ける
4. 起票前に `docs/adr/README.md` を確認し、既存決定と矛盾しないか確かめる
5. 実験の生ログ・試行錯誤は `.workspace/knowledge/`、確定した決定と根拠は docs/adr
6. 採番が衝突した場合(並行ブランチ等)は後から追加した方を繰り上げる
7. 本文段落はハードラップしない。1 段落を 1 行で書く。エディタの折り返し表示に委ねる
8. Markdown スタイルは `~/.claude/rules/markdown-style.md` に従う。
