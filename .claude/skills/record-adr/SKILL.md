---
name: record-adr
description: 設計・ロジック判断の決定記録(ADR)を docs/adr に起票するスキル。技術選定だけでなく処理フロー変更・アルゴリズム選択・データモデル・API 設計・検証や実験から得た方針の「決定とその理由」を記録する。既存 ADR の Deprecated 化(後継方針を立てない無効化)も行う。docs/adr が存在しないプロジェクトでは初期化を行う。「この決定を ADR として残して」「設計判断を記録して」「この決定はもうやめた」「この方針は代わりを立てずに廃止する」のような依頼、または重要な設計・ロジック判断が下された場面で使う。手動 `/record-adr [タイトル]` でも呼べる。
disable-model-invocation: false
argument-hint: "[decision title]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - Bash(ls:*)
  - Bash(grep:*)
  - Bash(test:*)
  - Bash(date:*)
  - Bash(echo:*)
  - Bash(mkdir:*)
---

# Record ADR

設計・ロジック判断の決定記録(ADR: Architecture Decision Record)を起票する。
技術選定に限らず、処理フロー・アルゴリズム選択・データモデル・API 設計、および検証・実験から得た方針の「何を決めたか」と「なぜか」を append-only で残す。

## Current state

- docs/adr exists: !`test -d docs/adr && echo 'yes' || echo 'no'`
- Existing ADRs: !`ls docs/adr/[0-9]*.md 2>/dev/null || echo '(none)'`
- Today: !`date +%Y-%m-%d`

## モード判定

Deprecated 化モードだけは Current state のシェル実行結果では判定できない。
既存 ADR を対象とする以上 docs/adr exists は必ず `yes` になり、機械的に分けると追記モードに落ちるため、判定材料は依頼内容側にしかない。
そこで次の順で判定する。

1. Deprecated 化モード: 依頼が既存 ADR を後継方針なしで無効化するもの(「この決定はもうやめた」「対象の機能ごと廃止した」など、代わりの方針を新しく立てない依頼)の場合
2. それ以外は従来どおり Current state の docs/adr exists で分ける
   - 初期化モード: `no` の場合
   - 追記モード: `yes` の場合

引数(`$ARGUMENTS`)は初期化モード / 追記モードでは起票する決定のタイトルとして扱う。
Deprecated 化モードは起票を行わないため引数をタイトルとしては使わず、対象 ADR は Deprecated 化モードの手順 1 で特定する(依頼文に番号やファイル名があればそれを手掛かりにする)。

## 初期化モード

新規プロジェクトに docs/adr を導入する。

1. `docs/adr/` を作成する
2. テンプレートを Read してコピー生成する
   - `~/.claude/skills/record-adr/templates/readme.md` → `docs/adr/README.md`
   - `~/.claude/skills/record-adr/templates/0001-record-architecture-decisions.md` → `docs/adr/0001-record-architecture-decisions.md`(フロントマターの `date:` を Current state の Today で置換)

`docs/adr/` 直下に template.md は置かない(ADR 一覧のノイズを避ける)。

引数(`$ARGUMENTS`)でタイトルが渡されている場合は、初期化後そのまま追記モードへ進み 0002 を起票する。
引数がなければ初期化のみで完了報告する。

## 追記モード

新しい決定を起票する。

1. 起票前に `docs/adr/README.md` を確認し、既存決定と矛盾しないか確かめる
2. タイトルを確定する
   - 引数(`$ARGUMENTS`)があればそれを使う
   - なければユーザーに確認する
3. 採番する: Current state の Existing ADRs で最大番号を確認し +1、4 桁ゼロ埋め
   - 起票時点では自ブランチに見えている番号しか判断材料が無いため、並行ブランチで同じ番号が独立に使われることがある。この衝突はマージ・リベースで両者が同じ作業ツリーに揃ったとき（同じ番号のファイルが 2 つ並ぶ、または同名ファイルのコンフリクト）に初めて検出できる
   - 検出したら、フロントマターの `date:` が新しい方（同日なら後から取り込んだ方）を、その時点の最大番号 +1 に付け替える。番号は必ず大きい側へずらし、空き番号の再利用や既存 ADR の番号変更はしない
   - 付け替え時はファイル名・H1 の番号・`docs/adr/README.md` の一覧行・他 ADR の `supersedes` / `superseded_by` の参照をすべて新番号に揃える
