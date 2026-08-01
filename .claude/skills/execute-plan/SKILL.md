---
name: execute-plan
description: >-
  承認済みプラン (`.claude/plans/`) を、タスクごとに fresh subagent で実装 → レビュー → コミット → 完了マークの順に進めるスキル。
  ユーザーが「プランを実行して」「実装を進めて」「プランの通り実装して」「execute-plan」と言ったとき、
  または Plan モードで ExitPlanMode 承認されたプランを実装フェーズに進めるときに使用する。
  ユーザーからの明示的な実行依頼がないまま起動した場合 (ExitPlanMode 承認後の自動継続など) のみ、最初に AskUserQuestion で実行確認してから進む。
allowed-tools:
  - Read
  - Bash(git status:*)
  - Bash(git log:*)
  - Bash(git diff:*)
  - Bash(git rev-parse:*)
  - Bash(git symbolic-ref:*)
  - Bash(git branch:*)
  - Bash(sed:*)
  - Bash(grep:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git checkout:*)
  - Bash(ls:*)
  - Bash(head:*)
  - Bash(echo:*)
  - TaskCreate
  - TaskUpdate
  - TaskList
  - TaskGet
  - AskUserQuestion
  - Agent
argument-hint: "[plan-file-path]"
---

# Execute Plan

承認済みプランを controller として読み込み、タスクごとに fresh subagent で実装 → レビュー → controller が直接コミット、を進めるスキル。

## Current state

base ブランチは `origin/HEAD` から解決する（取得できなければ `main` / `master` の存在で決める）。

- Branch: !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(not a git repository)"`
- Base branch: !`git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' | grep . || git branch --list --format='%(refname:short)' main master | head -1`
- Uncommitted changes: !`git status --porcelain 2>/dev/null | head -20`
- Available plans: !`ls -1t .claude/plans/ 2>/dev/null | head -20 || echo "no plans"`

## コア原則

- fresh subagent per task: タスクごとに新しい `Agent` を立て、controller の会話履歴を継承させない
- post-implementation review: 実装完了後に別の fresh subagent でレビュー (仕様適合 + 品質を 1 段で統合)
- continuous execution: タスク間で人に確認しない。停止は BLOCKED / 解消不能な ambiguity / 全タスク完了の 3 つに限る
- controller がコンテキストを curate: implementer に plan ファイルを読ませず、controller が必要な全文を prompt に貼って渡す

## ワークフロー

### Phase 1: プラン特定と読み込み

1. 実行確認 (ユーザーの明示依頼がない場合のみ): ユーザーが実行を明示的に依頼している場合 (`/execute-plan` スラッシュコマンド、または「プランを実行して」「実装を進めて」等の自然言語依頼) は確認せずに続行する。明示依頼がないまま起動した場合 (ExitPlanMode 承認後の自動継続など) のみ `AskUserQuestion` で「execute-plan で実行しますか？ (はい / いいえ)」を提示し、「いいえ」なら中止する。起動経路が判別できないときは安全側に倒して確認する
2. 引数でプランパスが渡されていればそれを使う
3. なければ Current state の Available plans (更新時刻の新しい順) を使う
   - 1 件 → それを使う
   - 複数 → `AskUserQuestion` で選択 (最新 4 件を選択肢として提示)
   - 0 件 → 「プランがありません」と報告して終了
4. `Read` でプラン全文を取得。冒頭が参照スタブマーカー (「このファイルは参照スタブ。実行対象: <パス>」) なら、指定された本体パスのプランへ読み替えて再取得する
5. プラン本文に `## 実装タスク` セクションがあるか確認
   - ない場合: `AskUserQuestion` で「実装タスクを追記してから再実行する」「このまま見出し / 番号付きリストから抽出を試みる」「中止」の 3 択を提示
6. プラン本文に `## 合意事項` セクションがあるか確認
   - ある場合: 全文を controller のメモリに保持する (Phase 2 チェックリストで使う)
   - ない場合: 合意事項なしのプラン (要約 + 実装タスク) でありインライン実装の対象である旨を明示し、`AskUserQuestion` で「このまま execute-plan で続行する」「中止してインライン実装に切り替える」を確認する (プランの形とセクション定義は `~/.claude/skills/write-plan/SKILL.md`)
   - 「続行する」を選んだ場合: 合意事項は存在しないものとして扱い、implementer / reviewer prompt の `[合意事項全文]` には固定文言 `(このプランは合意事項なし。合意事項との整合性は評価対象外)` を入れる。合意事項を推測して捏造しない
