---
name: issue-tracker
description: 調査・検討の結果や、作業中に見つけた不具合・課題・TODO を Markdown issue として `issues/` に起票し、未完了 issue の棚卸し（一覧・優先度づけ・ピックアップ）と done 化を行うスキル。「この調査結果を issue で起票して」「未完了の issue を棚卸しして優先度が高そうなものをピックアップ」「issue-xxxx を done にして」のような依頼で使う。加えて「issue に着手する」「次のタスクを取って」「いま何を持っているか」のような着手・claim の依頼にも使う。また、このセッションで着手した issue の作業が片付いた場面では、明示依頼が無くても done 化の提案・実行に使う。GitHub issue の操作（gh issue / API）には使わない。
argument-hint: "[create|triage|claim|done <id>] または自然文の依頼"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Bash(uv run --script ~/.claude/skills/issue-tracker/scripts/it.py:*)
  - Bash(date:*)
---

# Issue Tracker

調査・検討の結果を、後から棚卸しできる形で `issues/` に蓄積する。1 件 = 1 ファイル。状態はディレクトリ（`inbox/` 未着手 / `wip/` 着手中 / `done/` 完了）で表し、frontmatter には status を持たせない。これは二重管理による不整合を避けるためで、ディレクトリが状態の単一の真実になる。

ただし `wip/` の issue に限り、frontmatter に `owner` と `claimed_at` を持つ。これは状態ではなく「誰がいつ着手したか」であり、ディレクトリでは表現できないため二重管理には当たらない。

ファイル操作・スキャン・frontmatter の更新は `it.py` に委譲する。移動は原子的に行われるので、複数のエージェントが同じ issue を同時に取ることはない。判断（何を起票するか、どれが優先か、完了したか、メモに何を書くか）はこのスキル側で行う。

## Current state

- issues: !`uv run --script ~/.claude/skills/issue-tracker/scripts/it.py path 2>&1`
- 一覧: !`uv run --script ~/.claude/skills/issue-tracker/scripts/it.py list --include-hold 2>&1`
- Today: !`date +%Y%m%d`

一覧は各 issue の frontmatter と TL;DR 1 行だけを返す。既定で wip → inbox の順に並び、done は含まない（done を見るときだけ `--status done` を明示する）。`@<owner>` が付いているものが着手中、`[hold]` が付いているものが保留。issues 行に「見つかりません」と出ていれば `issues/` は未作成。

## it の呼び出し

- 実行するコマンドは常に `uv run --script ~/.claude/skills/issue-tracker/scripts/it.py <サブコマンド>` の完全形で書く。 以下の説明文に出てくる `it` はこの完全形の略記で、そのまま実行しない。Bash の許可はコマンド文字列の前方一致で判定されるため、略記や `cd ... &&` のような前置きを付けると許可にマッチせず毎回確認を求められる。
- 長い散文（本文・完了メモ・ログ）は引数ではなく標準入力で渡す。 ヒアドキュメントの区切りは必ずクォートする（`<<'EOF'`）。issue の本文にはバッククォートや `$` が入るため、クォートしないとシェルが展開する。
- issue の移動を伴う操作（`claim` / `release` / `done` / `reap`）の後は、コミット時に `git add -A issues/` で移動元の削除と移動先の追加を対にしてステージする。 `commit` スキルは `git status --short` を見て選択的にステージするため、対にしないと片方だけがコミットに乗る。`claim` と `done` は同じ案内を標準エラーに出す（`--json` 出力を壊さないため。出力例を採るときは `2>&1` が要る）。このスキル自身は git を実行しない。
- `it` は判断をしない。 何を起票するか・どれが優先か・完了したか・メモに何を書くかは、すべてこのスキルが決めて渡す。

## モード判定

ユーザーの依頼文（または引数）から、次の 4 モードのどれかを選ぶ。複数該当する場合は依頼の主目的を優先する。

