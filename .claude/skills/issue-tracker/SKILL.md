---
name: issue-tracker
description: 調査・検討の結果や、作業中に見つけた不具合・課題・TODO を、1 ファイル 1 件の Markdown issue として `issues/` に起票し、未完了 issue の棚卸し（一覧・優先度づけ・ピックアップ）と done 化を行うスキル。1 issue = 1 ファイル、ステータスは inbox / done のディレクトリ 2 値のみで表現する。「この調査結果を issue で起票して」「未完了の issue を棚卸しして優先度が高そうなものをピックアップ」「issue-xxxx を done にして」のような明示的な依頼のほか、レビューや実装の最中に後回しにすべき不具合・課題を見つけて記録に残したいときにも使う。手動 `/issue-tracker` でも呼べる。GitHub issue の操作（gh issue / API）には使わない。
argument-hint: "[create|triage|done <id>] または自然文の依頼"
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(ls:*), Bash(echo:*), Bash(test:*), Bash(date:*), Bash(mkdir:*), Bash(git mv:*), Bash(git rev-parse:*), Bash(mv:*)
---

# Issue Tracker

調査・検討の結果を、後から棚卸しできる形で `issues/` に蓄積する。1 件 = 1 ファイル。状態はディレクトリ（`inbox/` 未完了 / `done/` 完了）で表し、frontmatter には status を持たせない。これは二重管理による不整合を避けるためで、ディレクトリが状態の単一の真実になる。

## Current state

- issues/ exists: !`test -d issues && echo 'yes' || echo 'no'`
- inbox: !`ls issues/inbox/ 2>/dev/null || echo '(none)'`
- done: !`ls issues/done/ 2>/dev/null || echo '(none)'`
- git repo: !`git rev-parse --is-inside-work-tree 2>/dev/null || echo 'no'`
- Today: !`date +%Y%m%d`

## モード判定

ユーザーの依頼文（または引数）から、次の 3 モードのどれかを選ぶ。複数該当する場合は依頼の主目的を優先する。

- create（起票）: 「issue で起票」「issue にしておいて」「記録して」など、直前の調査・検討結果を残す依頼。
- triage（棚卸し / pickup）: 「一覧」「棚卸し」「優先度」「ピックアップ」「どれからやる」など、未完了 issue を見渡して選ぶ依頼。tags に `hold` が入っているものは通常候補から外し、末尾の `## hold 中` セクションに分離する（下記「hold（保留）」参照）。
- done（クローズ）: 「done にして」「クローズ」「片付いた」+ 対象 id を伴う依頼。加えて、triage で取り上げた（または起票済みの）issue に着手し、その作業がこのセッション内で片付いたときは、明示依頼が無くても done を提案・実行する（下記「着手 → 完了（done への接続）」を参照）。

`issues/` が未作成（Current state が `no`）で create を行う場合は、先に下記「初期化」を済ませる。triage / done で `issues/` が無ければ、その旨を伝えて終わる（起票がまだ無いだけなので何も作らない）。

## 初期化

`issues/` が無い状態で create するときだけ、ディレクトリを用意する。

```bash
mkdir -p issues/inbox issues/done
```

`issues/research/` は調査ログが巨大化したとき初めて作る。最初から空ディレクトリは作らない。索引ファイル（`issues/README.md` 等）は常設しない（陳腐化するため。必要時に triage でその場生成するに留める）。

## create（起票）

直前の調査・検討結果を 1 ファイルにまとめて `issues/inbox/` に保存する。

1. 起票対象を確認する。 直前の会話に起票すべき調査・検討の中身があるか見る。無い／曖昧なら「何を issue にするか」を聞き返してから進む。空の issue を作らない。
2. id を決める。 `id = YYYYMMDD-slug`。日付は Current state の Today から `YYYYMMDD`。slug は内容を表す短い kebab-case（英小文字・ハイフン）。連番は使わない（次番号スキャンが要るため。日付プレフィックスで時系列ソートする）。
3. 衝突を避ける。 Current state の inbox / done に同 id が無いか確認する。同日・同テーマで slug が衝突しそうなら slug を具体化する。それでも衝突するなら末尾に `-2`, `-3` を付ける。
4. テンプレートから生成する。 `~/.claude/skills/issue-tracker/templates/issue-template.md` を Read し、`{id}` `{title}` `{created}` `{updated}` を埋めて `issues/inbox/<id>.md` として Write する。`created` と `updated` は Today（`YYYYMMDD` 形式、id の日付部分と同じ表記）。
   - TL;DR と「結論 / プラン」は短く保つ。 ここは triage で各ファイル先頭だけ読むときのスキャン対象。長文は「調査結果」節に置く。
   - 調査結果は長くてよい。 自由にネストしてよい。「事実」と「そこからの解釈」を分けて書くと後から読み返しやすい。
   - priority は分かっていれば入れる。不明なら空のままでよい（triage 側で推定される）。
