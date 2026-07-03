# Claude Fable 5 / Mythos 5 プロンプティングガイド

Claude Fable 5（`claude-fable-5`）と Claude Mythos 5（`claude-mythos-5`）に固有の挙動と、プロンプト・スキャフォールディングの調整パターン。Claude Opus 4.8 との違いを起点に整理する。

出典: [Prompting Claude Fable 5 | Anthropic](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5)

## 位置づけ

Claude Fable 5 は、従来モデルには複雑・長時間・曖昧すぎた問題を扱えるモデルで、人間が数時間〜数週間かける end-to-end のタスクで特に効果を発揮する。最良の成果は「最も難しい未解決の問題」に適用したチームで観測されており、簡単なワークロードだけで試すと能力を過小評価しやすい。単純なタスクでも安定して動作する。

Opus 4.8 からいくつかの挙動が変わっており、プロンプトやスキャフォールディングの更新が必要になることがある。能力が上がった分、これまで必要だった指示・ツール・ガードレールのうち不要になったものを見直す好機でもある。

Fable 5 は offensive cybersecurity や biology / life sciences を対象としない。これらの領域のリクエストは `stop_reason: "refusal"` を返す（`parameters.md「Refusal と Fallback」` を参照）。

## 能力の向上点（Opus 4.8 比）

プロンプト設計の前提として押さえる。

- Long-horizon autonomy: 長時間・複数日にわたる goal-directed run を、指示保持を保ったまま完遂する
- 複雑で well-specified な問題での first-shot correctness: 従来は数日の反復を要したシステムを単一パスで実装した報告がある
- Vision: 密なテクニカル画像・Web アプリ・詳細なスクリーンショットを高精度に解釈。反転・ぼやけ・ノイズ画像に対し bash / crop ツールを使うよう訓練されている
- Enterprise workflow: 金融分析・スプレッドシート・スライド・ドキュメントで指示遵守・スコープ維持・プロ品質の出力
- Code review / debugging: バグ発見の recall が Opus 4.8 より明確に高い（cybersecurity 領域を除く）
- 曖昧性のナビゲーション: 複雑でマルチスレッドな依頼に対し次の手を自ら決められる
- 委譲と協調: 並列サブエージェントの dispatch と維持が大幅に安定。長時間サブエージェント・ピアエージェントとの継続的なやり取りを確実に管理する

## 挙動パターンと対処プロンプト

各パターンは「観測される挙動 → 追加すべき指示」の形で整理する。Fable 5 は指示遵守が強化されており、挙動を1つずつ列挙するより短い指示1本で広く steer できるのが原則。

### ターンが長くなる（Longer turns by default）

難しいタスクでは単一リクエストが高 effort で数分に及び、autonomous run は数時間に延びる。移行前にクライアントの timeout・streaming・進捗インジケータを調整し、ブロッキングせず非同期（スケジュールジョブ等）で run を確認する構成を検討する。曖昧なタスクでの overplanning を抑える指示:

```text
When you have enough information to act, act. Do not re-derive facts already established in the conversation, re-litigate a decision the user has already made, or narrate options you will not pursue in user-facing messages. If you are weighing a choice, give a recommendation, not an exhaustive survey. This does not apply to thinking blocks.
```

### effort レベルを使い分ける

effort が intelligence / latency / cost のトレードオフの主要コントロール。既定は `high`。詳細は `parameters.md「effort パラメータ」`。高 effort では routine work でも必要以上に context 収集・熟考しがち。要求外の整理・リファクタを抑える指示:

```text
Don't add features, refactor, or introduce abstractions beyond what the task requires. A bug fix doesn't need surrounding cleanup and a one-shot operation usually doesn't need a helper. Don't design for hypothetical future requirements: do the simplest thing that works well. Avoid premature abstraction and half-finished implementations. Don't add error handling, fallbacks, or validation for scenarios that cannot happen. Trust internal code and framework guarantees. Only validate at system boundaries (user input, external APIs). Don't use feature flags or backwards-compatibility shims when you can just change the code.
```

### 強い指示遵守（Strong instruction following）

挙動を名前で1つずつ列挙する必要はなく、短い指示で steer できる。un-steered では高 effort で冗長化しやすい（採用しない選択肢の列挙、根本原因の長い説明、過度に構造化された PR 説明、次の行を説明するだけのコメント）。簡潔さの指示は個別列挙と同等に効く:

```text
Lead with the outcome. Your first sentence after finishing should answer "what happened" or "what did you find": the thing the user would ask for if they said "just give me the TLDR." Supporting detail and reasoning come after. Being readable and being concise are different things, and readability matters more.

The way to keep output short is to be selective about what you include (drop details that don't change what the reader would do next), not to compress the writing into fragments, abbreviations, arrow chains like A → B → fails, or jargon.
```

長時間ワークフローの checkpoint も同様。全ケースを列挙せず、本当に必要なときだけ止める指示:

```text
Pause for the user only when the work genuinely requires them: a destructive or irreversible action, a real scope change, or input that only they can provide. If you hit one of these, ask and end the turn, rather than ending on a promise.
```

### 進捗報告を根拠づける（Ground progress claims）

長時間の autonomous run では、進捗を実際のツール結果に照らして監査させる。テストでは、捏造を誘発するよう設計されたタスクでも fabricated status report がほぼ消えた:

```text
Before reporting progress, audit each claim against a tool result from this session. Only report work you can point to evidence for; if something is not yet verified, say so explicitly. Report outcomes faithfully: if tests fail, say so with the output; if a step was skipped, say that; when something is done and verified, state it plainly without hedging.
```

### 境界を明示する（State the boundaries）

Fable 5 は時折、要求されていない行動を取る（頼まれていないメールの下書き、防御的な git ブランチのバックアップ作成）。何をして良い / いけないかを明示的に制約する:

```text
When the user is describing a problem, asking a question, or thinking out loud rather than requesting a change, the deliverable is your assessment. Report your findings and stop. Don't apply a fix until they ask for one. Before running a command that changes system state (restarts, deletes, config edits), check that the evidence actually supports that specific action. A signal that pattern-matches to a known failure may have a different cause.
```

### 並列サブエージェント（Parallel subagents）

Fable 5 は従来より積極的に並列サブエージェントを dispatch する。頻繁に使い、いつ委譲が適切かの明示的ガイダンスを与え、orchestrator ↔ subagent はブロッキングより非同期通信を優先する。context を持ち越す long-lived subagent は cache read でコスト・時間を節約し、最も遅い subagent での bottleneck を避ける:

```text
Delegate independent subtasks to subagents and keep working while they run. Intervene if a subagent goes off track or is missing relevant context.
```

### メモリシステムを構築する（Construct a memory system）

Fable 5 は過去の run から得た教訓を記録・参照できると特に高性能になる。Markdown ファイル程度の単純な書き込み先を与える:

```text
Store one lesson per file with a one-line summary at the top. Record corrections and confirmed approaches alike, including why they mattered. Don't save what the repo or chat history already records; update an existing note rather than creating a duplicate; delete notes that turn out to be wrong.
```

既存履歴から bootstrap するには過去セッションをレビューさせる:

```text
Reflect on the previous sessions we've had together. Use subagents to identify core themes and lessons, and store them in [X]. Make sure you know to reference [X] for future use.
```

### まれな早期停止（Rare cases of early stopping）

長いセッションの深部で、対応するツール呼び出しなしに意図の宣言だけ（"I'll now run X"）でターンを終えたり、既に十分な情報があるのに許可を求めて止まることがある。"continue" や "go ahead and do it end to end" で足りる。前述の checkpoint 指示と組み合わせる。autonomous パイプラインには system reminder を追加:

```text
You are operating autonomously. The user is not watching in real time and cannot answer questions mid-task, so asking "Want me to…?" or "Shall I…?" will block the work. For reversible actions that follow from the original request, proceed without asking. Offering follow-ups after the task is done is fine; asking permission after already discussing with the user before doing the work is not. Before ending your turn, check your last paragraph. If it is a plan, an analysis, a question, a list of next steps, or a promise about work you have not done ("I'll…", "let me know when…"), do that work now with tool calls. End your turn only when the task is complete or you are blocked on input only the user can provide.
```

### まれな context-budget 懸念（Context-budget concern）

非常に長いセッションで、新セッションを提案したり、要約して引き継ごうとしたり、自分の作業を削ろうとすることがある。harness が残トークンのカウントダウンをモデルに見せると起きやすい。可能なら明示的な context-budget 数値を見せない。見せざるを得ないなら安心させる指示を添える:

```text
You have ample context remaining. Do not stop, summarize, or suggest a new session on account of context limits. Continue the work.
```

### 依頼だけでなく理由を伝える（Give the reason, not only the request）

Fable 5 は依頼の背後にある意図を理解すると性能が上がる。context があれば、意図を自力で推測するのでなく関連情報とタスクを結びつけられる。特に複数ワークストリームを扱う長時間エージェントには why を与える:

```text
I'm working on [the larger task] for [who it's for]. They need [what the output enables]. With that in mind: [request].
```

### ユーザーとのコミュニケーションの可読性（Readability）

多数のツール呼び出しや大きな作業 context を含む agentic 会話では、追いにくいテキスト（密な arrow-chain 短縮、深い実装詳細、ユーザーが見ていない thinking への言及、過度に技術的な言い回し）が出やすい。コミュニケーションスタイルの addendum で緩和する:

```text
Terse shorthand is fine between tool calls (that's you thinking out loud, and brevity there is good). Your final summary is different: it's for a reader who didn't see any of that.

If you've been working for a while without the user watching (overnight, across many tool calls, since they last spoke), your final message is their first look at any of it. Write it as a re-grounding, not a continuation of your working thread: the outcome first, then the one or two things you need from them, each explained as if new. The vocabulary you built up while working is yours, not theirs; leave it behind unless you re-introduce it.

When you write the summary at the end, drop the working shorthand. Write complete sentences. Spell out terms. Don't use arrow chains, hyphen-stacked compounds, or labels you made up earlier. When you mention files, commits, flags, or other identifiers, give each one its own plain-language clause. Open with the outcome: one sentence on what happened or what you found. Then the supporting detail. If you have to choose between short and clear, choose clear.
```

### send-to-user ツールを作る（Create a send-to-user tool）

長時間・非同期エージェントには、ターンを終えずにユーザーが正確に読むべきメッセージ（成果物、具体的な数値を含む進捗、ループ中の質問への直接回答）を表示する手段を与える。ツールの input が表示メッセージで、Claude が呼んだら UI にそのまま描画し、tool result には単純な ack を返す。tool input は決して要約されないため content が無傷で届く。

```json
{
  "name": "send_to_user",
  "description": "Display a message directly to the user. Use this for progress updates, partial results, or content the user must see exactly as written before the task finishes.",
  "input_schema": {
    "type": "object",
    "properties": {
      "message": {
        "type": "string",
        "description": "The content to display to the user."
      }
    },
    "required": ["message"]
  }
}
```

verbatim の content 配信や直接対話に UX が依存する場合に追加する。ツール定義だけでは足りず、system prompt に elicitation 指示がないと Fable 5 はほとんど呼ばない。ナレーションや内部推論を通してはいけない（過剰呼び出しは目的を損なう）:

```text
Between tool calls, when you have content the user must read verbatim (a partial deliverable, a direct answer to their question), call the send_to_user tool with that content. Use send_to_user only for user-facing content, not for narration or reasoning.
```

## 推奨スキャフォールディング変更

- 難易度レンジの上限から始める: 従来モデルに割り当てるより難しいタスクを選び、Fable 5 に scope・clarifying question・実行までさせる
- 長時間 run では self-verification を明示: fresh-context の別 verifier サブエージェントは self-critique を上回る傾向。`Establish a method for checking your own work at an interval of [X] as you build. Run this every [X interval], verifying your work with subagents against the specification.`
- 既存のプロンプト・スキルをリファクタ: 従来モデル向けのスキルは Fable 5 には過度に prescriptive で出力品質を下げうる。default 性能が上回るなら古い指示の削除を検討する。Fable 5 はタスクから学んだことでスキルをその場で更新するのも得意
- 推論を応答内で再現させない: 内部推論を応答テキストとして echo / transcribe / explain させる指示は `reasoning_extraction` refusal を誘発し、Opus 4.8 への fallback を増やす。移行時に既存スキル・system prompt の reflection / show-your-thinking 指示を監査する。推論の可視性が必要なら adaptive thinking の構造化 `thinking` ブロックを読み、長時間 run の進捗は send-to-user ツールで出す

移行に関する API 変更（adaptive thinking のみ、summarized-only の thinking 出力、extended thinking budget なし、`refusal` stop reason と fallback 処理）は `parameters.md` を参照。