- create（起票）: 「issue で起票」「issue にしておいて」「記録して」など、直前の調査・検討結果を残す依頼。1 件でも複数件でも同じモードで扱う（brainstorm の「スコープ外にしたもの」や wrapup-dispatch の一括委譲のように、複数テーマがまとめて渡されることがある）。
- triage（棚卸し / pickup）: 「一覧」「棚卸し」「優先度」「ピックアップ」「どれからやる」など、未完了 issue を見渡して選ぶ依頼。tags に `hold` が入っているものは通常候補から外し、末尾の `## hold 中` セクションに分離する（下記「hold（保留）」参照）。
- claim（着手）: 「着手する」「次のタスクを取って」「これをやる」「いま何を持っているか」など、inbox の issue を手元に取る／取っているものを確認する依頼。
- done（クローズ）: 「done にして」「クローズ」「片付いた」+ 対象 id を伴う依頼。加えて、triage で取り上げた（または起票済みの）issue に着手し、その作業がこのセッション内で片付いたときは、明示依頼が無くても done を提案・実行する（下記「着手 → 完了（done への接続）」を参照）。

`issues/` が未作成（Current state の issues 行が「見つかりません」）で create を行う場合は、先に下記「初期化」を済ませる。triage / claim / done で `issues/` が無ければ、その旨を伝えて終わる（起票がまだ無いだけなので何も作らない）。

## 初期化

`issues/` が無い状態で create するときだけ、ディレクトリを用意する。

```bash
uv run --script ~/.claude/skills/issue-tracker/scripts/it.py init
```

カレントディレクトリに `issues/{inbox,wip,done}` を作る。上位への遡り探索を打ち切ってカレントに作るのが要点で、そうしないと親に `issues/` があるとき別の場所を掴む。上位にも `issues/` があれば警告が出るので、置き場所が意図どおりか確認する。

`issues/research/` は調査ログが巨大化したとき初めて作る。最初から空ディレクトリは作らない。索引ファイル（`issues/README.md` 等）は常設しない（陳腐化するため。必要時に triage でその場生成するに留める）。

## create（起票）

直前の調査・検討結果を `issues/inbox/` に保存する。1 テーマ = 1 ファイルで、複数テーマが渡された場合も 1 回の create でまとめて処理する。

1. 起票対象を洗い出す。 直前の会話に起票すべき調査・検討の中身があるか見て、独立して着手できるテーマ単位に分ける。テーマが複数あれば「どれを起票するか」の一覧（各 1 行サマリ）を先に提示して合意を取る。無い／曖昧なら「何を issue にするか」を聞き返してから進む。空の issue を作らない。1 テーマを無理に分割せず、逆に無関係な複数テーマを 1 ファイルに詰め込まない。
2. テーマごとに起票する。 1 テーマ = 1 コマンド。id の採番（`YYYYMMDD-slug`）、slug の正規化、同日同 slug の衝突回避（`-2`, `-3` の付与）、テンプレートの展開は `it new` が行うので、決めるのは slug とタイトルと本文だけ。

   ```bash
   uv run --script ~/.claude/skills/issue-tracker/scripts/it.py new <slug> --title "<title>" --body <<'EOF'
   <本文>
   EOF
   ```

   - slug は内容を表す短い kebab-case（英小文字・ハイフン）にする。 日付プレフィックスと連番は `it new` が付けるので、slug 側に日付や番号を入れない。
   - 本文はテンプレートと同じ節構成で書く。 節は `## TL;DR`、`## 背景 / 問い`、`## 調査結果`、`## 結論 / プラン`、`## 未解決の論点 / リスク` の順。`## ログ` は書かなくてよい（`- <Today> created` とともに末尾へ自動で補われる）。`--body` を省略するとテンプレートの本文（プレースホルダのコメント）がそのまま残る。
   - TL;DR と「結論 / プラン」は短く保つ。 ここは triage でスキャンされる対象。長文は「調査結果」節に置く。
   - 調査結果は長くてよい。 自由にネストしてよい。「事実」と「そこからの解釈」を分けて書くと後から読み返しやすい。
   - priority は分かっていれば `--body` の前に `--priority high|med|low` を足す。 不明なら付けない（triage 側で推定される）。
   - related は他 issue への参照が要る場合のみ id で書く。 パスで参照すると done 移動でリンクが壊れるため（`related: []` はテンプレート既定）。同じバッチで起票した issue 同士に依存関係があるときも、パスではなく id で相互参照する。書き方は下記「更新の作法」を参照。
3. 報告する。 1 件なら作成パスと TL;DR を 1〜2 行で返す。複数件なら `- <パス>: <TL;DR 1 行>` の箇条書きで全件を列挙し、末尾に件数を添える。

## triage（棚卸し / pickup）

