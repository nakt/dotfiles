---
name: execute-plan
description: >-
  承認済みプラン (`.claude/plans/`) を、タスクごとに fresh subagent で実装 → レビュー → コミット → 完了マークの順に進めるスキル。
  実装は Claude サブエージェントと Codex の 2 経路から選べ、実行全体で 1 回だけ選択する。
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
- Available plans: !`ls -1t .claude/plans/ 2>/dev/null | grep '\.md$' | head -20`

## コア原則

- fresh subagent per task: タスクごとに新しい `Agent` を立て、controller の会話履歴を継承させない
- post-implementation review: 実装完了後に別の fresh subagent でレビュー (仕様適合 + 品質を 1 段で統合)
- continuous execution: タスク間で人に確認しない。停止は BLOCKED / 解消不能な ambiguity / 全タスク完了の 3 つに限る
- controller がコンテキストを curate: controller はプラン内の位置 (パスと行範囲) を渡し、subagent は指定された範囲だけを読む
- 実行中はプランファイルを編集しない: 行範囲の参照が行番号に依存するため、実行中に編集すると subagent が誤った範囲を読む

## ワークフロー

### Phase 1: プラン特定と読み込み

1. 実行確認 (ユーザーの明示依頼がない場合のみ): ユーザーが実行を明示的に依頼している場合 (`/execute-plan` スラッシュコマンド、または「プランを実行して」「実装を進めて」等の自然言語依頼) は確認せずに続行する。明示依頼がないまま起動した場合 (ExitPlanMode 承認後の自動継続など) のみ `AskUserQuestion` で「execute-plan で実行しますか？ (はい / いいえ)」を提示し、「いいえ」なら中止する。起動経路が判別できないときは安全側に倒して確認する
2. 引数でプランパスが渡されていればそれを使う
3. なければ Current state の Available plans (更新時刻の新しい順) を使う
   - 1 件 → それを使う
   - 複数 → `AskUserQuestion` で選択 (最新 4 件を選択肢として提示)
   - 0 件 → 「プランがありません」と報告して終了
4. `Read` でプラン全文を取得。冒頭が参照スタブマーカー (「このファイルは参照スタブ。実行対象: <パス>」) なら、指定された本体パスのプランへ読み替えて再取得する
   - このとき `## 合意事項` と各 `### Task N` の行範囲を記録する。以降 subagent にはこの行範囲を渡し、本文は渡さない
   - 行範囲は `開始行-終了行` 形式で、開始行・終了行とも 1 始まり (`Read` の出力に付く行番号と同じ) のまま渡す。`offset` / `limit` への変換は subagent 側で行う
   - 範囲の取り方は、`## 合意事項` が当該見出し行から次の `##` 見出しの直前まで、各タスクが `### Task N` 見出し行から次の `###` 見出し (または次の `##` 見出し) の直前まで。いずれも次の見出しがなければファイル末尾まで
   - 参照スタブを経由した場合は、読み替え先の本体プランの行番号を使う (subagent に渡すパスも本体プランのもの)
   - `Read` が全文を返さなかった場合 (既定の上限行数を超える長さのプラン) に限り、`grep -n '^## \|^### Task '` で見出し行を取り直す
5. プラン本文に `## 実装タスク` セクションがあるか確認
   - ない場合: `AskUserQuestion` で「実装タスクを追記してから再実行する」「このまま見出し / 番号付きリストから抽出を試みる」「中止」の 3 択を提示
6. プラン本文に `## 合意事項` セクションがあるか確認
   - ある場合: ステップ 4 で記録した行範囲を controller のメモリに保持する (Phase 2 チェックリストで使う)
   - ない場合: 合意事項なしのプラン (要約 + 実装タスク) でありインライン実装の対象である旨を明示し、`AskUserQuestion` で「このまま execute-plan で続行する」「中止してインライン実装に切り替える」を確認する (プランの形とセクション定義は `~/.claude/skills/write-plan/SKILL.md`)
   - 「続行する」を選んだ場合: 合意事項は存在しないものとして扱い、implementer / reviewer には合意事項の行範囲の代わりに固定文言 `(このプランは合意事項なし。合意事項との整合性は評価対象外)` を渡す。合意事項を推測して捏造しない