5. 報告する。 作成パスと TL;DR を 1〜2 行で返す。

## triage（棚卸し / pickup）

`issues/inbox/` の未完了を見渡し、優先度の高そうなものを選ぶ。ファイルは作らない。チャット上に結果を返す。

1. 一覧を取る。 Current state の inbox で件数を把握する。各ファイルの先頭（frontmatter + TL;DR）を読む。全文は読まない（スキャンが目的）。frontmatter の `tags` に `hold` があるかもここで判定する。
   - inbox が空（`(none)`）なら「未完了 issue は無い」と伝えて終わる。done しか無い場合も同様。
2. hold を分離する。 tags に `hold` を持つ issue は通常候補集合から除外する。`priority: high` が付いていても hold なら候補外。分離した hold 群は手順 3 の末尾で別セクションに出す。
3. 優先度を決める。
   - frontmatter に `priority: high|med|low` が明示されていれば、それを最優先で採用する。
   - 明示が無いものは、TL;DR / tags / `created` からの経過日数 / 「未解決の論点」の多さ などから Claude が推定する。
   - 推定したものには 「なぜ高い（低い）と判断したか」を一言添える。明示 priority との区別がつくように、推定であることが分かる書き方にする。
4. 提示する。 候補一覧（id / title / priority とその判定根拠）を出し、最後に「推し」を 1〜数件、理由つきで挙げる。索引を常設ファイルにはしない。
   - inbox に hold 付きが 1 件以上あれば、出力の末尾に専用セクションを追加する。形式:

     ```text
     ## hold 中（N 件）
     - <id>: <title> — hold: <直近の hold: 行から抽出した理由 1 行>
     ```

     `## ログ` の `hold:` 行が複数ある場合は最新（末尾）を採用する。抽出できなければ理由部分は省略する。hold 付きが 0 件ならセクション自体を出さない。

## hold（保留）

「今はやらない」を tags で表明する運用。ディレクトリは動かさず `inbox/` のまま残す。triage の推しノイズを減らすためのもので、単なる後回し（`priority: low`）とは区別する。

- 判定基準: 外部依存待ち / 方針保留 / 優先度が本気で不明 / セッション外の要因待ち、など。次に動かせる目処が立っていないものを hold にする。
- 前提: hold は既存 issue にのみ後付けする。 create と同時に hold を付ける運用はしない（手順・ログを分離するため）。起票して間もなく保留したい場合も、まず create を通常通り完了させ、続けて別操作で hold を付ける。
- 呼び出し: 自然文（「issue-xxxx を hold にして」「hold を外して」など）で反応する。新モードは追加しない。`/issue-tracker hold <id>` のように引数で直叩きされた場合も自然文相当として受け付ける。

### 付与手順

1. 対象 id を確定する。 引数や依頼文の id を使う。曖昧なら inbox を一覧して確認する。
2. `tags:` に `hold` を追加する。 既に他タグがある場合はブロック形式に統一する:

   ```yaml
   tags:
     - hold
     - <既存タグ>
   ```

   単独なら `tags: [hold]` でもよい。
3. `updated` を Today に更新する。
4. `## ログ` に理由を追記する（必須）。

   ```text
   - <Today> hold: <なぜ今動かさないか 1 行>
   ```

### 解除手順

1. `tags:` から `hold` を除く。
2. `updated` を Today に更新する。
3. `## ログ` に再開の契機を追記する（必須）。

   ```text
   - <Today> unhold: <再開する理由・きっかけ 1 行>
   ```

done との違い: hold は「未完了だが今は動かさない」。決着したなら hold ではなく done を使う（下記 done 手順が hold との併存を自動でほどく）。

## 着手 → 完了（done への接続）

triage でピックアップした issue や、create で残しておいた issue に実際に取り掛かり、その作業がこのセッション内で片付いたら、ユーザーからの明示的な「done にして」を待たずに done 化を提案する。放置すると完了済みの issue が inbox に残り、triage の精度が落ちるため。