`issues/inbox/` の未着手を見渡し、優先度の高そうなものを選ぶ。ファイルは作らない。チャット上に結果を返す。

1. 一覧を取る。 各ファイルを開かずに 1 コマンドで済ませる（スキャンが目的なので全文は読まない）。

   ```bash
   uv run --script ~/.claude/skills/issue-tracker/scripts/it.py list --status inbox --json
   ```

   返るのは id / status / title / priority / tags / hold / owner / claimed_at / created / updated / TL;DR 1 行 / path。
   - inbox が空配列なら、Current state の wip 行だけ添えて「未着手の issue は無い」と伝えて終わる。done しか無い場合も同様。
   - wip の状況も併せて報告する。 Current state の一覧が wip を先頭に `@<owner>` 付きで並べているので、着手中のものはそこから拾う。見落とすと、すでに誰かが持っている issue を重ねて推すことになる。
2. hold を分離する。 tags に `hold` を持つ issue は通常候補集合から除外する。`priority: high` が付いていても hold なら候補外。手順 1 の `it list` は inbox の hold を既定で落とすので、その出力がそのまま候補集合になる。hold 群はそちらには出てこないので、`--include-hold` を足してもう一度取り、`hold: true` のものを手順 4 の末尾で別セクションに出す。

   ```bash
   uv run --script ~/.claude/skills/issue-tracker/scripts/it.py list --status inbox --json --include-hold
   ```

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

     理由は一覧には載らないので、hold 付きの issue に限って `## ログ` を Read し、最新（末尾）の `hold:` 行から取る。抽出できなければ理由部分は省略する。hold 付きが 0 件ならセクション自体を出さない。

## hold（保留）

「今はやらない」を tags で表明する運用。ディレクトリは動かさず `inbox/` のまま残す。triage の推しノイズを減らすためのもので、単なる後回し（`priority: low`）とは区別する。

- 判定基準: 外部依存待ち / 方針保留 / 優先度が本気で不明 / セッション外の要因待ち、など。次に動かせる目処が立っていないものを hold にする。
- 前提: hold は既存 issue にのみ後付けする。 create と同時に hold を付ける運用はしない（手順・ログを分離するため）。起票して間もなく保留したい場合も、まず create を通常通り完了させ、続けて別操作で hold を付ける。
- 呼び出し: 自然文（「issue-xxxx を hold にして」「hold を外して」など）で反応する。新モードは追加しない。`/issue-tracker hold <id>` のように引数で直叩きされた場合も自然文相当として受け付ける。

### 付与手順

1. 対象 id を確定する。 引数や依頼文の id を使う。曖昧なら Current state の一覧で確認する。
2. tag を付け、理由をログに残す（理由は必須）。

   ```bash
   uv run --script ~/.claude/skills/issue-tracker/scripts/it.py set <id> --add-tag hold
   uv run --script ~/.claude/skills/issue-tracker/scripts/it.py log <id> "hold: <なぜ今動かさないか 1 行>"
   ```

### 解除手順

1. 対象 id を確定する。
2. tag を外し、再開の契機をログに残す（理由は必須）。

   ```bash
   uv run --script ~/.claude/skills/issue-tracker/scripts/it.py set <id> --rm-tag hold
   uv run --script ~/.claude/skills/issue-tracker/scripts/it.py log <id> "unhold: <再開する理由・きっかけ 1 行>"
   ```

`it log` は行頭の日付を自動で付けるので、`- <Today>` を自分で書かない。`updated` も `it set` / `it log` が自動で更新する。

done との違い: hold は「未完了だが今は動かさない」。完了したなら hold ではなく done を使う（`it done` が hold との併存を自動でほどく）。

## claim（着手）

inbox の issue を `wip/` へ移して手元に取る。移動そのものが排他になるので、同じ issue を 2 つのエージェントが同時に取ることはない。

- 対象が決まっている場合（triage で選んだ、id を指定された）は `--id` で指定する。

  ```bash
  uv run --script ~/.claude/skills/issue-tracker/scripts/it.py claim --id <id>
  ```

- 「次のタスクを取って」のように対象が決まっていない場合は `--id` を省く。優先度順に自動で選ぶ。競合して負けた場合はスクリプト側が次の候補に回るので、リトライを書かない。

  ```bash
  uv run --script ~/.claude/skills/issue-tracker/scripts/it.py claim
  ```