7. Branch が Base branch と同じ場合は `AskUserQuestion` で続行確認し、「はい」ならその場でフィーチャーブランチを作成 (`git checkout -b <内容を表す名前>`) してから継続する。「いいえ」なら中止する。これにより実装開始前にブランチを確定させ、以降のコミットは全てフィーチャーブランチ上で行う
8. 作業ツリーがクリーンか確認 (`## Current state` の `git status --porcelain` 出力を参照)。ただしプランファイル (`.claude/plans/` 配下。本体プラン・参照スタブとも) はこの判定から除外する。理由: write-plan の承認直後に execute-plan が起動される経路では、今から実行するプラン自身が untracked で作業ツリーに存在するのが正常であり、除外しないと必ず中止になる。プランファイルはどのタスクの対象ファイルにもならないので、パス限定のレビュー差分にも `git add` にも混入しない
   - プランファイル以外がクリーン → 続行
   - プランファイル以外に未コミット変更や untracked file がある → スキルを中止し、ユーザーに `git commit` か `git stash` でクリーンにしてから再実行するよう案内する。理由: タスクのレビュー差分 (直前コミット (HEAD) からのパス限定差分) に無関係な変更が混ざると reviewer が誤検出する / コミット時に意図しないファイルを巻き込むリスクがある
9. 権限モードの案内: 実装開始前に、acceptEdits モード (`shift+tab` で切替) への切り替えをユーザーに 1 度だけ案内する。理由: implementer subagent の Edit / Write が権限プロンプトで拒否されると自律実行が中断し、連続実行というスキルの狙いが崩れるため。案内後は返答を待たずに続行してよい (切り替えなくても実行は可能だが、Edit ごとに確認が発生しうる)

### Phase 2: タスク抽出と TaskList 作成

1. 抽出規則 (優先度順):
   - `## 実装タスク` 配下の `### Task N: ...` 見出し (推奨形式。詳細は `~/.claude/skills/write-plan/references/task-format.md` を参照)
   - `- [ ]` 形式の TaskList
   - 番号付きリスト (`1.`, `2.`, ...)
2. 各タスクから以下を controller のメモリに保持:
   - タスク全文 (本文をそのまま)
   - 目的 / 対象ファイル / 依存 / Acceptance criteria / Context (推奨形式の場合。詳細は `~/.claude/skills/write-plan/references/task-format.md` を参照)
   - 複雑度ヒント (対象ファイル数 / Context 長さ / criteria の主観性)
3. `TaskCreate` で抽出した各タスクを登録
4. 実行順とバッチを決める:
   - 依存が明示されているタスクは依存元の後に回し、それ以外はプラン記載順とする
   - この順に走査し、対象ファイルが互いに素かつ依存関係のないタスク群を 1 バッチにまとめる。対象ファイルが 1 つでも重なるタスク、依存関係のあるタスク、対象ファイルが特定できないタスクは同じバッチに入れず、単独バッチとする
   - Phase 3 はバッチ単位で処理する (1 件だけのバッチは逐次実行と同じ)

#### controller チェックリスト (Phase 3 へ渡す前)

各タスクの implementer / reviewer prompt を組み立てる前に、以下 2 点を controller のメモリに揃えておく (Phase 3 のステップ 2 / ステップ 4 で prompt に埋め込むため)。1 点目が欠けていると、implementer が合意事項を無視した実装をしても reviewer が検出できない。

- プランの `## 合意事項` セクションの全文を、implementer prompt の `[Context]` と reviewer prompt の `[合意事項全文]` に転記できる状態にしておく。要約・抜粋はしない。合意事項なしのプランで Phase 1 ステップ 6 の「続行する」を選んだ場合は、そこで定めた固定文言を代わりに使う。あわせて判断が本文へ散在していないかを 1 パスで確認する
- 対象リポの `CLAUDE.md` を「リポルート → 対象ファイルの各先祖ディレクトリ」の順に読む (`.claude/CLAUDE.md` があれば併せて確認)。monorepo の `packages/*/CLAUDE.md` などサブ階層に個別規約があれば、当該タスクに関係する検証項目 (例: 独自の命名規約、特定ディレクトリでのテスト必須ルール、コミット前に通すべきチェック) を抜粋し、implementer prompt の `[Context]` に含める。階層に CLAUDE.md が一つも無ければ、この項目自体を省略してよい

### Phase 3: タスクループ

Phase 2 で決めたバッチを順に処理する。1 バッチ内のタスク (対象ファイルが互いに素で依存関係がない) は implementer / reviewer を並列に起動してよい。対象ファイルが重なるタスクや依存関係のあるタスクは別バッチなので、結果として逐次に処理される。

