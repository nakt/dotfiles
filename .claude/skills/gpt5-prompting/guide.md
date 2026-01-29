# GPT-5 公式プロンプティングガイド 詳細

OpenAI公式ドキュメントに基づくGPT-5系モデルのプロンプティングベストプラクティス。

---

## 1. エージェント積極性（Eagerness）の制御

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

**ポイント**: ツールごとに不確実性の閾値を変える。決済ツールは低閾値（確認必須）、検索ツールは高閾値（自律的に進める）。

---

## 2. Tool Preamble（ツール呼び出し前の説明）

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

## 3. reasoning_effort パラメータ

| レベル | 用途 |
|---|---|
| `minimal` | 低レイテンシ優先、GPT-4.1からの移行向け |
| `low` | 簡単なタスク |
| `medium` | デフォルト、多くのワークフローで十分 |
| `high` | 複雑なマルチステップタスク |

**推奨**: 複数の独立タスクは、1ターンに1タスクずつ分割すると最高性能。

---

## 4. verbosity パラメータ

`reasoning_effort` が思考の深さを制御するのに対し、`verbosity` は最終回答の長さを制御。

- APIパラメータでグローバル設定
- プロンプトで特定コンテキストのみ上書き可能

**Cursor事例**: グローバルで `verbosity=low`、コード出力のみ高冗長性を指定：

```
Write code for clarity first. Prefer readable, maintainable solutions with clear names, comments where needed. Do not produce code-golf or overly clever one-liners. Use high verbosity for writing code and code tools.
```

---

## 5. Responses API 推奨

Chat Completions APIより**Responses API**を強く推奨。

- `previous_response_id` で前回の推論トレースを再利用
- ツール呼び出し後に計画を再構築する必要なし
- CoTトークン節約、レイテンシ改善
- Tau-Bench Retailで 73.9% → 78.2% にスコア改善

---

## 6. 指示遵守の注意点

GPT-5は指示を忠実に守ろうとするため、**矛盾・曖昧な指示があると推論トークンを浪費**して両立しようとする。

### 悪い例

- 「患者の同意なしに予約するな」→ 後で「緊急時は患者に連絡せず自動予約しろ」
- 「必ず最初にプロファイル検索しろ」→ 後で「緊急時は即座に911案内しろ」

### 対策

- プロンプト内の矛盾を徹底排除
- 優先順位を明示（例：「緊急時はプロファイル検索をスキップ可」）
- [Prompt Optimizer](https://platform.openai.com/chat/edit?optimize=true) で検証

---

## 7. minimal reasoning モードのプロンプティング

`reasoning_effort=minimal` ではGPT-4.1に近いプロンプティングが有効：

1. **明示的な計画指示**: モデルが内部で計画する余裕が少ないため
2. **詳細なツール呼び出し説明を要求**: 進捗更新でエージェント性能向上
3. **ツール説明の曖昧さ排除**: 最大限に明確化
4. **永続性リマインダー**: 早期終了を防ぐ
5. **簡潔な思考プロセス出力を要求**: 箇条書きなど

```
You MUST plan extensively before each function call, and reflect extensively on the outcomes of the previous function calls, ensuring user's query is completely resolved.
```

計画プロンプト例：

```
Remember, you are an agent - please keep going until the user's query is completely resolved. Decompose the user's query into all required sub-requests, and confirm that each is completed. Do not stop after completing only part of the request.

You must plan extensively in accordance with the workflow steps before making subsequent function calls, and reflect extensively on the outcomes each function call made.
```

---

## 8. Cursorのプロンプトチューニング事例

### 発見1: 冗長性のバランス

**初期問題**: テキスト出力が冗長、コードは逆に簡潔すぎる（単一文字変数など）

**解決策**:
- APIで `verbosity=low` を設定
- プロンプトでコードのみ高冗長性を指定

### 発見2: 不要なユーザー確認の削減

**初期問題**: モデルが頻繁に確認を求め、長時間タスクの流れが途切れる

**解決策**: 製品の挙動を詳細に説明し、自律性を促進

```
Be aware that the code edits you make will be displayed to the user as proposed changes, which means (a) your code edits can be quite proactive, as the user can always reject, and (b) your code should be well-written and easy to quickly review.

If proposing next steps that would involve changing the code, make those changes proactively for the user to approve/reject rather than asking whether to proceed. In general, you should almost never ask the user whether to proceed with a plan; instead proactively attempt the plan.
```

### 発見3: 過剰なコンテキスト収集の抑制

**初期問題**: 以前のモデル向けの「徹底的に調査せよ」指示がGPT-5では逆効果

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

## 9. Markdownフォーマット

デフォルトではMarkdownを使用しない（レンダリング非対応環境との互換性のため）。

必要な場合はプロンプトで指示：

```
- Use Markdown **only where semantically correct** (e.g., `inline code`, ```code fences```, lists, tables).
- When using markdown, use backticks to format file, directory, function, and class names.
- Use \( and \) for inline math, \[ and \] for block math.
```

長い会話では3-5メッセージごとにMarkdown指示を再挿入すると遵守率が維持される。

---

## 10. メタプロンプティング

GPT-5自身にプロンプト改善点を聞くのが有効：

```
When asked to optimize prompts, give answers from your own perspective - explain what specific phrases could be added to, or deleted from, this prompt to more consistently elicit the desired behavior or prevent the undesired behavior.

Here's a prompt: [PROMPT]

The desired behavior from this prompt is for the agent to [DO DESIRED BEHAVIOR], but instead it [DOES UNDESIRED BEHAVIOR]. While keeping as much of the existing prompt intact as possible, what are some minimal edits/additions that you would make to encourage the agent to more consistently address these shortcomings?
```

---

## 11. 公式ベンチマーク用プロンプト抜粋

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

**成功基準 + 自己検証指示 + 明示的出力スキーマ + 矛盾のない制約** の組み合わせが安定。