- 「いま何を持っているか」を聞かれた場合は、Current state の一覧の wip 行（`@<owner>` 付き）から答える。コマンドを追加で叩かない。

`--agent` は省略してよい（`$IT_AGENT`、無ければ作業ディレクトリ名が入る）。claim すると `## ログ` に `- <Today> claim: <owner>` が自動で追記される。

着手をやめて inbox に戻すときは release を使う。hold と同じく自然文で反応し、新モードは追加しない。

```bash
uv run --script ~/.claude/skills/issue-tracker/scripts/it.py release <id> --reason "<1 行>"
```

## 着手 → 完了（done への接続）

triage でピックアップした issue や、create で残しておいた issue に実際に取り掛かるときは、まず上記 claim で `wip/` へ移す。その作業がこのセッション内で片付いたら、ユーザーからの明示的な「done にして」を待たずに done 化を提案する。放置すると完了済みの issue が inbox / wip に残り、triage の精度が落ちるため。

- 判断。 会話文脈から、その issue の狙いが満たされ追加の残作業が無いと確認できたら「この issue は done にできそう」と一言添える。
- 実行。 ユーザーが同意している（または元々 done 前提で着手していた）なら、下記 done 手順を実行する。判断が曖昧なら勝手に動かさず確認する。
- 部分完了。 issue 全体が完了していないなら done にはせず、進捗メモだけ残して `wip/` に置いたままにする。進捗メモは done の完了メモ（`done:` プレフィックス）と triage スキャン上で取り違えないよう、`progress:` のプレフィックス付きで残す。

  ```bash
  uv run --script ~/.claude/skills/issue-tracker/scripts/it.py log <id> "progress: <途中経過を 1 行>"
  ```

  しばらく触らない見込みなら、上記 release で inbox に戻す。

## done（クローズ）

完了した issue を `done/YYYY-MM/` へ移す。複数 id が渡された場合は、id ごとに手順 2 を繰り返し、報告（手順 3）だけまとめて 1 回で行う。

1. 対象 id を確定する。 引数や依頼文の id を使う。複数指定されていれば全件を対象リストにする。曖昧なら Current state の一覧で確認する。
2. 完了メモを渡して閉じる。 `inbox/` からでも `wip/` からでも同じ。

   ```bash
   uv run --script ~/.claude/skills/issue-tracker/scripts/it.py done <id> --note <<'EOF'
   <採用した結論 / 打ち切り理由を 1 行。triage スキャン用の要約>
   - 経緯: <何をして解決したか。会話で辿った道筋を 1〜数行>
   - 学び: <その過程で得た知見・再利用できる教訓。無ければ省略>
   EOF
   ```

   この 1 コマンドが、完了メモを `## 完了メモ` 節に書き、`## ログ` へ `- <Today> done: <メモの 1 行目>` を追記し、`hold` タグが付いていれば外し（`- <Today> unhold: done に向けて解除` が残る）、`owner` / `claimed_at` を落とし、`updated` を今日にして移動まで行う。記録と移動を別コマンドにすると「メモは書いたが移動していない」状態が残りうるので 1 回に寄せてある。
   - 1 行目は必ず書く。 これがログの `done:` 行に転記され、triage の先頭スキャン対象になる。`- <Today> done:` のプレフィックスは `it done` が付けるので、メモ側には書かない。
   - その下にネストで経緯・学びを足す。 会話に根拠がある範囲だけ書く（捏造しない）。学び・経緯が会話から取れない場合（例: 文脈の薄い手動クローズ）は、1 行目のみにフォールバックしてよい。曖昧なら完了理由をユーザーに聞き返す。
   - `--note` は原則付ける。 省いてもログに `- <Today> done` の 1 行は残るが、それだけでは「調査だけして放置」と「完了」が区別できなくなる。
   - wrapup-dispatch から完了メモを渡された場合はそれを素材に整形する。直接 `/issue-tracker done` 実行時は直近の会話文脈から自前で抽出する。
3. 報告する。 移動結果と完了理由を返す。複数件なら `- <移動後のパス>: <完了理由 1 行>` の箇条書きで全件を列挙する。

## 更新の作法

