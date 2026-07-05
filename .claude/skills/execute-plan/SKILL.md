---
name: execute-plan
description: >-
  承認済みプラン (`.claude/plans/*.md`) を、タスクごとに fresh subagent で実装 → レビュー → コミット → 完了マークの連続実行で進めるスキル。
  ユーザーが「プランを実行して」「実装を進めて」「プランの通り実装して」「execute-plan」と言ったとき、
  または Plan モードで ExitPlanMode 承認されたプランを実装フェーズに進めるときに使用する。
  モデルが自動起動した場合は、最初に AskUserQuestion で実行確認してから進む。
allowed-tools:
  - Read
  - Glob
  - Bash(git status:*)
  - Bash(git log:*)
  - Bash(git branch:*)
  - Bash(git diff:*)
  - Bash(git rev-parse:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git checkout:*)
  - TaskCreate
  - TaskUpdate
  - TaskList
  - TaskGet
  - AskUserQuestion
  - Agent
argument-hint: "[plan-file-path]"
---

# Execute Plan

承認済みプランを controller として読み込み、タスクごとに fresh subagent で実装 → レビュー → controller が直接コミット、を連続実行するスキル。

## Current state

- Branch: !`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(not a git repository)"`
- Uncommitted changes: !`git status --porcelain 2>/dev/null | head -20`
- Available plans: !`ls -1t .claude/plans/ 2>/dev/null | head -10 || echo "no plans"`

## コア原則

- fresh subagent per task: タスクごとに新しい `Agent` を立て、controller の会話履歴を継承させない
- post-implementation review: 実装完了後に別の fresh subagent でレビュー (仕様適合 + 品質を 1 段で統合)
- continuous execution: タスク間で人に確認しない。停止は BLOCKED / 解消不能な ambiguity / 全タスク完了の 3 つに限る
- controller がコンテキストを curate: implementer に plan ファイルを読ませず、controller が必要な全文を prompt に貼って渡す
- 委譲の切り分けは `.claude/rules/subagent-delegation.md` に従う: 実装は fresh subagent に散らすが、implementer / reviewer は判断寄りロールなので物差し (Acceptance criteria・レビュー観点) を必ず渡す。設計採否など複数の妥当な選択肢がある判断は subagent に決めさせず controller / ユーザーへエスカレーションさせる (判断は親が握る)

## ワークフロー

### Phase 1: プラン特定と読み込み

1. 実行確認 (自動起動時のみ): 本スキルがユーザーの `/execute-plan` スラッシュコマンド以外 (ExitPlanMode 承認後の自動継続、または「実装を進めて」等の自然言語依頼) で起動された場合、`AskUserQuestion` で「execute-plan で実行しますか？ (はい / いいえ)」を提示し、「いいえ」なら中止する。`/execute-plan` のスラッシュコマンド起動と確定できる場合のみこの確認をスキップする (起動経路が判別できないときは安全側に倒して確認する)
2. 引数でプランパスが渡されていればそれを使う
3. なければ `.claude/plans/` を `Glob` で列挙
   - 1 件 → それを使う
   - 複数 → `AskUserQuestion` で選択 (最新 4 件を選択肢として提示)
   - 0 件 → 「プランがありません」と報告して終了
4. `Read` でプラン全文を取得
5. プラン本文に `## 実装タスク` セクションがあるか確認
   - ない場合: `AskUserQuestion` で「実装タスクを追記してから再実行する」「このまま見出し / 番号付きリストから抽出を試みる」「中止」の 3 択を提示
6. main / master ブランチで実行されている場合は `AskUserQuestion` で続行確認し (`.claude/rules/git-workflow.md` に従う)、「はい」ならその場でフィーチャーブランチを作成 (`git checkout -b <内容を表す名前>`) してから継続する。「いいえ」なら中止する。これにより実装開始前にブランチを確定させ、以降のコミットは全てフィーチャーブランチ上で行う
7. 作業ツリーがクリーンか確認 (`## Current state` の `git status --porcelain` 出力を参照)
   - クリーン → 続行
   - 未コミット変更や untracked file がある → スキルを中止し、ユーザーに `git commit` か `git stash` でクリーンにしてから再実行するよう案内する。理由: タスクのレビュー差分 (`PRE_BATCH_BASE` からのパス限定差分) に無関係な変更が混ざると reviewer が誤検出する / コミット時に意図しないファイルを巻き込むリスクがある

