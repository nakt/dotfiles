# GPT-5 / GPT-5.1 / GPT-5.2 プロンプティングガイド

GPT-5 系初期 3 バージョン（GPT-5 / GPT-5.1 / GPT-5.2）の固有ガイダンス。共通原則（パーソナリティ vs ロール、矛盾排除、メタプロンプティング、Markdown、曖昧性対策、スコープドリフト、長文コンテキスト、まとめテンプレート）は [common.md](common.md) を参照。

GPT-5.3 Codex / 5.4 / 5.5 の固有ガイダンスは各バージョン別ファイルを参照。

## 目次

- [GPT-5 / GPT-5.1 / GPT-5.2 プロンプティングガイド](#gpt-5--gpt-51--gpt-52-プロンプティングガイド)
  - [目次](#目次)
  - [1. reasoning\_effort パラメータ](#1-reasoning_effort-パラメータ)
  - [2. verbosity パラメータ](#2-verbosity-パラメータ)
  - [3. Responses API 推奨](#3-responses-api-推奨)
  - [4. Tool Preamble（ツール呼び出し前の説明）](#4-tool-preambleツール呼び出し前の説明)
  - [5. エージェント積極性（Eagerness）の制御](#5-エージェント積極性eagernessの制御)
    - [積極性を下げる場合](#積極性を下げる場合)
    - [積極性を上げる場合](#積極性を上げる場合)
  - [6. none reasoning モードのプロンプティング（GPT-5.1 で導入）](#6-none-reasoning-モードのプロンプティングgpt-51-で導入)
  - [7. Cursor のプロンプトチューニング事例](#7-cursor-のプロンプトチューニング事例)
    - [発見1: 冗長性のバランス](#発見1-冗長性のバランス)
    - [発見2: 不要なユーザー確認の削減](#発見2-不要なユーザー確認の削減)
    - [発見3: 過剰なコンテキスト収集の抑制](#発見3-過剰なコンテキスト収集の抑制)
  - [8. Compaction（コンテキスト拡張）](#8-compactionコンテキスト拡張)
  - [9. 公式ベンチマーク用プロンプト抜粋](#9-公式ベンチマーク用プロンプト抜粋)
    - [SWE-Bench: 検証の徹底](#swe-bench-検証の徹底)
    - [Tau-Bench Retail: 計画と反省](#tau-bench-retail-計画と反省)
    - [Terminal-Bench: 探索と検証](#terminal-bench-探索と検証)
  - [10. GPT-5.2 マイグレーションガイド](#10-gpt-52-マイグレーションガイド)

---

## 1. reasoning_effort パラメータ

| レベル | 用途 |
|---|---|
| `none` | 非推論モード（GPT-5.1 で導入）。GPT-4.1/4o 相当の挙動。web search・file search 等の hosted tools が利用可能 |
| `minimal` | 低レイテンシ優先。GPT-5.1 以降では `none` への移行を推奨 |
| `low` | 簡単なタスク |
| `medium` | GPT-5 のデフォルト |
| `high` | 複雑なマルチステップタスク |
| `xhigh` | 最大推論深度（GPT-5.2 で導入） |

デフォルト値:

| バージョン | デフォルト |
|---|---|
| GPT-5 | `medium` |
| GPT-5.1 | `none` |
| GPT-5.2 | `none` |

推奨: 複数の独立タスクは、1 ターンに 1 タスクずつ分割すると最高性能。

GPT-5.4 以降では「`none` / `low` / `medium` から始め、`high` / `xhigh` は reasoning-heavy 用途に限定」が公式推奨に変化（gpt-5-4.md「Reasoning Effort 推奨」参照）。

---

## 2. verbosity パラメータ

`reasoning_effort` が思考の深さを制御するのに対し、`verbosity` は最終回答の長さを制御。

- API パラメータでグローバル設定
- プロンプトで特定コンテキストのみ上書き可能

Cursor 事例: グローバルで `verbosity=low`、コード出力のみ高冗長性を指定：

```text
Write code for clarity first. Prefer readable, maintainable solutions with clear names, comments where needed. Do not produce code-golf or overly clever one-liners. Use high verbosity for writing code and code tools.
```

---

## 3. Responses API 推奨

Chat Completions API より Responses API を強く推奨。

- `previous_response_id` で前回の推論トレースを再利用
- ツール呼び出し後に計画を再構築する必要なし
- CoT トークン節約、レイテンシ改善
- Tau-Bench Retail で 73.9% → 78.2% にスコア改善

---

## 4. Tool Preamble（ツール呼び出し前の説明）

長時間タスクでは進捗説明が UX を大幅改善。頻度・スタイル・内容をプロンプトで制御可能。

```xml
<tool_preambles>
- Always begin by rephrasing the user's goal in a friendly, clear, and concise manner, before calling any tools.
- Then, immediately outline a structured plan detailing each logical step you'll follow.
- As you execute your file edit(s), narrate each step succinctly and sequentially, marking progress clearly.
- Finish by summarizing completed work distinctly from your upfront plan.
</tool_preambles>
```

GPT-5.4 / 5.5 では `phase` パラメータ（commentary / final_answer）と組み合わせる運用が推奨されている（gpt-5-4.md「Phase Parameter」参照）。

---

## 5. エージェント積極性（Eagerness）の制御

GPT-5 はデフォルトで徹底的にコンテキスト収集しようとする。タスクに応じて制御が必要。

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

## 6. none reasoning モードのプロンプティング（GPT-5.1 で導入）

GPT-5.1 で導入された `reasoning_effort=none` は reasoning トークンを一切使用せず、GPT-4.1/4o に近い挙動となる。web search・file search 等の hosted tools が利用可能になる。

`none` および `minimal` では GPT-4.1 に近いプロンプティングが有効：

1. 明示的な計画指示: モデルが内部で計画する余裕が少ないため
2. 詳細なツール呼び出し説明を要求: 進捗更新でエージェント性能向上
3. ツール説明の曖昧さ排除: 最大限に明確化
4. 永続性リマインダー: 早期終了を防ぐ
5. 簡潔な思考プロセス出力を要求: 箇条書きなど

```text
You MUST plan extensively before each function call, and reflect extensively on the outcomes of the previous function calls, ensuring user's query is completely resolved.
```

`none` でツール呼び出しの正確性を高める：

```text
When selecting a replacement variant, verify it meets all user constraints (cheapest, brand, spec, etc.). Quote the item-id and price back for confirmation before executing.
```

計画プロンプト例：

```text
Remember, you are an agent - please keep going until the user's query is completely resolved. Decompose the user's query into all required sub-requests, and confirm that each is completed. Do not stop after completing only part of the request.

You must plan extensively in accordance with the workflow steps before making subsequent function calls, and reflect extensively on the outcomes each function call made.
```

---

## 7. Cursor のプロンプトチューニング事例

### 発見1: 冗長性のバランス

初期問題: テキスト出力が冗長、コードは逆に簡潔すぎる（単一文字変数など）

解決策:

- API で `verbosity=low` を設定
- プロンプトでコードのみ高冗長性を指定

### 発見2: 不要なユーザー確認の削減

初期問題: モデルが頻繁に確認を求め、長時間タスクの流れが途切れる

解決策: 製品の挙動を詳細に説明し、自律性を促進

```text
Be aware that the code edits you make will be displayed to the user as proposed changes, which means (a) your code edits can be quite proactive, as the user can always reject, and (b) your code should be well-written and easy to quickly review.

If proposing next steps that would involve changing the code, make those changes proactively for the user to approve/reject rather than asking whether to proceed. In general, you should almost never ask the user whether to proceed with a plan; instead proactively attempt the plan.
```

### 発見3: 過剰なコンテキスト収集の抑制

初期問題: 以前のモデル向けの「徹底的に調査せよ」指示が GPT-5 では逆効果

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

## 8. Compaction（コンテキスト拡張）

長時間実行のツール多用ワークフローでコンテキストウィンドウを超える場合、GPT-5.2 は Compaction API で会話状態を圧縮できる。

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

GPT-5.4 では ZDR 互換 / `encrypted_content` を返却する形で標準化されている（gpt-5-4.md「Compaction for Long Sessions」参照）。

---

## 9. 公式ベンチマーク用プロンプト抜粋

### SWE-Bench: 検証の徹底

```text
Always verify your changes extremely thoroughly. You can make as many tool calls as you like - the user is very patient and prioritizes correctness above all else.

IMPORTANT: not all tests are visible to you in the repository, so even on problems you think are relatively straightforward, you must double and triple check your solutions to ensure they pass any edge cases that are covered in the hidden tests.
```

### Tau-Bench Retail: 計画と反省

```text
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

## 10. GPT-5.2 マイグレーションガイド

GPT-5.2 への移行時の reasoning_effort マッピング：

| 移行元 | 移行先 | reasoning_effort | 備考 |
|---|---|---|---|
| GPT-4o | GPT-5.2 | `none` | 低遅延を維持 |
| GPT-4.1 | GPT-5.2 | `none` | 同上 |
| GPT-5 | GPT-5.2 | 同値（`minimal`→`none`） | レイテンシ/品質プロファイルを維持 |
| GPT-5.1 | GPT-5.2 | 同値 | 評価後に調整 |

移行ステップ:

1. モデル切り替えのみ: プロンプトは変更しない。モデル変更の影響だけをテスト
2. reasoning_effort を明示的に固定: 移行元のレイテンシ/深度プロファイルに合わせる
3. 評価スイートでベースライン取得: 結果が良好（med/high で多い）ならそのまま出荷
4. 回帰があればプロンプト調整: Prompt Optimizer + 冗長性/フォーマット/スキーマの制約で調整
5. 小変更ごとに再評価: reasoning_effort を 1 段階上げるか、プロンプト微調整を繰り返す

GPT-5.4 / 5.5 への移行は各バージョンファイルの「Migration Path」を参照。