並列実行時に守ること:

- 各 implementer prompt の `[Context]` に、同一バッチで並行実行している他タスクの対象ファイル一覧を渡し、担当外のファイルは読むだけで編集しないことを明示する
- reviewer に渡す差分は必ず `git diff [BASE_SHA] -- [TARGET_FILES]` のパス限定にする。同じツリーに他タスクの未コミット変更が同居するため、パス限定を外すと他タスクの変更を誤検出する
- `[BASE_SHA]` はバッチ開始時点の `git rev-parse HEAD` をバッチ内の全タスクで共有する (バッチ内の他タスクのコミットで base がずれると差分に他タスクの変更が混ざる)
- コミットは controller が APPROVED になったタスクから 1 件ずつ、`git add <対象ファイル>` のパス限定で行う (1 タスク = 1 コミット)

各バッチについて以下を行う。

1. バッチ選定: Phase 2 の順で次のバッチを取り、含まれる各タスクを `TaskUpdate(status=in_progress)`。`BASE_SHA` として `git rev-parse HEAD` を記録する
2. 実装: バッチ内の各タスクに implementer `Agent` を起動する (バッチ内は同時起動可)
   - `~/.claude/skills/execute-plan/references/implementer-prompt.md` をテンプレートとして使用 (プレースホルダー `[FULL TEXT of task]`, `[Context]`, `[Working directory]` を埋める)
   - `[Context]` には (a) 当該タスクの `対象ファイル` と `Context`、(b) `## 合意事項` 全文 (合意事項なしのプランなら Phase 1 ステップ 6 の固定文言)、(c) 対象リポ CLAUDE.md 由来の検証項目 (CLAUDE.md が無ければこの項目自体を省く)、(d) 並列実行時は他タスクの対象ファイル一覧 を含める。(b) と (c) は Phase 2 「controller チェックリスト」で用意したものを使う
   - `subagent_type=general-purpose`、`model` はタスク複雑度に応じて切替 (後述の「モデル選択方針」)
   - implementer は自分の対象ファイルのみ編集し、コミットはしない
3. implementer の報告を受けてタスクごとにステータス分岐 (後述の「ステータスハンドリング」)
4. レビュー: DONE / DONE_WITH_CONCERNS のタスクごとに reviewer `Agent` を起動する (バッチ内は同時起動可)
   - `~/.claude/skills/execute-plan/references/reviewer-prompt.md` をテンプレートとして使用
   - プレースホルダー `[FULL TEXT of task]`, `[Acceptance criteria]`, `[合意事項全文]`, `[implementer report]`, `[BASE_SHA]` (= ステップ 1 で記録した SHA), `[TARGET_FILES]` (= 当該タスクの対象ファイル) を埋める
   - `[合意事項全文]` にはプランの `## 合意事項` を丸ごと転記する (合意事項なしのプランなら Phase 1 ステップ 6 の固定文言。reviewer 側でこの観点がスキップされる)。空のまま渡すと reviewer が「プラン合意事項との整合性」観点をレビューできない
   - `subagent_type=general-purpose`、`model=opus` 固定 (`plan-reviewer` エージェントはプランのレビュー用で、実装差分のレビューには使わない)
   - レビューは `git diff [BASE_SHA] -- [TARGET_FILES]` のパス限定・未コミット差分で行う
5. レビュー結果分岐 (タスクごと):
   - APPROVED → ステップ 6 のコミットへ進む
   - NEEDS_CHANGES → 指摘を fresh implementer に再委譲 (同じ Agent ではなく fresh で起動。指摘内容を `[Context]` に追記)。再レビューは最大 2 ループまで、3 回目到達で「エスカレーション」フローへ
6. コミット: APPROVED になったタスクを controller が直接コミットする。バッチ内に複数あれば 1 件ずつ順にコミットする
   - Phase 1 ステップ 7 で既にフィーチャーブランチ上にいることを前提とする
   - 当該タスクの対象ファイルのみを `git add <対象ファイル>` して `git commit` (1 タスク = 1 コミット)
   - `git add` は対象ファイルのみを stage するため、implementer が誤って対象外ファイルを変更しても、また同一バッチの他タスクが未コミットで同居していても、コミットには入らない