7. 実装経路の選択: `ls ~/.claude/plugins/cache/openai-codex` で Codex プラグインの導入有無を確認する
   - 導入されていない → 質問せず Claude 経路に決定する (選べない選択肢を毎回提示しない)
   - 導入されている → `AskUserQuestion` で「Claude サブエージェント」「Codex」の 2 択を実行全体で 1 回だけ提示する (タスクごとには聞かない)
   - 決まった経路 (質問で選んだ場合も未導入で自動決定した場合も) を controller のメモリに保持し、Phase 3 ステップ 2 で使う
8. Branch が Base branch と同じ場合は `AskUserQuestion` で続行確認し、「はい」ならその場でフィーチャーブランチを作成 (`git checkout -b <内容を表す名前>`) してから継続する。「いいえ」なら中止する。これにより実装開始前にブランチを確定させ、以降のコミットは全てフィーチャーブランチ上で行う
9. 作業ツリーがクリーンか確認 (`## Current state` の `git status --porcelain` 出力を参照)。ただしプランファイル (`.claude/plans/` 配下。本体プラン・参照スタブとも) はこの判定から除外する。理由: write-plan の承認直後に execute-plan が起動される経路では、今から実行するプラン自身が untracked で作業ツリーに存在するのが正常であり、除外しないと必ず中止になる。プランファイルはどのタスクの対象ファイルにもならないので、パス限定のレビュー差分にも `git add` にも混入しない
   - プランファイル以外がクリーン → 続行
   - プランファイル以外に未コミット変更や untracked file がある → スキルを中止し、ユーザーに `git commit` か `git stash` でクリーンにしてから再実行するよう案内する。理由: タスクのレビュー差分 (直前コミット (HEAD) からのパス限定差分) に無関係な変更が混ざると reviewer が誤検出する / コミット時に意図しないファイルを巻き込むリスクがある
10. 権限モードの案内 (Claude 経路のみ): Claude 経路を選んだ場合、`~/.claude/skills/execute-plan/references/route-claude.md` の「acceptEdits モードの案内」に従い、実装開始前に案内する。Codex 経路では Claude Code の Edit / Write 権限プロンプトが介在しないため、このステップは行わない

### Phase 2: タスク抽出と TaskList 作成

1. 抽出規則 (優先度順):
   - `## 実装タスク` 配下の `### Task N: ...` 見出し (推奨形式。詳細は `~/.claude/skills/write-plan/references/task-format.md` を参照)
   - `- [ ]` 形式の TaskList
   - 番号付きリスト (`1.`, `2.`, ...)
2. 各タスクから以下を controller のメモリに保持:
   - タスクの行範囲 (Phase 1 ステップ 4 で記録したもの。subagent の prompt には本文を転記しない)
   - 目的 / 対象ファイル / 依存 / Acceptance criteria / Context (推奨形式の場合。詳細は `~/.claude/skills/write-plan/references/task-format.md` を参照)
3. `TaskCreate` で抽出した各タスクを登録
4. 実行順とバッチを決める:
   - 依存が明示されているタスクは依存元の後に回し、それ以外はプラン記載順とする
   - この順に走査し、対象ファイルが互いに素かつ依存関係のないタスク群を 1 バッチにまとめる。対象ファイルが 1 つでも重なるタスク、依存関係のあるタスク、対象ファイルが特定できないタスクは同じバッチに入れず、単独バッチとする
   - Phase 3 はバッチ単位で処理する (1 件だけのバッチは逐次実行と同じ)

#### controller チェックリスト (Phase 3 へ渡す前)

各タスクの implementer / reviewer を起動する前に、合意事項の行範囲を controller のメモリに揃えておく (Phase 3 のステップ 4 で渡すため。Claude 経路ではステップ 2 でも渡す)。
これが欠けていると、implementer が合意事項を無視した実装をしても reviewer が検出できない。

