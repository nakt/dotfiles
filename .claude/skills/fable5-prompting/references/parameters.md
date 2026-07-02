# Fable 5 / Mythos 5 の API パラメータと制御

effort・adaptive thinking・refusal / fallback の3つを扱う。プロンプト本文だけでなく API レイヤの設定も Fable 5 の挙動を大きく左右する。

出典: [Effort](https://platform.claude.com/docs/en/build-with-claude/effort) / [Adaptive thinking](https://platform.claude.com/docs/en/build-with-claude/adaptive-thinking) / [Refusals and fallback](https://platform.claude.com/docs/en/build-with-claude/refusals-and-fallback)

## effort パラメータ

`output_config.effort` で、応答に費やすトークンの eagerness を制御する。intelligence / latency / cost のトレードオフを単一モデル内で調整できる。beta ヘッダ不要。thinking の有効化は不要で、text 応答・ツール呼び出し・extended thinking を含む全トークンに効く。低 effort ほどツール呼び出しも減る。

### レベル一覧

| レベル | 内容 | 典型用途 |
|---|---|---|
| `max` | 絶対最大能力。トークン消費に制約なし | 最も深い推論・徹底分析 |
| `xhigh` | long-horizon 向けの拡張能力 | 30分超の長時間 agentic / coding、トークン budget が数百万規模 |
| `high` | 高能力。パラメータ未指定と等価（既定） | 複雑な推論・難しい coding・agentic タスク |
| `medium` | バランス型。中程度のトークン節約 | 速度・コスト・性能のバランスが要る agentic タスク |
| `low` | 最も効率的。相応の能力低下 | 単純タスク、サブエージェント等、速度・低コスト優先 |

effort は厳密なトークン budget ではなく behavioral signal。低 effort でも十分難しい問題では thinking するが、同じ問題で高 effort よりは少なく考える。

### Fable 5 での推奨

- 既定の `high` を大半のタスクの出発点にする
- 最も能力が要るワークロードで `xhigh`
- routine work は `medium` / `low` に step down。Fable 5 の低 effort は従来モデルの `xhigh` を上回ることが多い
- タスクが完了するが時間がかかりすぎる、あるいはより速く対話的に進めたい場合は effort を下げる
- `high` / `xhigh` では `max_tokens` を大きく取る。`max_tokens` は thinking + response text を合わせた総出力のハード上限

Mythos 5 も同じ推奨。

### ツール使用時

低 effort: 複数操作を少数のツール呼び出しにまとめる / 呼び出し数を減らす / preamble なしで着手 / 完了後は簡潔な確認のみ。

高 effort: ツール呼び出しを増やす / 着手前に計画を説明 / 変更の詳細サマリー / 網羅的なコードコメント。

### Claude Code の ultracode について

ultracode は Claude Code の effort メニューに現れるが、API の effort レベルではない。`xhigh` effort に、マルチエージェントワークフロー起動の standing permission を組み合わせたもの。API が受け付ける effort 値は上表が全て。

## adaptive thinking

Fable 5 / Mythos 5 では thinking は常時オンで無効化できず、adaptive thinking が唯一の thinking モード。`thinking: {type: "disabled"}` は拒否される。`thinking` を未設定でも adaptive が適用される。manual `thinking: {type: "enabled", budget_tokens: N}` は非対応で、`budget_tokens` は 400 エラー。

adaptive モードでは、モデルが各リクエストの複雑さを評価して thinking の要否と深さを自ら決める。既定 effort（`high`）ではほぼ常に thinking し、低 effort では単純問題で thinking をスキップしうる。adaptive thinking は interleaved thinking（ツール呼び出しの間の thinking）も自動で有効化するため agentic workflow に特に有効。

### effort との組み合わせ

| effort | thinking 挙動 |
|---|---|
| `max` | 制約なしで常に thinking |
| `xhigh` | 常に深く thinking、探索を拡張 |
| `high`（既定） | ほぼ常に thinking。複雑タスクで深い推論 |
| `medium` | 中程度。ごく単純なクエリでスキップしうる |
| `low` | thinking を最小化。速度優先で単純タスクはスキップ |

### thinking 挙動のチューニング

triggering は promptable。考えすぎる場合:

```text
Extended thinking adds latency and should only be used when it will meaningfully improve answer quality, typically for problems that require multi-step reasoning. When in doubt, respond directly.
```

考えさせたい場合:

```text
This task involves multi-step reasoning. Think carefully before responding.
```

ユーザーターン単位でも steer 可能。`"Please think hard before responding."` で促し、`"Answer directly without deliberating."` で抑制する。system prompt と独立に効く。文言に敏感なので、期待通りにならなければより直接的な表現を試す。

### thinking 出力（Fable 5 / Mythos 5 固有）

raw chain of thought は決して返らない。返るのは通常の `thinking` ブロック（`redacted_thinking` ではない）。`thinking.display` の挙動:

- `"summarized"`: 推論の可読サマリーを返す
- `"omitted"`（これらのモデルの既定）: `thinking` ブロックは含まれるが `thinking` フィールドは空文字列

既定が `"omitted"` なのは Opus 4.6 からの silent change。サマリーテキストが欲しければ `thinking.display: "summarized"` を明示する。

```python
thinking = {"type": "adaptive", "display": "summarized"}
```

同一モデルで会話を継続する場合、各 thinking ブロックは受け取ったまま（`thinking` が空のものも含め）API に返す。編集・再構成しない。表示用にサマリーを読むのは問題ないが、内容を変更したブロックは拒否される。

モデルを切り替える場合（classifier refusal fallback など）は、直前までの assistant ターンから `thinking` / `redacted_thinking` ブロックを除去する。thinking ブロックは生成元モデルに紐づく。他モデルは拒否せず黙って無視するが、無視されたブロックも input トークンを消費する。

内部推論の可視化は、応答テキストで推論を求めるのでなくこの `thinking` ブロックを読むこと。Fable 5 では内部推論を応答テキストとして引き出そうとするリクエストは `stop_details.category: "reasoning_extraction"` で refuse されうる。

### コスト制御

`max_tokens` を総出力（thinking + response text）のハード上限に使う。effort は thinking 配分の soft guidance。`high` / `max` では thinking が広がり `max_tokens` を使い切りやすい。`stop_reason: "max_tokens"` が出たら `max_tokens` を増やすか effort を下げる。

課金は full thinking トークンに対して行われ、visible なトークン数とは一致しない。`display: "omitted"` は latency を減らすがコストは減らさない。`usage.output_tokens_details.thinking_tokens` で内部推論に使われた billed トークン数が読める。

## Refusal と Fallback

Fable 5 は safety classifier を持ち、リクエストを decline しうる。その場合エラーでなく `stop_reason: "refusal"` の通常応答（HTTP 200）が返る。同じリクエストを別の Claude モデルに送れば通常は回答が得られる。

### refusal 応答の形

```json
{
  "stop_reason": "refusal",
  "stop_details": {
    "type": "refusal",
    "category": "cyber",
    "explanation": "This request was declined because it could enable cyber harm."
  },
  "usage": { "input_tokens": 412, "output_tokens": 0 }
}
```

`stop_details.category` は発火したポリシー領域、`explanation` は人間可読説明（テキストは不安定なので parse せず表示する）。named category に mapping しない場合は両フィールドが `null`（正常値）。`stop_details` 自体は `refusal` 以外の stop reason では `null`。

### category

| category | 意味 |
|---|---|
| `"cyber"` | malware / exploit 開発などの cyber harm。benign な cybersecurity work でも発火しうる |
| `"bio"` | 危険な lab method などの biological harm。有益な life sciences work でも発火しうる |
| `"frontier_llm"` | 競合 AI モデル開発の補助（商用条項で制限）。benign な ML work でも発火しうる |
| `"reasoning_extraction"` | 内部推論を応答テキストで再現させる要求。構造化された形で推論が要るなら adaptive thinking を使う |

refusal は出力前にも mid-stream にも起きうる。いずれも partial output は不完全として破棄する。出力前の refusal は課金されず rate limit にも数えない。mid-stream refusal は既に stream された input / output を通常レートで課金する。

### fallback の選び方

| 状況 | 手段 |
|---|---|
| Claude API / Claude Platform on AWS、最も単純 | server-side fallback |
| 任意プラットフォーム + TS/Python/Go/Java/C# SDK | SDK middleware（client-side fallback） |
| Ruby / PHP / raw HTTP / 独自 retry | fallback credit を使った手動 retry |

### server-side fallback

`fallbacks` パラメータに最大3モデルを列挙し、`server-side-fallback-2026-06-01` beta ヘッダを送る。Fable 5 が decline すると API がチェーン内の次モデルを同一リクエストで実行し、回答したモデル名を含む単一応答を返す。

```json
{
  "model": "claude-fable-5",
  "max_tokens": 1024,
  "fallbacks": [{ "model": "claude-opus-4-8" }],
  "messages": [{ "role": "user", "content": "..." }]
}
```

ルール: エントリは順に試行し互いに / 要求モデルと distinct であること。各エントリは要求モデルの許可 target（Models API の `allowed_fallback_models`）であること。各エントリで `max_tokens` / `thinking` をそのattempt限りで上書き可。リクエストは列挙した全モデルへの直接リクエストとして valid であること。fallback を trigger するのは safety classifier decline のみで、rate limit / overload / server error はそのまま返る。

応答には `fallback` content ブロック（`{"type": "fallback", "from": {...}, "to": {...}}`）がモデル境界に入り、`usage.iterations` に各 attempt が記録される（decline したモデルは `message`、回答したモデルは `fallback_message`）。

### client-side fallback（SDK middleware）

TS / Python / Go / Java / C# SDK に refusal-fallback middleware がある。client に一度設定すれば `client.beta.messages` 経由の呼び出しが自動 retry する。`fallback-credit-2026-06-01` beta ヘッダも毎回送るため retry が repricing される。会話をまたいで単一の `BetaFallbackState` を共有すると、accept したモデルに以降 pin される。Ruby / PHP には未提供で detect-and-retry を自前実装する。

### よくある落とし穴

- refusal は別モデルで retry する（同一モデルへの再送は再度 refusal になりやすい）
- retry は request 単位で budget する（1ターンで agent + sub-agent が複数 refusal を出しうる）
- retry handler / error-recovery branch / background worker の全 request path に fallback を設定する
- sub-agent 呼び出しには独自の fallback を与える（`fallbacks` はツール実行内のモデル呼び出しに伝播しない）
- fallback は ambient state でなく request のプロパティにする
- refusal は HTTP 200 なのでエラー率監視では見えない。refusal ごと / fallback-served ごとにイベントを emit して監視する
- 分岐は `stop_reason` で行う（`stop_details` は informational で `null` になりうる）

### Message Batches

batch 内の refusal は `result.type: "succeeded"` + `stop_reason: "refusal"` で返る。`stop_details` は `null` になりうるので `stop_reason` を直接見る。server-side fallback は batch 非対応（`fallbacks` を含む batch request は per-item errored になる）。refused item を集めて thinking ブロックを除去し、fallback モデルへ再投入する。