7. コミットしたタスクを `TaskUpdate(status=completed)`
8. バッチ後チェック: バッチ内全タスクの対象ファイル以外に未コミット変更が残っていないか `git status --porcelain` で確認し、あればスコープ逸脱としてユーザーに報告する。Phase 1 ステップ 8 と同じくプランファイル (`.claude/plans/` 配下) は除外する
9. 残バッチがあれば次のバッチへ (ステップ 1 に戻る)

#### pre-commit hook fail 時の扱い

ステップ 6 の `git commit` で pre-commit hook (`.pre-commit-config.yaml` / husky / lint-staged 等) が fail した場合は、その commit を諦めて `NEEDS_CHANGES` 相当の扱いに切り替える。具体的には:

- hook の stderr / stdout を Context として抜粋する (どのファイルの何が引っ掛かったか)
- 当該タスクを fresh implementer に再委譲する (ステップ 5 の NEEDS_CHANGES 再委譲と同じフローに乗せる)
- 抜粋した hook エラーは implementer prompt の `[Context]` に追記する
- hook が示している問題は必ず implementer に fix させる (`--no-verify` で skip して commit を通さない)
- hook fail はレビューループ回数のカウントに含める (再委譲 2 回超過でエスカレーション)

hook fail が発生する主因は、implementer の self-check が対象リポの hook を回していないこと。`~/.claude/skills/execute-plan/references/implementer-prompt.md` の「lint / hook self-check」で `~/.claude/skills/execute-plan/references/lint-per-language.md` に沿った検出・実行が徹底されていれば、この分岐に来る頻度は下がる。

### Phase 4: 完了報告

全タスク完了後:

- 変更ファイル数とコミット数を `git log` / `git diff` で確認
- 1〜2 文のサマリを出力 (例: 「3 タスク完了。5 ファイル変更、3 コミット作成」)
- `TaskList` で全タスクの最終ステータスを取得し (個別の詳細が要るときは `TaskGet`)、未完タスクがあれば一覧で報告する。内訳は、エスカレーションでスキップした `deleted`、着手前に停止して `pending` のまま残ったもの、バッチ処理中に停止して `in_progress` のまま残ったものの 3 種
- PR の作成に進む場合は `pr-merge` スキルを使うようユーザーに案内する

最終全体レビューは実施しない (タスクごとの 1 段レビューで担保)。

## ステータスハンドリング

implementer subagent は 4 種の status で報告する。

| Status | 対応 |
| -- | -- |
| `DONE` | レビュー段階へ進む |
| `DONE_WITH_CONCERNS` | 懸念を読み、影響なければレビュー段階へ。影響あれば fresh implementer に修正委譲 |
| `NEEDS_CONTEXT` | 不足コンテキストを controller が補完して fresh で再委譲 |
| `BLOCKED` | 「エスカレーション」フローへ |

## エスカレーション

修正ループ 2 回超過時、または `BLOCKED` 報告時は、`AskUserQuestion` で 3 択をユーザーに提示する。

1. 追加指示を与えて再試行 (ユーザー入力を `[Context]` に追記して fresh で再委譲)
2. 当該タスクをスキップして次へ (`TaskUpdate(status=deleted)`、状況をログ出力。Phase 4 では未完タスクとして一覧に載せる)
3. スキル全体を停止 (残タスクを `pending` のまま終了し、Phase 4 のサマリで未完一覧を出力)

## モデル選択方針

`Agent` 呼び出しの `model` パラメータで切替える。`haiku` は本スキルでは使用しない。

| ロール | 既定モデル | 切替条件 |
| -- | -- | -- |
| controller (本スキル本体) | セッション継承 | 切替しない |
| implementer (通常タスク) | `sonnet` | 明確な仕様、リファクタ、パターン照合、デバッグ |
| implementer (設計判断) | `opus` | 設計判断、広範な理解、Context 長大 |
| reviewer | `opus` | 常に固定 |

複雑度判定は controller がプランの `対象ファイル` の数、`Context` の長さ、`Acceptance criteria` の主観性で行う。プラン内に明示的な複雑度ヒントがあれば優先する。

## References

- `~/.claude/skills/execute-plan/references/implementer-prompt.md`: implementer subagent 用テンプレート
- `~/.claude/skills/execute-plan/references/reviewer-prompt.md`: reviewer subagent 用テンプレート (仕様適合 + 品質統合版)
- `~/.claude/skills/execute-plan/references/lint-per-language.md`: implementer が「lint / hook self-check」で参照する言語別の判定・実行コマンド (Python / TypeScript・JavaScript を収録)
- `~/.claude/skills/write-plan/references/task-format.md`: 実装タスクの記述形式 (controller 側の抽出規則はこの形式に従う)