- プランの `## 合意事項` セクションの行範囲を確定させる (Phase 1 ステップ 4 で記録したもの)。合意事項なしのプランで Phase 1 ステップ 6 の「続行する」を選んだ場合は、そこで定めた固定文言を代わりに使う。あわせて `## 合意事項` の外に判断が散在していないかを 1 パスで確認し、散在があればその箇所の行範囲も控えておく (控えるのは行範囲で、subagent の prompt には本文を転記しない)
- 対象リポの `CLAUDE.md` は controller では読まない。リポルートから対象ファイルの各先祖ディレクトリまでを辿って当該タスクに関係する検証項目を拾うのは implementer 自身の仕事で、その指示は implementer テンプレート側にある

### Phase 3: タスクループ

Phase 2 で決めたバッチを順に処理する。1 バッチ内のタスク (対象ファイルが互いに素で依存関係がない) は implementer / reviewer を並列に起動してよい。対象ファイルが重なるタスクや依存関係のあるタスクは別バッチなので、結果として逐次に処理される。

並列実行時に守ること:

- 各 implementer に、同一バッチで並行実行している他タスクの対象ファイル一覧を渡し、担当外のファイルは読むだけで編集しないことを明示する
- reviewer に渡す差分は必ず `git diff [BASE_SHA] -- [TARGET_FILES]` のパス限定にする。同じツリーに他タスクの未コミット変更が同居するため、パス限定を外すと他タスクの変更を誤検出する
- `[BASE_SHA]` はバッチ開始時点の `git rev-parse HEAD` をバッチ内の全タスクで共有する (バッチ内の他タスクのコミットで base がずれると差分に他タスクの変更が混ざる)
- コミットは controller が APPROVED になったタスクから 1 件ずつ、`git add <対象ファイル>` のパス限定で行う (1 タスク = 1 コミット)

ステップ 2 / 4 で subagent に渡すパスは絶対パスとする。
相対パスは subagent の作業ディレクトリ次第で解決できないため、テンプレートは `~/.claude/skills/execute-plan/references/` 配下のパスを `~` を展開せずそのまま渡し、プランファイルは対象リポのルートからの絶対パスに解決してから渡す。
ただし Codex 経路のステップ 2 に限り、パスはすべて `~` を展開した絶対パスで渡す (`~` が Codex 側で展開される保証がないため。詳細は `~/.claude/skills/execute-plan/references/route-codex.md` の「プロンプトに載せる値」)。

各バッチについて以下を行う。

1. バッチ選定: Phase 2 の順で次のバッチを取り、含まれる各タスクを `TaskUpdate(status=in_progress)`。`BASE_SHA` として `git rev-parse HEAD` を記録する
2. 実装: Phase 1 ステップ 7 で選んだ経路に従い、バッチ内の各タスクに implementer を起動する (バッチ内は同時起動可)
   - Claude 経路 → `~/.claude/skills/execute-plan/references/route-claude.md` の「implementer の起動」に従う
   - Codex 経路 → `~/.claude/skills/execute-plan/references/route-codex.md` に従う (「実装の委譲」で起動したうえで、「戻り値の受け取り」「Codex 起動失敗時の扱い」まで読んでから次のステップへ進む。戻り値が空またはジョブ起動メッセージだった場合はステップ 3 のステータス分岐に載せない)
   - どちらの経路でも、implementer は自分の対象ファイルのみ編集し、コミットはしない
