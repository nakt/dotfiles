---
name: issue-tracker
description: 調査・検討の結果を 1 ファイル 1 件の Markdown issue として起票し、未完了 issue の棚卸し（一覧・優先度づけ・ピックアップ）と done 化を行うスキル。1 issue = 1 ファイル、ステータスは inbox / done のディレクトリ 2 値のみで表現する。手動 `/issue-tracker` 専用。「この調査結果を issue で起票して」「未完了の issue を棚卸しして優先度が高そうなものをピックアップ」「issue-xxxx を done にして」のように明示的に呼ばれたときだけ動く。GitHub issue の操作（gh issue / API）には使わない。
disable-model-invocation: true
argument-hint: "[create|triage|done <id>] または自然文の依頼"
allowed-tools: Read(*), Glob(*), Grep(*), Write(*), Edit(*), Bash(ls:*), Bash(cat:*), Bash(test:*), Bash(date:*), Bash(mkdir:*), Bash(git mv:*), Bash(git rev-parse:*), Bash(mv:*)
---

# Issue Tracker

調査・検討の結果を、後から棚卸しできる形で `issues/` に蓄積する。1 件 = 1 ファイル。状態はディレクトリ（`inbox/` 未完了 / `done/` 完了）で表し、frontmatter には status を持たせない。これは二重管理による不整合を避けるためで、ディレクトリが状態の単一の真実になる。

## Current state

- issues/ exists: !`test -d issues && echo 'yes' || echo 'no'`
- inbox: !`ls issues/inbox/ 2>/dev/null || echo '(none)'`
- done: !`ls issues/done/ 2>/dev/null || echo '(none)'`
- git repo: !`git rev-parse --is-inside-work-tree 2>/dev/null || echo 'no'`
- Today: !`date +%Y-%m-%d`

## モード判定

ユーザーの依頼文（または引数）から、次の 3 モードのどれかを選ぶ。複数該当する場合は依頼の主目的を優先する。

- create（起票）: 「issue で起票」「issue にしておいて」「記録して」など、直前の調査・検討結果を残す依頼。
- triage（棚卸し / pickup）: 「一覧」「棚卸し」「優先度」「ピックアップ」「どれからやる」など、未完了 issue を見渡して選ぶ依頼。
- done（クローズ）: 「done にして」「クローズ」「片付いた」+ 対象 id を伴う依頼。

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
4. テンプレートから生成する。 `~/.claude/skills/issue-tracker/templates/issue-template.md` を Read し、`{id}` `{title}` `{created}` `{updated}` を埋めて `issues/inbox/<id>.md` として Write する。`created` と `updated` は Today。
   - TL;DR と「結論 / プラン」は短く保つ。 ここは triage で各ファイル先頭だけ読むときのスキャン対象。長文は「調査結果」節に置く。
   - 調査結果は長くてよい。 自由にネストしてよい。「事実」と「そこからの解釈」を分けて書くと後から読み返しやすい。
   - priority は分かっていれば入れる。不明なら空のままでよい（triage 側で推定される）。
5. 報告する。 作成パスと TL;DR を 1〜2 行で返す。

## triage（棚卸し / pickup）

`issues/inbox/` の未完了を見渡し、優先度の高そうなものを選ぶ。ファイルは作らない。チャット上に結果を返す。

1. 一覧を取る。 Current state の inbox で件数を把握する。各ファイルの先頭（frontmatter + TL;DR）を読む。全文は読まない（スキャンが目的）。
   - inbox が空（`(none)`）なら「未完了 issue は無い」と伝えて終わる。done しか無い場合も同様。
2. 優先度を決める。
   - frontmatter に `priority: high|med|low` が明示されていれば、それを最優先で採用する。
   - 明示が無いものは、TL;DR / tags / `created` からの経過日数 / 「未解決の論点」の多さ などから Claude が推定する。
   - 推定したものには 「なぜ高い（低い）と判断したか」を一言添える。明示 priority との区別がつくように、推定であることが分かる書き方にする。
3. 提示する。 候補一覧（id / title / priority とその判定根拠）を出し、最後に「推し」を 1〜数件、理由つきで挙げる。索引を常設ファイルにはしない。

## done（クローズ）

調査が決着した issue を `done/` へ移す。

1. 対象 id を確定する。 引数や依頼文の id を使う。曖昧なら inbox を一覧して確認する。
2. 決着理由をログに追記する（必須）。 mv の前に、対象ファイルの「## ログ」節末尾へ `- <Today> done: <採用した結論 / 打ち切り理由を 1 行>` を Edit で追記する。これが無いと「調査だけして放置」と「決着して完了」が区別できなくなる。
3. `updated` を更新する。 frontmatter の `updated:` を Today に Edit する。
4. 移動する。 git 管理下（Current state の git repo が `true`）なら履歴を保つため `git mv` を使う。そうでなければ通常 `mv` にフォールバックする。

   ```bash
   git mv issues/inbox/<id>.md issues/done/<id>.md
   ```

5. 報告する。 移動結果と追記した決着理由を返す。

## Key Principles

1. 状態はディレクトリが単一の真実。 `inbox/` = 未完了、`done/` = 完了。frontmatter に status を持たせない（二重管理で不整合が出る）。
2. issue 間の参照は id で行う。 パスで参照すると done 移動でリンクが壊れる。`related:` には id を書く。
3. id は `YYYYMMDD-slug`、連番にしない。 日付プレフィックスで時系列ソートでき、次番号スキャンも不要。
4. TL;DR と結論は短く、調査本体は自由に長く。 前者は triage のスキャン対象、後者は記録。役割が違う。
5. done 化は理由とセット。 ログに 1 行の決着理由を残してから動かす。
6. 索引は常設しない。 陳腐化するので triage 時にその場で生成する止まり。
7. Markdown スタイルは `~/.claude/rules/markdown-style.md` に従う。

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