### Phase 2: タスク抽出と TaskList 作成

1. 抽出規則 (優先度順):
   - `## 実装タスク` 配下の `### Task N: ...` 見出し (推奨形式)
   - `- [ ]` 形式の TaskList
   - 番号付きリスト (`1.`, `2.`, ...)
2. 各タスクから以下を controller のメモリに保持:
   - タスク全文 (本文をそのまま)
   - 目的 / 対象ファイル / 依存 / Acceptance criteria / Context (推奨形式の場合)
   - 複雑度ヒント (対象ファイル数 / Context 長さ / criteria の主観性)
3. `TaskCreate` で抽出した各タスクを登録
4. バッチ算出規則を用意する。Phase 3 はこの規則で残タスクから 1 バッチずつ選んで処理する
   - 1 バッチ = 「依存が全て完了済み」かつ「対象ファイルが互いに重ならない (disjoint)」タスクの集合。同時実行は最大 N (目安 3-4) 件まで (「モデル選択方針」の同時実行上限に従う)
   - 同一バッチに入れない (単独バッチ or 後続バッチに回す) もの:
     - 他の候補とファイルが重なるタスク (共有ツリーで衝突するため)
     - 依存が未解決のタスク (依存元の完了を待つ)
     - 対象ファイルが不明 / 列挙されていないタスク (disjoint 判定ができないため安全側で単独実行)
   - 候補が 1 件しか残らない場合は 1 件だけのバッチ (= 従来の逐次実行と同じ) になる

### Phase 3: バッチループ

バッチ単位で処理する。バッチ内のタスクは並列、バッチ間は逐次。並列起動は「1 つのアシスタントメッセージ内で複数の `Agent` を呼び出す」ことで行う (同一メッセージ内の複数 Agent は並列実行される)。

各バッチについて以下を行う。

1. バッチ選定: Phase 2 の算出規則で残タスクから 1 バッチ (最大 N 件、目安 3-4) を選ぶ
2. `PRE_BATCH_BASE` を記録: `git rev-parse HEAD` の出力を controller メモリに保持する。このバッチのレビュー差分は全てこの BASE を基準にする
3. バッチ内の各タスクを `TaskUpdate(status=in_progress)`
4. 並列実装: 1 つのメッセージ内でバッチ内タスク分の implementer `Agent` をまとめて起動する
   - 各 Agent に `references/implementer-prompt.md` をテンプレートとして使用 (プレースホルダー `[FULL TEXT of task]`, `[Context]`, `[Working directory]` を埋める)
   - `subagent_type=general-purpose`、`model` はタスク複雑度に応じて切替 (後述の「モデル選択方針」)
   - 各 implementer は自分の対象ファイル (バッチ内で disjoint) のみ編集し、コミットはしない
5. 全 implementer の報告を受け、タスクごとにステータス分岐 (後述の「ステータスハンドリング」)。分岐は per-task で行い、あるタスクの BLOCKED / NEEDS_CONTEXT は他のバッチタスクに波及させない
6. 並列レビュー: DONE / DONE_WITH_CONCERNS のタスクについて、1 つのメッセージ内で reviewer `Agent` をまとめて起動する
   - 各 Agent に `references/reviewer-prompt.md` をテンプレートとして使用
   - プレースホルダー `[FULL TEXT of task]`, `[Acceptance criteria]`, `[implementer report]`, `[BASE_SHA]` (= `PRE_BATCH_BASE`), `[TARGET_FILES]` (= 当該タスクの対象ファイル) を埋める
   - `model=opus` 固定
   - レビューは `git diff [BASE_SHA] -- [TARGET_FILES]` のパス限定・未コミット差分で行う。対象ファイルが disjoint なので、他タスクの未コミット変更や先行コミットがあっても当該タスクの差分は分離される
7. レビュー結果分岐 (per-task):
   - APPROVED → ステップ 8 のコミット対象にする
   - NEEDS_CHANGES → 指摘を fresh implementer に再委譲 (同じ Agent ではなく fresh で起動。指摘内容を `[Context]` に追記)。再レビューは最大 2 ループまで、3 回目到達で「エスカレーション」フローへ。この再ループでも BASE は `PRE_BATCH_BASE` のまま対象ファイルにパス限定する。他のバッチタスクは影響を受けない