4. `~/.claude/skills/record-adr/templates/adr-template.md` を Read し、以下を埋めて `docs/adr/NNNN-kebab-title.md` として Write する
   - kebab-title はタイトルを小文字ハイフン区切りにしたもの
   - フロントマター `date:` を Current state の Today に置換
   - H1 `# NNNN: タイトル` を実際の番号とタイトルに置換
   - status はテンプレート既定の `Accepted` のまま起票する(status は `Accepted` / `Superseded` / `Deprecated` の 3 値。`Superseded` は手順 6 で後継 ADR を伴って既存 ADR を置き換えるときに、`Deprecated` は Deprecated 化モードで後継方針なしに無効化するときにのみ使う)
   - 対話で Context / Decision / Rationale / Consequences を埋める。検証・実験に基づく決定なら Rationale に実測値や比較を具体的に書く。Alternatives がなければ削除してよい
   - 検証・実験で使った `.workspace/` の一時ファイルは参照せず、根拠となる実測値・比較結果を Rationale 本文に転記する(`.workspace/` は使い捨てのため)
   - 本文の段落は 1 文 1 行にする。文の途中では折らない
5. `docs/adr/README.md` の一覧テーブルを再生成する
   - 既存の `docs/adr/README.md` を Read で読み込み、既存行の「サマリ」列の文言を把握する
   - 全 ADR のフロントマター status と H1 タイトルを以下で収集する

     ```bash
     grep -h '^status:' docs/adr/[0-9]*.md
     grep -h '^# [0-9]' docs/adr/[0-9]*.md
     ```

   - 既存行の「サマリ」列はそのまま使い、新規行のサマリのみ Claude が記入する
   - テーブル全体を書き直す(追記ではなく再生成)
6. 後継 ADR を伴う方針変更の場合は、新旧 ADR のフロントマターを双方向に更新する
   - 新 ADR の `supersedes: "NNNN"` に旧 ADR 番号を設定する
   - 旧 ADR の `status: Superseded` に変更する
   - 旧 ADR の `superseded_by: "NNNN"` に新 ADR 番号を設定する
   - 更新するのはフロントマターのみで、本文セクション(`##` 以降)は変更しない。append-only は本文に対する原則であり、フロントマターは状態を表す機械可読値なので対象外
   - この手順は後継 ADR がある場合のみ。代わりの方針を立てず旧 ADR を無効にするだけの依頼は追記モードではなく Deprecated 化モードで扱う(モード判定 1)
7. 起票結果を報告する

## Deprecated 化モード

後継方針のない決定を無効化する。
新規 ADR の起票と採番は行わない。

1. 対象 ADR を特定する
   - `docs/adr/README.md` の一覧で Status が `Accepted` の行から候補を挙げ、複数あれば番号でユーザーに確認する
   - 依頼文が番号やファイル名で対象を示している場合はその ADR を対象にする
2. 対象 ADR のフロントマターを更新する
   - `status` を `Deprecated` に変更する
   - `deprecated_date` を Current state の Today に設定する
   - `deprecated_date` フィールドが無ければ `superseded_by` の次の行に追加する
3. 対象 ADR の本文末尾に `## Deprecation` を追記する
   - 本文の最終節として追記し、既存の節は書き換えない
   - 見出し直下に 1 段落でやめた理由を書き、後継方針がないことを明記する
   - 日付は本文に書かず `deprecated_date` のみで表す
   - 段落は 1 文 1 行にする。文の途中では折らない
4. `docs/adr/README.md` を更新する
   - 一覧テーブルを再生成する。手順は追記モードの手順 5 と同じで、`status: Deprecated` も同じ grep でそのまま拾える
   - 「運用」セクションが `Deprecated` や `## Deprecation` に触れていない旧記述のままなら、`~/.claude/skills/record-adr/templates/readme.md` を Read し、現行の「運用」セクションの記述へ更新する
5. Deprecated 化の結果を報告する

status の遷移は `Accepted` からの一方向のみで、`Superseded` / `Deprecated` からの逆行と横移動はしない。
Deprecated 化の後に後継方針が出てきた場合は追記モードで新規 ADR を起票し、旧 ADR は `Deprecated` のまま残す。
