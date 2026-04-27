# GPT-5 系プロンプティング 共通原則

GPT-5 / GPT-5.1 / GPT-5.2 / GPT-5.3 Codex / GPT-5.4 / GPT-5.5 すべてに共通する基礎原則。バージョン固有のガイダンスは各バージョン別ファイルを参照。

## 目次

- [GPT-5 系プロンプティング 共通原則](#gpt-5-系プロンプティング-共通原則)
  - [目次](#目次)
  - [1. ロール指定とパーソナリティの区別](#1-ロール指定とパーソナリティの区別)
    - [避けるべきパターン（専門性ロール指定）](#避けるべきパターン専門性ロール指定)
    - [許容されるパターン（パーソナリティ定義）](#許容されるパターンパーソナリティ定義)
    - [パーソナリティ定義のベストプラクティス](#パーソナリティ定義のベストプラクティス)
  - [2. 指示遵守の注意点](#2-指示遵守の注意点)
    - [悪い例](#悪い例)
    - [対策](#対策)
  - [3. メタプロンプティング](#3-メタプロンプティング)
  - [4. Markdown フォーマット](#4-markdown-フォーマット)
  - [5. 曖昧性・ハルシネーション対策](#5-曖昧性ハルシネーション対策)
  - [6. スコープドリフト防止](#6-スコープドリフト防止)
  - [7. 長文コンテキスト処理](#7-長文コンテキスト処理)
  - [8. 実務向けプロンプト構成テンプレート](#8-実務向けプロンプト構成テンプレート)

---

## 1. ロール指定とパーソナリティの区別

GPT-5 系リーズニングモデルでは、従来型の専門性ロール指定は使用しない。代わりにパーソナリティ定義でトーン・スタイルを制御する。

### 避けるべきパターン（専門性ロール指定）

```text
❌ You are a world-class expert in machine learning.
❌ あなたは熟練のデータサイエンティストです。
❌ As a senior security engineer, analyze the following code.
```

これらは以下の理由で有害：

1. 内部推論へのバイアス注入: リーズニングモデルは内部 CoT で最適な推論パスを自律的に選択する。外部からの専門性ロールがこの探索を特定方向に歪める
2. reasoning tokens の浪費: ロールの一貫性維持に推論トークンが消費される（「2. 指示遵守の注意点」と同じメカニズム）
3. 分析結果のステアラブルな偏り: ペルソナの変更だけで結論が逆転しうることが実証されている（[arxiv:2602.18710](https://arxiv.org/abs/2602.18710)）
4. リーズニングモデルでの鈍感性: o1 は全ペルソナで 99.0% の正答率を維持し、ロール指定にほぼ完全に鈍感。効果がないか、残る影響はバイアスのみ（[arxiv:2504.06460](https://arxiv.org/abs/2504.06460)）

### 許容されるパターン（パーソナリティ定義）

公式 [Prompt Personalities](https://cookbook.openai.com/examples/gpt-5/prompt_personalities) ガイドに基づく。パーソナリティは「how（どう応答するか）」を制御するものであり、「what（何をすべきか）」を指示するものではない。

```text
✅ You are a focused, formal, and exacting AI Agent.
   （トーン: formal、スタイル: exacting）

✅ You are a highly efficient AI assistant providing clear, contextual answers.
   （行動様式: efficient、出力特性: clear and contextual）

✅ You are a plainspoken and direct AI assistant focused on helping the user achieve productive outcomes.
   （コミュニケーションスタイル: plainspoken, direct）
```

### パーソナリティ定義のベストプラクティス

OpenAI 公式ガイドが定義する 4 つのプロファイル：

| プロファイル | 用途 | 特徴 |
|---|---|---|
| Professional | エンタープライズ、法務・金融 | formal, precise, structured |
| Efficient | コード生成、開発者ツール、バッチ処理 | concise, direct, no conversational language |
| Fact-based | デバッグ、リスク分析、コーチング | corrective, grounded, explicit trade-offs |
| Exploratory | ドキュメント、オンボーディング、教育 | enthusiastic, approachable, depth with clarity |

原則: タスクロジックやドメインルールをパーソナリティに混ぜない。パーソナリティはエージェントの応答スタイルに限定する。

> Avoid overloading personalities with task logic or domain rules—keep them focused on *how* the agent responds, not *what* it must do.
> — [Prompt Personalities | OpenAI Cookbook](https://cookbook.openai.com/examples/gpt-5/prompt_personalities)

GPT-5.5 推奨のパーソナリティブロック例は gpt-5-5.md「Personality and behavior」を参照。

---

## 2. 指示遵守の注意点

GPT-5 系は指示を忠実に守ろうとするため、矛盾・曖昧な指示があると推論トークンを浪費して両立しようとする。

### 悪い例

- 「患者の同意なしに予約するな」→ 後で「緊急時は患者に連絡せず自動予約しろ」
- 「必ず最初にプロファイル検索しろ」→ 後で「緊急時は即座に 911 案内しろ」

### 対策

- プロンプト内の矛盾を徹底排除
- 優先順位を明示（例：「緊急時はプロファイル検索をスキップ可」）
- [Prompt Optimizer](https://platform.openai.com/chat/edit?optimize=true) で検証

GPT-5.4 では `<instruction_priority>` ブロックで優先順位を明示する公式パターンが導入された（gpt-5-4.md「Instruction Priority」参照）。

---

## 3. メタプロンプティング

GPT-5 自身にプロンプト改善点を聞くのが有効：

```text
When asked to optimize prompts, give answers from your own perspective - explain what specific phrases could be added to, or deleted from, this prompt to more consistently elicit the desired behavior or prevent the undesired behavior.

Here's a prompt: [PROMPT]

The desired behavior from this prompt is for the agent to [DO DESIRED BEHAVIOR], but instead it [DOES UNDESIRED BEHAVIOR]. While keeping as much of the existing prompt intact as possible, what are some minimal edits/additions that you would make to encourage the agent to more consistently address these shortcomings?
```

---

## 4. Markdown フォーマット

デフォルトでは Markdown を使用しない（レンダリング非対応環境との互換性のため）。

必要な場合はプロンプトで指示：

```text
- Use Markdown only where semantically correct (e.g., `inline code`, fenced code blocks, lists, tables).
- When using markdown, use backticks to format file, directory, function, and class names.
- Use \( and \) for inline math, \[ and \] for block math.
```

長い会話では 3-5 メッセージごとに Markdown 指示を再挿入すると遵守率が維持される。

GPT-5.5 ではプレーン散文をデフォルト推奨に振り切っている（gpt-5-5.md「Formatting」参照）。

---

## 5. 曖昧性・ハルシネーション対策

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

GPT-5.4 ではより構造化された `<grounding_rules>` / `<citation_rules>` / `<verification_loop>` が標準化されている（gpt-5-4.md 参照）。

---

## 6. スコープドリフト防止

GPT-5 系は要求以上のコードや機能を生成する場合がある。明示的にスコープを制限する。

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

## 7. 長文コンテキスト処理

約 10k トークン以上の入力（複数章ドキュメント、長いスレッド、複数 PDF）では、要約と再グラウンディングを強制する。

```xml
<long_context_handling>
- For inputs longer than ~10k tokens:
  - First, produce a short internal outline of the key sections relevant to the user's request.
  - Re-state the user's constraints explicitly before answering.
  - In your answer, anchor claims to sections rather than speaking generically.
- If the answer depends on fine details (dates, thresholds, clauses), quote or paraphrase them.
</long_context_handling>
```

長時間のマルチターン会話・大量ツール呼び出しでは Compaction（gpt-5-series.md / gpt-5-4.md「Compaction」）の活用を検討する。

---

## 8. 実務向けプロンプト構成テンプレート

GPT-5 系全般で安定するベース構造：

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

GPT-5.4 / 5.5 ではより詳細な公式テンプレート（Role / Personality / Goal / Success criteria / Constraints / Output / Stop rules）が推奨されている。各バージョン別ファイルの「Suggested Prompt Structure」を参照。