構造化フィールドの frontmatter を `Edit` で直接書き換えない。 インデントずれや `---` の重複でスクリプト側が読めなくなり、triage で初めて気付くことになる。構造化フィールド（`title` / `priority` / `tags`）の書き換えは必ず `it set` を通す。

```bash
uv run --script ~/.claude/skills/issue-tracker/scripts/it.py set <id> --priority high
uv run --script ~/.claude/skills/issue-tracker/scripts/it.py set <id> --add-tag hold --rm-tag blocked
uv run --script ~/.claude/skills/issue-tracker/scripts/it.py set <id> --title "<新しいタイトル>"
```

- `it set` がキー行を書き換えると、その行の行末コメント（テンプレート由来の説明）は失われる。 これは既知の挙動で、値そのものは保たれる。
- `priority` を YAML のブロック形式（`priority:` の次行にインデント付きの `- high` を置く形）で書かない。 `it check` が不正値として弾く。取りうる値は `high` / `med` / `low` か空のいずれか。
- `it set` が扱わないフィールド（`related` / `sources`）を書くときだけ、その行を `Edit` でインライン形式のまま差し替える（`related: [<id>, <id>]`）。 行を増やさず、書き換えた後に `it check` を通す。`it check` が見るのは frontmatter の構造だけで、`related` に書いた id が実在するかは検証しない。

本文への追記も、定型のものはサブコマンドを使う。 長い散文は標準入力で渡す。

```bash
uv run --script ~/.claude/skills/issue-tracker/scripts/it.py log <id> "<1 行>"
uv run --script ~/.claude/skills/issue-tracker/scripts/it.py note <id> "調査結果" "<本文>"
uv run --script ~/.claude/skills/issue-tracker/scripts/it.py note <id> "結論 / プラン" --replace <<'EOF'
<本文>
EOF
```

- `it log` は `## ログ` に日付つきで 1 行追記する。`it note` は指定した節に追記し、`--replace` で差し替える。節が無ければ末尾に作る。
- `updated` はこれらすべてが自動で更新するので、手で書き換える手順は不要。
- `Edit` を使ってよいのは、既存 issue の本文を部分的に直す場面だけ。 起票は `it new --body` で完結するので、起票直後に本文を書き足す手順は無い。
- 既知の制約: `it note` / `it log` は節の境界を探すとき、コードフェンス（3 連バッククォート）の中の見出し行（`##` で始まる行）を見分けない。 本文にコードブロックがあり、その中に見出し行があると境界を誤認する。該当する issue では `Edit` で直接直す。

作業前後の健全性は `it check` で確認できる。

```bash
uv run --script ~/.claude/skills/issue-tracker/scripts/it.py check
```

`id` / `title` / `created` の欠損、id とファイル名の不一致、不正な priority / tag、`owner` の無い `wip/`、`wip/` 以外に残った `owner` / `claimed_at` を検出する。異常があれば該当行を並べて異常終了する。

## reap（放置された着手の回収）

エージェントが落ちたり、着手したまま忘れられた issue は `wip/` に残り続け、他のエージェントが取れなくなる。一定時間動きが無いものを inbox に戻す。

```bash
uv run --script ~/.claude/skills/issue-tracker/scripts/it.py reap --stale 60m --dry-run
uv run --script ~/.claude/skills/issue-tracker/scripts/it.py reap --stale 60m
```

- 放置の判定は `claimed_at` と mtime の遅いほうからの経過で行う。`it log` で進捗を書き続けていれば回収されない。
- 戻した issue には `- <Today> reap: ...` がログに残るので、なぜ inbox に戻っているかが後から分かる。
- 単独作業では、triage の前に `--dry-run` で確認する程度でよい。多数のエージェントを常時回す環境では定期実行する。
- 排他が効く範囲は「同一の作業ディレクトリの `issues/` を見ているエージェント同士」に限る。 worktree を分けると `issues/` も別実体になるので、worktree 間では claim も reap も互いに干渉しない。

## ディレクトリ構成

```text
issues/                    # レポジトリの追跡下
├── inbox/                 # 未着手
│   └── 20260626-skill-status-design.md
├── wip/                   # 着手中（owner / claimed_at を持つ）
│   └── 20260901-foo.md
├── done/                  # 完了（年月で分割）
│   └── 2026-09/
│       └── 20260620-bar.md
└── research/              # （任意）巨大化した調査ログの外出し先
    └── 20260626-skill-status-design.md
```