3. implementer の報告を受けてタスクごとにステータス分岐 (後述の「ステータスハンドリング」)
4. レビュー: DONE / DONE_WITH_CONCERNS のタスクごとに reviewer `Agent` を起動する (バッチ内は同時起動可)
   - prompt では `~/.claude/skills/execute-plan/references/reviewer-prompt.md` を `Read` し、それに従ってレビューするよう指示する。テンプレート本体は controller が読まず、prompt にも書き出さない
   - あわせて渡す値は次の 7 つ: タスク番号 / プランファイルの絶対パス / 当該タスクの行範囲 / 合意事項の行範囲 (散在があれば追加の行範囲も) / `[BASE_SHA]` (= ステップ 1 で記録した SHA) / `[TARGET_FILES]` (= 当該タスクの対象ファイル) / implementer の報告
   - 合意事項なしのプランなら、合意事項の行範囲の代わりに Phase 1 ステップ 6 の固定文言を渡す (reviewer 側でこの観点がスキップされる)。どちらも渡さないと reviewer が「プラン合意事項との整合性」観点をレビューできない
   - `subagent_type=general-purpose`、`model=opus` 固定 (`plan-reviewer` エージェントはプランのレビュー用で、実装差分のレビューには使わない)
   - レビューは `git diff [BASE_SHA] -- [TARGET_FILES]` のパス限定・未コミット差分で行う
5. レビュー結果分岐 (タスクごと):
   - APPROVED → ステップ 6 のコミットへ進む
   - NEEDS_CHANGES → 指摘を fresh implementer に再委譲 (同じ Agent ではなく fresh で起動。指摘内容は「再委譲時の追加指摘」として渡す)。宛先とモデル / フラグは選ばれた経路の reference (`route-claude.md` / `route-codex.md`) の再委譲手順に従う。再レビューは最大 2 ループまで、3 回目到達で「エスカレーション」フローへ
   - NEEDS_CONTEXT → reviewer が先頭行の照合または終端の検査に失敗してレビューに入れなかった場合。実装には差し戻さず、プランを読み直して行範囲を取り直してから fresh reviewer を起動し直す。この再起動はレビューループの回数に数えない
6. コミット: APPROVED になったタスクを controller が直接コミットする。バッチ内に複数あれば 1 件ずつ順にコミットする
   - Phase 1 ステップ 8 で既にフィーチャーブランチ上にいることを前提とする
   - 当該タスクの対象ファイルのみを `git add <対象ファイル>` して `git commit` (1 タスク = 1 コミット)
   - `git add` は対象ファイルのみを stage するため、implementer が誤って対象外ファイルを変更しても、また同一バッチの他タスクが未コミットで同居していても、コミットには入らない
7. コミットしたタスクを `TaskUpdate(status=completed)`
8. バッチ後チェック: バッチ内全タスクの対象ファイル以外に未コミット変更が残っていないか `git status --porcelain` で確認し、あればスコープ逸脱としてユーザーに報告する。Phase 1 ステップ 9 と同じくプランファイル (`.claude/plans/` 配下) は除外する
9. 残バッチがあれば次のバッチへ (ステップ 1 に戻る)

#### pre-commit hook fail 時の扱い

ステップ 6 の `git commit` で pre-commit hook (`.pre-commit-config.yaml` / husky / lint-staged 等) が fail した場合は、その commit を諦めて `NEEDS_CHANGES` 相当の扱いに切り替える。具体的には:

- hook の stderr / stdout を抜粋する (どのファイルの何が引っ掛かったか)
- 当該タスクを fresh implementer に再委譲する (ステップ 5 の NEEDS_CHANGES 再委譲と同じフローに乗せる)。宛先とモデル / フラグは選ばれた経路の reference (`route-claude.md` / `route-codex.md`) の再委譲手順に従う
- 抜粋した hook エラーは「再委譲時の追加指摘」として implementer に渡す (ファイルに残っていない情報なので controller が文面を書く)
- hook が示している問題は必ず implementer に fix させる (`--no-verify` で skip して commit を通さない)
- hook fail はレビューループ回数のカウントに含める (再委譲 2 回超過でエスカレーション)

hook fail が発生する主因は、implementer の self-check が対象リポの hook を回していないこと。Claude 経路は `~/.claude/skills/execute-plan/references/implementer-prompt.md`、Codex 経路は `~/.claude/skills/execute-plan/references/codex-implementer-prompt.md` の「lint / hook self-check」で、ともに `~/.claude/skills/execute-plan/references/lint-per-language.md` に沿った検出・実行を求めている。徹底されていれば、この分岐に来る頻度は下がる。

