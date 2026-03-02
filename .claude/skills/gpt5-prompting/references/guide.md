# GPT-5 公式プロンプティングガイド 詳細

OpenAI公式ドキュメントに基づくGPT-5系モデルのプロンプティングベストプラクティス。

## 目次

- [GPT-5 公式プロンプティングガイド 詳細](#gpt-5-公式プロンプティングガイド-詳細)
  - [目次](#目次)
  - [1. ロール指定とパーソナリティの区別](#1-ロール指定とパーソナリティの区別)
    - [避けるべきパターン（専門性ロール指定）](#避けるべきパターン専門性ロール指定)
    - [許容されるパターン（パーソナリティ定義）](#許容されるパターンパーソナリティ定義)
    - [パーソナリティ定義のベストプラクティス](#パーソナリティ定義のベストプラクティス)
  - [2. エージェント積極性（Eagerness）の制御](#2-エージェント積極性eagernessの制御)
    - [積極性を下げる場合](#積極性を下げる場合)
    - [積極性を上げる場合](#積極性を上げる場合)
  - [3. Tool Preamble（ツール呼び出し前の説明）](#3-tool-preambleツール呼び出し前の説明)
  - [4. reasoning\_effort パラメータ](#4-reasoning_effort-パラメータ)
  - [5. verbosity パラメータ](#5-verbosity-パラメータ)
  - [6. Responses API 推奨](#6-responses-api-推奨)
  - [7. 指示遵守の注意点](#7-指示遵守の注意点)
    - [悪い例](#悪い例)
    - [対策](#対策)
  - [8. none reasoning モードのプロンプティング](#8-none-reasoning-モードのプロンプティング)
  - [9. スコープドリフト防止](#9-スコープドリフト防止)
  - [10. 長文コンテキスト処理](#10-長文コンテキスト処理)
  - [11. 曖昧性・ハルシネーション対策](#11-曖昧性ハルシネーション対策)
  - [12. Cursorのプロンプトチューニング事例](#12-cursorのプロンプトチューニング事例)
    - [発見1: 冗長性のバランス](#発見1-冗長性のバランス)
    - [発見2: 不要なユーザー確認の削減](#発見2-不要なユーザー確認の削減)
    - [発見3: 過剰なコンテキスト収集の抑制](#発見3-過剰なコンテキスト収集の抑制)
  - [13. Markdownフォーマット](#13-markdownフォーマット)
  - [14. メタプロンプティング](#14-メタプロンプティング)
  - [15. Compaction（コンテキスト拡張）](#15-compactionコンテキスト拡張)
  - [16. 公式ベンチマーク用プロンプト抜粋](#16-公式ベンチマーク用プロンプト抜粋)
    - [SWE-Bench: 検証の徹底](#swe-bench-検証の徹底)
    - [Tau-Bench Retail: 計画と反省](#tau-bench-retail-計画と反省)
    - [Terminal-Bench: 探索と検証](#terminal-bench-探索と検証)
  - [17. GPT-5.2 マイグレーションガイド](#17-gpt-52-マイグレーションガイド)
  - [まとめ: 実務向けプロンプト構成テンプレート](#まとめ-実務向けプロンプト構成テンプレート)

---

## 1. ロール指定とパーソナリティの区別

GPT-5系リーズニングモデルでは、従来型の専門性ロール指定は使用しない。代わりにパーソナリティ定義でトーン・スタイルを制御する。

### 避けるべきパターン（専門性ロール指定）

```
❌ You are a world-class expert in machine learning.
❌ あなたは熟練のデータサイエンティストです。
❌ As a senior security engineer, analyze the following code.
```

これらは以下の理由で有害：

1. 内部推論へのバイアス注入: リーズニングモデルは内部CoTで最適な推論パスを自律的に選択する。外部からの専門性ロールがこの探索を特定方向に歪める
2. reasoning tokensの浪費: ロールの一貫性維持に推論トークンが消費される（guide.md「指示遵守の注意点」と同じメカニズム）
3. 分析結果のステアラブルな偏り: ペルソナの変更だけで結論が逆転しうることが実証されている（[arxiv:2602.18710](https://arxiv.org/abs/2602.18710)）
4. リーズニングモデルでの鈍感性: o1は全ペルソナで99.0%の正答率を維持し、ロール指定にほぼ完全に鈍感。効果がないか、残る影響はバイアスのみ（[arxiv:2504.06460](https://arxiv.org/abs/2504.06460)）

### 許容されるパターン（パーソナリティ定義）

公式 [Prompt Personalities](https://cookbook.openai.com/examples/gpt-5/prompt_personalities) ガイドに基づく。パーソナリティは「how（どう応答するか）」を制御するものであり、「what（何をすべきか）」を指示するものではない。

```
✅ You are a focused, formal, and exacting AI Agent.
   （トーン: formal、スタイル: exacting）

✅ You are a highly efficient AI assistant providing clear, contextual answers.
   （行動様式: efficient、出力特性: clear and contextual）

✅ You are a plainspoken and direct AI assistant focused on helping the user achieve productive outcomes.
   （コミュニケーションスタイル: plainspoken, direct）
```

### パーソナリティ定義のベストプラクティス

OpenAI公式ガイドが定義する4つのプロファイル：

| プロファイル | 用途 | 特徴 |
|---|---|---|
| Professional | エンタープライズ、法務・金融 | formal, precise, structured |
| Efficient | コード生成、開発者ツール、バッチ処理 | concise, direct, no conversational language |
| Fact-based | デバッグ、リスク分析、コーチング | corrective, grounded, explicit trade-offs |
| Exploratory | ドキュメント、オンボーディング、教育 | enthusiastic, approachable, depth with clarity |

原則: タスクロジックやドメインルールをパーソナリティに混ぜない。パーソナリティはエージェントの応答スタイルに限定する。

> Avoid overloading personalities with task logic or domain rules—keep them focused on *how* the agent responds, not *what* it must do.
> — [Prompt Personalities | OpenAI Cookbook](https://cookbook.openai.com/examples/gpt-5/prompt_personalities)

---

## 2. エージェント積極性（Eagerness）の制御

GPT-5はデフォルトで徹底的にコンテキスト収集しようとする。タスクに応じて制御が必要。

### 積極性を下げる場合

- `reasoning_effort` を `low`/`medium` に設定
- 探索の停止条件を明示
- ツール呼び出し回数の上限設定

```xml
<context_gathering>
Goal: Get enough context fast. Parallelize discovery and stop as soon as you can act.

Method:
- Start broad, then fan out to focused subqueries.
- In parallel, launch varied queries; read top hits per query.
- Avoid over searching for context.

Early stop criteria:
- You can name exact content to change.
- Top hits converge (~70%) on one area/path.

Depth:
- Trace only symbols you'll modify or whose contracts you rely on.
</context_gathering>
```

最大限に制限する場合：

```xml
<context_gathering>
- Search depth: very low
- Bias strongly towards providing a correct answer as quickly as possible.
- Usually, this means an absolute maximum of 2 tool calls.
- If you need more time, update the user with findings and open questions.
</context_gathering>
```

### 積極性を上げる場合

- `reasoning_effort` を `high` に設定
- 永続性指示を追加

```xml
<persistence>
- You are an agent - please keep going until the user's query is completely resolved.
- Only terminate your turn when you are sure that the problem is solved.
- Never stop or hand back when you encounter uncertainty — research or deduce the most reasonable approach and continue.
- Do not ask the human to confirm assumptions — decide the most reasonable assumption, proceed, and document it.
</persistence>
```

ポイント: ツールごとに不確実性の閾値を変える。決済ツールは低閾値（確認必須）、検索ツールは高閾値（自律的に進める）。

---

## 3. Tool Preamble（ツール呼び出し前の説明）

長時間タスクでは進捗説明がUXを大幅改善。頻度・スタイル・内容をプロンプトで制御可能。

```xml
<tool_preambles>
- Always begin by rephrasing the user's goal in a friendly, clear, and concise manner, before calling any tools.
- Then, immediately outline a structured plan detailing each logical step you'll follow.
- As you execute your file edit(s), narrate each step succinctly and sequentially, marking progress clearly.
- Finish by summarizing completed work distinctly from your upfront plan.
</tool_preambles>
```

---

## 4. reasoning_effort パラメータ

| レベル | 用途 |
|---|---|
| `none` | 非推論モード（GPT-5.1で導入）。GPT-4.1/4o相当の挙動。web search・file search等のhosted toolsが利用可能 |
| `minimal` | 低レイテンシ優先。GPT-5.1以降では `none` への移行を推奨 |
| `low` | 簡単なタスク |
| `medium` | GPT-5のデフォルト |
| `high` | 複雑なマルチステップタスク |
| `xhigh` | 最大推論深度（GPT-5.2で導入） |

デフォルト値: GPT-5は `medium`、GPT-5.1/5.2は `none`。

推奨: 複数の独立タスクは、1ターンに1タスクずつ分割すると最高性能。

---

## 5. verbosity パラメータ

`reasoning_effort` が思考の深さを制御するのに対し、`verbosity` は最終回答の長さを制御。

- APIパラメータでグローバル設定
- プロンプトで特定コンテキストのみ上書き可能

Cursor事例: グローバルで `verbosity=low`、コード出力のみ高冗長性を指定：

```
Write code for clarity first. Prefer readable, maintainable solutions with clear names, comments where needed. Do not produce code-golf or overly clever one-liners. Use high verbosity for writing code and code tools.
```

---

## 6. Responses API 推奨

Chat Completions APIよりResponses APIを強く推奨。

- `previous_response_id` で前回の推論トレースを再利用
- ツール呼び出し後に計画を再構築する必要なし
- CoTトークン節約、レイテンシ改善
- Tau-Bench Retailで 73.9% → 78.2% にスコア改善

---

## 7. 指示遵守の注意点

GPT-5は指示を忠実に守ろうとするため、矛盾・曖昧な指示があると推論トークンを浪費して両立しようとする。

### 悪い例

- 「患者の同意なしに予約するな」→ 後で「緊急時は患者に連絡せず自動予約しろ」
- 「必ず最初にプロファイル検索しろ」→ 後で「緊急時は即座に911案内しろ」

### 対策

- プロンプト内の矛盾を徹底排除
- 優先順位を明示（例：「緊急時はプロファイル検索をスキップ可」）
- [Prompt Optimizer](https://platform.openai.com/chat/edit?optimize=true) で検証

---

## 8. none reasoning モードのプロンプティング

GPT-5.1で導入された `reasoning_effort=none` はreasoningトークンを一切使用せず、GPT-4.1/4oに近い挙動となる。web search・file search等のhosted toolsが利用可能になる。

`none` および `minimal` ではGPT-4.1に近いプロンプティングが有効：

1. 明示的な計画指示: モデルが内部で計画する余裕が少ないため
2. 詳細なツール呼び出し説明を要求: 進捗更新でエージェント性能向上
3. ツール説明の曖昧さ排除: 最大限に明確化
4. 永続性リマインダー: 早期終了を防ぐ
5. 簡潔な思考プロセス出力を要求: 箇条書きなど

```
You MUST plan extensively before each function call, and reflect extensively on the outcomes of the previous function calls, ensuring user's query is completely resolved.
```

`none` でツール呼び出しの正確性を高める：

```
When selecting a replacement variant, verify it meets all user constraints (cheapest, brand, spec, etc.). Quote the item-id and price back for confirmation before executing.
```

計画プロンプト例：

```
Remember, you are an agent - please keep going until the user's query is completely resolved. Decompose the user's query into all required sub-requests, and confirm that each is completed. Do not stop after completing only part of the request.

You must plan extensively in accordance with the workflow steps before making subsequent function calls, and reflect extensively on the outcomes each function call made.
```

---

## 9. スコープドリフト防止

GPT-5.2はコード構造化に強いが、要求以上のコードを生成する場合がある。明示的にスコープを制限する。

```xml
<design_and_scope_constraints>
- Implement EXACTLY and ONLY what the user requests.
- No extra features, no added components, no UX embellishments.
- Style aligned to the design system at hand.
- Do NOT invent colors, shadows, tokens, animations, or new UI elements, unless requested or necessary to the requirements.
- If any instruction is ambiguous, choose the simplest valid interpretation.
</design_and_scope_constraints>
```

---

## 10. 長文コンテキスト処理

約10kトークン以上の入力（複数章ドキュメント、長いスレッド、複数PDF）では、要約と再グラウンディングを強制する。

```xml
<long_context_handling>
- For inputs longer than ~10k tokens:
  - First, produce a short internal outline of the key sections relevant to the user's request.
  - Re-state the user's constraints explicitly before answering.
  - In your answer, anchor claims to sections rather than speaking generically.
- If the answer depends on fine details (dates, thresholds, clauses), quote or paraphrase them.
</long_context_handling>
```

---

## 11. 曖昧性・ハルシネーション対策

曖昧なクエリや不確実な情報に対する自信過剰なハルシネーションを防ぐ。

```xml
<uncertainty_and_ambiguity>
- If the question is ambiguous or underspecified:
  - Ask up to 1-3 precise clarifying questions, OR
  - Present 2-3 plausible interpretations with clearly labeled assumptions.
- When external facts may have changed recently and no tools are available:
  - Answer in general terms and state that details may have changed.
- Never fabricate exact figures, line numbers, or external references when uncertain.
- When unsure, prefer language like "Based on the provided context..." instead of absolute claims.
</uncertainty_and_ambiguity>
```

高リスク出力（法務・金融・コンプライアンス）での自己チェック：

```xml
<high_risk_self_check>
Before finalizing an answer in legal, financial, compliance, or safety-sensitive contexts:
- Briefly re-scan your own answer for:
  - Unstated assumptions,
  - Specific numbers or claims not grounded in context,
  - Overly strong language ("always," "guaranteed," etc.).
- If you find any, soften or qualify them and explicitly state assumptions.
</high_risk_self_check>
```

---

## 12. Cursorのプロンプトチューニング事例

### 発見1: 冗長性のバランス

初期問題: テキスト出力が冗長、コードは逆に簡潔すぎる（単一文字変数など）

解決策:
- APIで `verbosity=low` を設定
- プロンプトでコードのみ高冗長性を指定

### 発見2: 不要なユーザー確認の削減

初期問題: モデルが頻繁に確認を求め、長時間タスクの流れが途切れる

解決策: 製品の挙動を詳細に説明し、自律性を促進

```
Be aware that the code edits you make will be displayed to the user as proposed changes, which means (a) your code edits can be quite proactive, as the user can always reject, and (b) your code should be well-written and easy to quickly review.

If proposing next steps that would involve changing the code, make those changes proactively for the user to approve/reject rather than asking whether to proceed. In general, you should almost never ask the user whether to proceed with a plan; instead proactively attempt the plan.
```

### 発見3: 過剰なコンテキスト収集の抑制

初期問題: 以前のモデル向けの「徹底的に調査せよ」指示がGPT-5では逆効果

```xml
<!-- 旧: GPT-5では過剰なツール呼び出しを誘発 -->
<maximize_context_understanding>
Be THOROUGH when gathering information. Make sure you have the FULL picture before replying.
</maximize_context_understanding>

<!-- 新: トーンを緩和 -->
<context_understanding>
If you've performed an edit that may partially fulfill the query, but you're not confident, gather more information before ending your turn.
Bias towards not asking the user for help if you can find the answer yourself.
</context_understanding>
```

---

## 13. Markdownフォーマット

デフォルトではMarkdownを使用しない（レンダリング非対応環境との互換性のため）。

必要な場合はプロンプトで指示：

```
- Use Markdown only where semantically correct (e.g., `inline code`, ```code fences```, lists, tables).
- When using markdown, use backticks to format file, directory, function, and class names.
- Use \( and \) for inline math, \[ and \] for block math.
```

長い会話では3-5メッセージごとにMarkdown指示を再挿入すると遵守率が維持される。

---

## 14. メタプロンプティング

GPT-5自身にプロンプト改善点を聞くのが有効：

```
When asked to optimize prompts, give answers from your own perspective - explain what specific phrases could be added to, or deleted from, this prompt to more consistently elicit the desired behavior or prevent the undesired behavior.

Here's a prompt: [PROMPT]

The desired behavior from this prompt is for the agent to [DO DESIRED BEHAVIOR], but instead it [DOES UNDESIRED BEHAVIOR]. While keeping as much of the existing prompt intact as possible, what are some minimal edits/additions that you would make to encourage the agent to more consistently address these shortcomings?
```

---

## 15. Compaction（コンテキスト拡張）

長時間実行のツール多用ワークフローでコンテキストウィンドウを超える場合、GPT-5.2はCompaction APIで会話状態を圧縮できる。

エンドポイント: `POST https://api.openai.com/v1/responses/compact`

使用タイミング:
- 多数のツール呼び出しを伴うマルチステップエージェントフロー
- 以前のターンを保持する必要がある長い会話
- 最大コンテキストウィンドウを超える反復的推論

ベストプラクティス:
- コンテキスト使用量を監視し、限界に達する前に計画的に圧縮
- 毎ターンではなく、主要なマイルストーン（ツール多用フェーズ後など）で圧縮
- 再開時はプロンプトを機能的に同一に保ち、挙動ドリフトを防ぐ
- 圧縮されたアイテムは不透明として扱い、内部構造に依存しない

---

## 16. 公式ベンチマーク用プロンプト抜粋

### SWE-Bench: 検証の徹底

```
Always verify your changes extremely thoroughly. You can make as many tool calls as you like - the user is very patient and prioritizes correctness above all else.

IMPORTANT: not all tests are visible to you in the repository, so even on problems you think are relatively straightforward, you must double and triple check your solutions to ensure they pass any edge cases that are covered in the hidden tests.
```

### Tau-Bench Retail: 計画と反省

```
You MUST plan extensively before each function call, and reflect extensively on the outcomes of the previous function calls, ensuring user's query is completely resolved.

DO NOT do this entire process by making function calls only, as this can impair your ability to solve the problem and think insightfully.
```

### Terminal-Bench: 探索と検証

```xml
<exploration>
Before coding, always:
- Decompose the request into explicit requirements, unclear areas, and hidden assumptions.
- Map the scope: identify the codebase regions, files, functions likely involved.
- Check dependencies: identify relevant frameworks, APIs, config files.
- Resolve ambiguity proactively: choose the most probable interpretation.
- Define the output contract: exact deliverables.
- Formulate an execution plan and refer to it as you work.
</exploration>

<verification>
Routinely verify your code works as you work through the task. Don't hand back to the user until you are sure that the problem is solved.
</verification>
```

---

## 17. GPT-5.2 マイグレーションガイド

GPT-5.2への移行時のreasoning_effortマッピング：

| 移行元 | 移行先 | reasoning_effort | 備考 |
|---|---|---|---|
| GPT-4o | GPT-5.2 | `none` | 低遅延を維持 |
| GPT-4.1 | GPT-5.2 | `none` | 同上 |
| GPT-5 | GPT-5.2 | 同値（`minimal`→`none`） | レイテンシ/品質プロファイルを維持 |
| GPT-5.1 | GPT-5.2 | 同値 | 評価後に調整 |

移行ステップ:

1. モデル切り替えのみ: プロンプトは変更しない。モデル変更の影響だけをテスト
2. reasoning_effort を明示的に固定: 移行元のレイテンシ/深度プロファイルに合わせる
3. 評価スイートでベースライン取得: 結果が良好（med/highで多い）ならそのまま出荷
4. 回帰があればプロンプト調整: Prompt Optimizer + 冗長性/フォーマット/スキーマの制約で調整
5. 小変更ごとに再評価: reasoning_effort を1段階上げるか、プロンプト微調整を繰り返す

---

## まとめ: 実務向けプロンプト構成テンプレート

```markdown
# タスク
[タスクの概要]

## 成功基準（DoD）
- [抽出すべき情報の明確な定義]
- [品質基準]

## 思考の指針
- [探索戦略: 停止条件を含む]
- 初期結果に対して欠落がないか自己検証せよ

## 出力フォーマット
{
  "entities": [...],
  "primary_complaint": "...",
  "evidence_refs": [...]
}

## 制約
- [停止条件・回数制限]
- [優先順位の明示]

## 永続性（必要に応じて）
- タスク完了まで続けよ
- 不確実性があっても最も合理的な仮定で進めよ
```

成功基準 + 自己検証指示 + 明示的出力スキーマ + 矛盾のない制約 の組み合わせが安定。