8. 逐次コミット: APPROVED になったタスクを 1 件ずつコミットする
   - Phase 1 step 6 で既にフィーチャーブランチ上にいることを前提とする
   - 当該タスクの対象ファイルのみを `git add <対象ファイル>` し、Conventional Commits 形式 (英語) のメッセージで `git commit` (1 タスク = 1 コミット)。対象ファイルが disjoint なのでコミット順序は任意
   - `git add` は対象ファイルのみを stage するため、implementer が誤って対象外ファイルを変更してもコミットには入らない
   - `--no-verify` / `--force` push / `reset --hard` は使用しない (`.claude/rules/git-workflow.md` の禁止事項に従う)
9. 各 APPROVED タスクを `TaskUpdate(status=completed)`
10. バッチ後チェック: 対象ファイル外の未コミット変更が残っていないか `git status --porcelain` で確認し、あればスコープ逸脱としてユーザーに報告する
11. 残タスクがあれば次バッチへ (ステップ 1 に戻る)

### Phase 4: 完了報告

全タスク完了後:

- 変更ファイル数とコミット数を `git log` / `git diff` で確認
- 1〜2 文のサマリを出力 (例: 「3 タスク完了。5 ファイル変更、3 コミット作成」)
- 未完タスク (cancelled / blocked) があれば一覧で報告

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
2. 当該タスクをスキップして次へ (`TaskUpdate(status=deleted)`、状況をログ出力)
3. スキル全体を停止 (残タスクを抱えたまま終了し、Phase 4 のサマリで未完一覧を出力)

## モデル選択方針

`Agent` 呼び出しの `model` パラメータで切替える。`haiku` は本スキルでは使用しない。

| ロール | 既定モデル | 切替条件 |
| -- | -- | -- |
| controller (本スキル本体) | セッション継承 | 切替しない |
| implementer (機械的タスク) | `sonnet` | 対象ファイル 1-2 件、明確な仕様、リファクタ等 |
| implementer (統合タスク) | `sonnet` | 複数ファイル、パターン照合、デバッグ |
| implementer (設計判断) | `opus` | 設計判断、広範な理解、Context 長大 |
| reviewer | `opus` | 常に固定 |

複雑度判定は controller がプランの `対象ファイル` の数、`Context` の長さ、`Acceptance criteria` の主観性で行う。プラン内に明示的な複雑度ヒントがあれば優先する。

同時実行上限: 1 バッチで並列起動する implementer / reviewer は最大 3-4 を目安とする。バッチ候補がこれを超える場合は複数バッチに分割する。各 implementer の `model` 切替規則は上表のまま適用する。

## Constraints

- main / master ブランチ上で実装開始しない (`AskUserQuestion` で確認)
- 作業ツリーが dirty な状態で実装開始しない (中止してユーザーに案内)
- reviewer の指摘を未解決のまま次タスクへ進まない
- implementer に plan ファイルを読ませず、controller が必要な全文を prompt に貼って渡す
- implementer はコミットしない。コミットは controller が直接 `git add` + `git commit` で行う
- 並列実行は「依存なし かつ 対象ファイルが互いに disjoint」なタスクに限る。git worktree は使わず共有ツリーで実行するため、対象ファイルの重なりがないことが並列化の前提条件 (重なる / 依存未解決 / 対象ファイル不明のタスクは逐次)
- コミットは逐次・タスク単位 (1 タスク = 1 コミット、対象ファイルのみ `git add`)
- `--no-verify`、`--force` push、`reset --hard` などは原典 Red Flags と本リポ `.claude/rules/git-workflow.md` の禁止事項に従う
- コミットログは英語、その他の会話は日本語 (本リポ既存スキルの規約に従う)

## References

- `.claude/rules/subagent-delegation.md`: 委譲の切り分け原則 (探索は散らす / 判断は親が握る / 切るなら物差しは残す)
- `references/implementer-prompt.md`: implementer subagent 用テンプレート
- `references/reviewer-prompt.md`: reviewer subagent 用テンプレート (仕様適合 + 品質統合版)