### Phase 4: 完了報告

全タスク完了後:

- 変更ファイル数とコミット数を `git log` / `git diff` で確認
- 1〜2 文のサマリを出力し、実装経路 (Claude / Codex) を含める (例: 「Claude 経路で 3 タスク完了。5 ファイル変更、3 コミット作成」)
- `TaskList` で全タスクの最終ステータスを取得し (個別の詳細が要るときは `TaskGet`)、未完タスクがあれば一覧で報告する。内訳は、エスカレーションでスキップした `deleted`、着手前に停止して `pending` のまま残ったもの、バッチ処理中に停止して `in_progress` のまま残ったものの 3 種
- PR の作成に進む場合は `pr-merge` スキルを使うようユーザーに案内する

最終全体レビューは実施しない (タスクごとの 1 段レビューで担保)。

## ステータスハンドリング

implementer subagent は 4 種の status で報告する。

| Status | 対応 |
| -- | -- |
| `DONE` | レビュー段階へ進む |
| `DONE_WITH_CONCERNS` | 懸念を読み、影響なければレビュー段階へ。影響あれば選ばれた経路の reference (`route-claude.md` / `route-codex.md`) の再委譲手順で fresh implementer に修正委譲 |
| `NEEDS_CONTEXT` | 原因は controller が報告の文面で見分け、選ばれた経路の reference (`route-claude.md` / `route-codex.md`) の再委譲手順に従って fresh subagent を起動する |
| `BLOCKED` | 「エスカレーション」フローへ |

## エスカレーション

修正ループ 2 回超過時、または `BLOCKED` 報告時は、`AskUserQuestion` で 3 択をユーザーに提示する。

1. 追加指示を与えて再試行 (ユーザー入力を「再委譲時の追加指摘」として渡し fresh implementer に再委譲。宛先とモデル / フラグは選ばれた経路の reference (`route-claude.md` / `route-codex.md`) の再委譲手順に従う)
2. 当該タスクをスキップして次へ (`TaskUpdate(status=deleted)`、状況をログ出力。Phase 4 では未完タスクとして一覧に載せる)
3. スキル全体を停止 (残タスクを `pending` のまま終了し、Phase 4 のサマリで未完一覧を出力)

## モデル選択方針

`Agent` 呼び出しの `model` パラメータで切替える。`haiku` は本スキルでは使用しない。

| ロール | 既定モデル | 切替条件 |
| -- | -- | -- |
| controller (本スキル本体) | セッション継承 | 切替しない |
| reviewer | `opus` | 常に固定 |

implementer のモデル / ルーティング選択は実装経路ごとに異なるため、選ばれた経路の reference (`route-claude.md` / `route-codex.md`) に従う。

## References

- `~/.claude/skills/execute-plan/references/route-claude.md`: Claude 経路の controller 手順 (implementer 起動 / モデル選択 / ステータスハンドリング / acceptEdits 案内)
- `~/.claude/skills/execute-plan/references/route-codex.md`: Codex 経路の controller 手順 (実装の委譲 / 戻り値の受け取り / 起動失敗時の扱い / ステータス別の再委譲)
- `~/.claude/skills/execute-plan/references/implementer-prompt.md`: Claude 経路の implementer subagent 用テンプレート
- `~/.claude/skills/execute-plan/references/codex-implementer-prompt.md`: Codex 経路の implementer 用テンプレート (Codex 自身が読む)
- `~/.claude/skills/execute-plan/references/reviewer-prompt.md`: reviewer subagent 用テンプレート (仕様適合 + 品質統合版)
- `~/.claude/skills/execute-plan/references/lint-per-language.md`: implementer が「lint / hook self-check」で参照する言語別の判定・実行コマンド (Python / TypeScript・JavaScript を収録)
- `~/.claude/skills/write-plan/references/task-format.md`: 実装タスクの記述形式 (controller 側の抽出規則はこの形式に従う)
