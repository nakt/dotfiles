---
name: record-adr
description: 設計・ロジック判断の決定記録(ADR)を docs/adr に起票するスキル。技術選定だけでなく処理フロー変更・アルゴリズム選択・データモデル・API 設計・検証や実験から得た方針の「決定とその理由」を記録する。docs/adr が存在しないプロジェクトでは初期化を行う。手動 `/record-adr [タイトル]` で呼び出す。
disable-model-invocation: true
argument-hint: "[decision title]"
allowed-tools: Read(*), Glob(*), Grep(*), Write(*), Edit(*), Bash(ls:*), Bash(grep:*), Bash(test:*), Bash(date:*)
---

# Record ADR

設計・ロジック判断の決定記録(ADR: Architecture Decision Record)を起票する。
技術選定に限らず、処理フロー・アルゴリズム選択・データモデル・API 設計、および
検証・実験から得た方針の「何を決めたか」と「なぜか」を append-only で残す。

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
2. 以下を生成する

```text
docs/adr/
├── README.md     # インデックス(番号・タイトル・Status・1行サマリ)
├── template.md   # 起票テンプレート
└── 0001-record-architecture-decisions.md   # 決定記録の採用自体を記録
```

引数(`$ARGUMENTS`)でタイトルが渡されている場合は、初期化後そのまま追記モードへ進み
0002 を起票する。引数がなければ初期化のみで完了報告する。

### README.md(初期テンプレート)

```markdown
# Decision Records (ADR)

このディレクトリは設計・ロジック判断の決定記録を管理します。
技術選定だけでなく、処理フロー・アルゴリズム・データモデル・API 設計、
検証や実験から得た方針の「決定とその理由」を記録します。

## 一覧

| No. | タイトル | Status | サマリ |
|-----|---------|--------|--------|
| [0001](./0001-record-architecture-decisions.md) | Record architecture decisions | Accepted | 決定記録を運用する |

## 運用

- append-only。一度書いた本文は書き換えない
- 方針変更時は新規 ADR を起票し、旧 ADR の Status を `Superseded by NNNN` にする
- 起票は `/record-adr [タイトル]` で行う
- 実験の生ログは `.workspace/knowledge/`、確定した決定と根拠はここ
```

### template.md(初期テンプレート)

```markdown
# NNNN: タイトル

Status: Accepted
Date: YYYY-MM-DD

## Context

何を解決・検証しようとしたか。前提・制約・観察した問題。

## Decision

採用した方針・ロジック・アルゴリズムを 1〜3 文で明記する。

## Rationale

なぜこの Decision にしたか。検証手順・実測値・比較対象との差異。
詳細な実験ログは `.workspace/knowledge/` への参照リンクでもよい。

## Consequences

この決定で何が変わるか・何を捨てたか・既知の欠点。

## Alternatives Considered (任意)

- 案A: 不採用の理由
```

### 0001-record-architecture-decisions.md(初期テンプレート)

```markdown
# 0001: Record architecture decisions

Status: Accepted
Date: {today}

## Context

検証・実験が多い開発スタイルで、「なぜこのロジック・処理フローにしたか」を
後から参照できる場所がなかった。docs/arch は現状の記述、.workspace/knowledge は
揮発する作業メモであり、確定した決定とその根拠を残す層が欠けていた。

## Decision

技術選定に限らず、処理フロー変更・アルゴリズム選択・データモデル・API 設計、
検証や実験から得た方針も含めて、決定とその理由を docs/adr に記録する。

## Rationale

決定の経緯と却下案を残すことで、同じ検討の蒸し返しを防ぎ、数ヶ月後の自分が
判断の前提を辿れるようにする。実験ベースの開発では「なぜ」が最も失われやすい。

## Consequences

- ADR は append-only とし、本文は書き換えない
- 方針変更時は新規 ADR を起票し、旧 ADR を `Superseded by NNNN` でリンクする
- Accepted な ADR を読めば現在の方針が一意に定まる
```

## 追記モード

新しい決定を起票する。

1. タイトルを確定する
   - 引数(`$ARGUMENTS`)があればそれを使う
   - なければユーザーに確認する
2. 採番する: Current state の Existing ADRs で最大番号を確認し +1、4 桁ゼロ埋め
3. `docs/adr/NNNN-kebab-title.md` を `template.md` の枠で作成する
   - kebab-title はタイトルを小文字ハイフン区切りにしたもの
   - Date は Current state の Today を使う
   - 対話で Context / Decision / Rationale / Consequences を埋める。検証・実験に基づく
     決定なら Rationale に実測値や比較を具体的に書く。Alternatives がなければ省略してよい
4. `docs/adr/README.md` の一覧テーブルに行を追加する(インデックスの陳腐化を防ぐ)
5. 方針変更を伴う場合は、置き換えられる旧 ADR の Status を `Superseded by NNNN` に更新する
   (これは Status 行のみの更新で、append-only の例外として許可する)
6. 起票結果を報告する

## Key Principles

1. append-only。本文は書き換えない。変更は新規 ADR で表現する
2. Status は `Accepted` または `Superseded by NNNN` の 2 値のみ
3. Decision は「何を決めたか」、Rationale は「なぜか(検証・実験の根拠)」と役割を分ける
4. 起票前に `docs/adr/README.md` を確認し、既存決定と矛盾しないか確かめる
5. 実験の生ログ・試行錯誤は `.workspace/knowledge/`、確定した決定と根拠は docs/adr
6. 採番が衝突した場合(並行ブランチ等)は後から追加した方を繰り上げる