- 判断。 会話文脈から、その issue の狙いが満たされ追加の残作業が無いと確認できたら「この issue は done にできそう」と一言添える。
- 実行。 ユーザーが同意している（または元々 done 前提で着手していた）なら、下記 done 手順（決着メモ + mv）を実行する。判断が曖昧なら勝手に動かさず確認する。
- 部分完了。 issue 全体が決着していないなら done にはせず、`## ログ` 節に進捗メモだけ追記して inbox に残す。進捗メモは done の決着メモ（`done:` プレフィックス）と triage スキャン上で取り違えないよう、`- <Today> progress: <途中経過を 1 行>` のプレフィックス付きで残す。

## done（クローズ）

調査が決着した issue を `done/` へ移す。

1. 対象 id を確定する。 引数や依頼文の id を使う。曖昧なら inbox を一覧して確認する。
2. hold との併存を解く。 対象 issue の `tags` に `hold` があれば、決着メモ追記の前に自動で unhold する。具体的には `tags:` から `hold` を除き、`## ログ` に `- <Today> unhold: done に向けて解除` を追記する。この後、次ステップで `done:` 行が続く形になる。hold が無ければこのステップは飛ばす。
3. 決着メモをログに追記する（必須）。 mv の前に、対象ファイルの「## ログ」節末尾へ、会話文脈から抽出した決着メモを Edit で追記する。これが無いと「調査だけして放置」と「決着して完了」が区別できなくなる。形式は次の構造化メモにする。

   ```text
   - <Today> done: <採用した結論 / 打ち切り理由を 1 行。triage スキャン用の見出し>
     - 経緯: <何をして解決したか。会話で辿った道筋を 1〜数行>
     - 学び: <その過程で得た知見・再利用できる教訓。無ければ省略>
   ```

   - 1 行目の `done:` 見出しは必ず残す（triage の先頭スキャン対象）。その下にネストで経緯・学びを足す。
   - 会話に根拠がある範囲だけ書く（捏造しない）。学び・経緯が会話から取れない場合（例: 文脈の薄い手動クローズ）は、`done:` の 1 行のみにフォールバックしてよい。曖昧なら決着理由をユーザーに聞き返す。
   - wrapup-dispatch から決着メモを渡された場合はそれを素材に整形する。直接 `/issue-tracker done` 実行時は直近の会話文脈から自前で抽出する。
4. `updated` を更新する。 frontmatter の `updated:` を Today に Edit する。
5. 移動する。 git 管理下（Current state の git repo が `true`）なら履歴を保つため `git mv` を使う。そうでなければ通常 `mv` にフォールバックする。

   ```bash
   git mv issues/inbox/<id>.md issues/done/<id>.md
   ```

6. 報告する。 移動結果と追記した決着理由を返す。

## Key Principles

1. 状態はディレクトリが単一の真実。 `inbox/` = 未完了、`done/` = 完了。frontmatter に status を持たせない（二重管理で不整合が出る）。
2. hold は inbox の中の「今はやらない」表明。 ディレクトリ状態は動かさず `tags: [hold]` で表現し、triage の推し候補から外れる。付与／解除は理由 1 行のログ（`hold:` / `unhold:`）とセット。done 化時は自動で unhold する（tags に hold を残さない）。
3. issue 間の参照は id で行う。 パスで参照すると done 移動でリンクが壊れる。`related:` には id を書く。
4. id は `YYYYMMDD-slug`、連番にしない。 日付プレフィックスで時系列ソートでき、次番号スキャンも不要。frontmatter の `created` / `updated` と `## ログ` に書く `<Today>` / `<date>` もすべて `YYYYMMDD` 形式で統一する（id の日付部分と同じ表記）。
5. TL;DR と結論は短く、調査本体は自由に長く。 前者は triage のスキャン対象、後者は記録。役割が違う。
6. done 化は決着メモとセット。 ログに決着メモ（`done:` の決着理由 1 行 + 経緯 + 学び）を残してから動かす。会話文脈が薄ければ決着理由 1 行にフォールバックしてよいが、空での done は不可。
7. 着手した issue は完了したら done へ接続する。 triage でピックアップ / 起票済みの issue に着手し、その作業がセッション内で片付いたら、明示依頼を待たず done を提案する（放置すると完了済みが inbox に残り triage 精度が落ちる）。部分完了なら done にせず `progress:` メモを残して inbox に継続する。
8. 索引は常設しない。 陳腐化するので triage 時にその場で生成する止まり。
9. Markdown スタイルは `~/.claude/rules/markdown-style.md` に従う。

## ディレクトリ構成

```text
issues/
├── inbox/                 # 未完了
│   └── 20260626-skill-status-design.md
├── done/                  # 完了
│   └── 20260620-foo.md
└── research/              # （任意）巨大化した調査ログの外出し先
    └── 20260626-skill-status-design.md
```
